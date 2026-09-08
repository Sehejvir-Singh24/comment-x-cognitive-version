package org.saathi.patient_app

import android.app.role.RoleManager
import android.Manifest
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.os.Bundle
import java.util.Locale
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var launcherChannel: MethodChannel? = null
    private var speechChannel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingMicrophoneResult: MethodChannel.Result? = null
    private var textToSpeech: TextToSpeech? = null
    private var textToSpeechReady = false
    private var pendingSpeech: MethodChannel.Result? = null
    private var utteranceNumber = 0
    private var activeUtterance = ""

    private fun finishSpeech(id: String, failed: Boolean = false) {
        runOnUiThread {
            if (id == activeUtterance) {
                val pending = pendingSpeech
                pendingSpeech = null
                if (failed) pending?.error("TTS_FAILED", "Speech could not complete", null)
                else pending?.success(null)
            }
        }
    }

    private fun stopVoice() {
        activeUtterance = ""
        val pending = pendingSpeech
        pendingSpeech = null
        textToSpeech?.stop()
        pending?.success(null)
    }

    private val reminderPreferences by lazy { getSharedPreferences("medicine_reminders", MODE_PRIVATE) }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_HOME)) {
            launcherChannel?.invokeMethod("homePressed", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launcherChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.saathi/launcher")
        launcherChannel?.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "hasValidatedInternet" -> {
                            val manager = getSystemService(ConnectivityManager::class.java)
                            val caps = manager.getNetworkCapabilities(manager.activeNetwork)
                            result.success(caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true)
                        }
                        "isDefaultHome" -> {
                            val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
                            val resolved = packageManager.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)
                            result.success(resolved?.activityInfo?.packageName == packageName)
                        }
                        "requestHome" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                val roles = getSystemService(RoleManager::class.java)
                                if (roles.isRoleAvailable(RoleManager.ROLE_HOME) && !roles.isRoleHeld(RoleManager.ROLE_HOME)) {
                                    startActivityForResult(roles.createRequestRoleIntent(RoleManager.ROLE_HOME), 101)
                                } else if (!roles.isRoleHeld(RoleManager.ROLE_HOME)) {
                                    startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
                                }
                            } else {
                                startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
                            }
                            result.success(null)
                        }
                        "listApps" -> {
                            val query = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                            val apps = packageManager.queryIntentActivities(query, 0)
                                .filter { it.activityInfo.packageName != packageName }
                                .distinctBy { it.activityInfo.packageName }
                                .map { mapOf("label" to it.loadLabel(packageManager).toString(), "packageName" to it.activityInfo.packageName) }
                                .sortedBy { it["label"]?.lowercase() }
                            result.success(apps)
                        }
                        "openApp" -> {
                            val target = call.argument<String>("packageName")
                            val intent = target?.let { packageManager.getLaunchIntentForPackage(it) }
                            if (intent == null || target == packageName) {
                                result.error("APP_UNAVAILABLE", "Application is unavailable", null)
                            } else {
                                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                                result.success(null)
                            }
                        }
                        "openDialer" -> {
                            startActivity(Intent(Intent.ACTION_DIAL))
                            result.success(null)
                        }
                        "dialNumber" -> {
                            val number = call.argument<String>("number").orEmpty()
                            val uri = android.net.Uri.parse("tel:$number")
                            startActivity(Intent(Intent.ACTION_DIAL, uri))
                            result.success(null)
                        }
                        "openSettings" -> {
                            startActivity(Intent(Settings.ACTION_SETTINGS))
                            result.success(null)
                        }
                        "openMaps" -> {
                            val uri = android.net.Uri.parse("geo:0,0")
                            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                                setPackage("com.google.android.apps.maps")
                            }
                            val fallback = Intent(Intent.ACTION_VIEW, uri)
                            try {
                                startActivity(intent)
                            } catch (_: android.content.ActivityNotFoundException) {
                                startActivity(fallback)
                            }
                            result.success(null)
                        }
                        "openCalendar" -> {
                            val intent = Intent(Intent.ACTION_MAIN).apply {
                                addCategory(Intent.CATEGORY_APP_CALENDAR)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null)
                        }
                        "openContacts" -> {
                            startActivity(Intent(Intent.ACTION_VIEW, android.provider.ContactsContract.Contacts.CONTENT_URI))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("ANDROID_UNAVAILABLE", "Android could not complete this action", null)
                }
            }
        speechChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.saathi/speech")
        speechChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "availability" -> result.success(
                    SpeechRecognizer.isRecognitionAvailable(this)
                )
                "start" -> {
                    if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                        result.error("SPEECH_UNAVAILABLE", "Google speech recognition is unavailable on this phone", null)
                    } else if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                        if (pendingMicrophoneResult != null) {
                            result.error("MICROPHONE_PERMISSION_PENDING", "Waiting for microphone permission", null)
                        } else {
                            pendingMicrophoneResult = result
                            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), MICROPHONE_PERMISSION_REQUEST)
                        }
                    } else {
                        startGoogleSpeechRecognition()
                        result.success(null)
                    }
                }
                "stop" -> { speechRecognizer?.stopListening(); result.success(null) }
                "cancel" -> { destroySpeechRecognizer(); result.success(null) }
                "speak" -> speak(call.argument<String>("text").orEmpty(), result)
                "stopSpeaking" -> {
                    stopVoice()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.saathi/reminders")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "permissionGranted" -> result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        )
                        "requestPermission" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 202)
                            }
                            result.success(null)
                        }
                        "schedule" -> {
                            val reminders = call.argument<List<Map<String, String>>>("reminders").orEmpty()
                            cancelMedicineReminders()
                            val ids = reminders.mapNotNull { reminder ->
                                val id = reminder["id"] ?: return@mapNotNull null
                                val title = reminder["title"] ?: "Medicine"
                                val time = reminder["time"] ?: return@mapNotNull null
                                val instructions = reminder["instructions"] ?: ""
                                MedicineReminderReceiver.schedule(this, id, title, time, instructions)
                                id
                            }
                            reminderPreferences.edit().putStringSet("ids", ids.toSet()).apply()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("REMINDER_UNAVAILABLE", "Android could not set the medicine reminder", null)
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != MICROPHONE_PERMISSION_REQUEST) return
        val result = pendingMicrophoneResult ?: return
        pendingMicrophoneResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startGoogleSpeechRecognition()
            result.success(null)
        } else {
            result.error(
                "MICROPHONE_PERMISSION_DENIED",
                "Microphone permission is required for voice input",
                null,
            )
        }
    }

    private fun cancelMedicineReminders() {
        val ids = reminderPreferences.getStringSet("ids", emptySet()).orEmpty()
        ids.forEach { MedicineReminderReceiver.cancel(this, it) }
        reminderPreferences.edit().remove("ids").apply()
    }

    private fun startGoogleSpeechRecognition() {
        destroySpeechRecognizer()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = Unit
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit
            override fun onError(error: Int) {
                speechChannel?.invokeMethod("error", mapOf("code" to error))
                destroySpeechRecognizer()
            }
            override fun onResults(results: Bundle?) {
                deliverSpeech("final", results)
                destroySpeechRecognizer()
            }
            override fun onPartialResults(partialResults: Bundle?) = deliverSpeech("partial", partialResults)
            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-GB")
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
        }
        speechRecognizer?.startListening(intent)
    }

    private fun deliverSpeech(event: String, results: Bundle?) {
        val texts = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty()
        speechChannel?.invokeMethod(event, texts.firstOrNull() ?: "")
    }

    private fun destroySpeechRecognizer() {
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    private fun speak(text: String, result: MethodChannel.Result) {
        if (text.isBlank()) {
            result.success(null)
            return
        }
        val voice = textToSpeech
        stopVoice()
        val id = "saathi-${++utteranceNumber}"
        activeUtterance = id
        pendingSpeech = result
        if (voice != null && textToSpeechReady) {
            if (voice.speak(text, TextToSpeech.QUEUE_FLUSH, null, id) == TextToSpeech.ERROR) finishSpeech(id, true)
            return
        }
        textToSpeech = TextToSpeech(applicationContext) { status ->
            textToSpeechReady = status == TextToSpeech.SUCCESS
            if (textToSpeechReady) {
                textToSpeech?.language = Locale.UK
                textToSpeech?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) = Unit
                    override fun onDone(utteranceId: String?) { finishSpeech(utteranceId.orEmpty()) }
                    override fun onError(utteranceId: String?) { finishSpeech(utteranceId.orEmpty(), true) }
                })
                if (activeUtterance == id && textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, id) == TextToSpeech.ERROR) finishSpeech(id, true)
            } else {
                finishSpeech(id, true)
            }
        }
    }

    override fun onDestroy() {
        destroySpeechRecognizer()
        stopVoice()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }

    companion object {
        private const val MICROPHONE_PERMISSION_REQUEST = 203
    }
}

