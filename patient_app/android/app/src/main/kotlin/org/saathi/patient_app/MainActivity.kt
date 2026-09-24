package org.saathi.patient_app

import android.app.role.RoleManager
import android.app.AppOpsManager
import android.app.NotificationManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.Manifest
import android.content.ComponentName
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
import android.util.Log
import java.util.Locale
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

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
    private var pendingSharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        receiveShare(intent)
    }

    private fun receiveShare(incoming: Intent?) {
        if (incoming?.action == Intent.ACTION_SEND && incoming.type == "text/plain") {
            pendingSharedText = incoming.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.take(4096)
        }
    }

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
        setIntent(intent)
        receiveShare(intent)
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
                        "usageAccessGranted" -> result.success(usageAccessGranted())
                        "openUsageAccessSettings" -> {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(null)
                        }
                        "recentUsage" -> result.success(recentUsage())
                        "notificationAccessGranted" -> {
                            val manager = getSystemService(NotificationManager::class.java)
                            result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1 &&
                                manager.isNotificationListenerAccessGranted(
                                    ComponentName(this, SaathiNotificationListener::class.java)))
                        }
                        "openNotificationAccessSettings" -> {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                            result.success(null)
                        }
                        "setNotificationCapture" -> {
                            val enabled = call.argument<Boolean>("enabled") == true
                            getSharedPreferences("saathi_notification_context", MODE_PRIVATE).edit().apply {
                                putBoolean("enabled", enabled)
                                if (!enabled) remove("items")
                            }.apply()
                            result.success(null)
                        }
                        "notificationPreviews" -> {
                            val prefs = getSharedPreferences("saathi_notification_context", MODE_PRIVATE)
                            val values = if (prefs.getBoolean("enabled", false))
                                JSONArray(prefs.getString("items", "[]")) else JSONArray()
                            result.success((0 until values.length()).mapNotNull { index ->
                                values.optJSONObject(index)?.let { item -> mapOf(
                                    "timestamp" to item.optLong("timestamp"),
                                    "packageName" to item.optString("packageName"),
                                    "sender" to item.optString("sender"),
                                    "preview" to item.optString("preview"),
                                ) }
                            })
                        }
                        "consumeShare" -> {
                            val text = pendingSharedText
                            pendingSharedText = null
                            result.success(text)
                        }
                        "openWebLink" -> {
                            val uri = android.net.Uri.parse(call.argument<String>("url").orEmpty())
                            if (uri.scheme != "https" && uri.scheme != "http") {
                                result.error("INVALID_LINK", "Only web links can be reopened", null)
                            } else {
                                startActivity(Intent(Intent.ACTION_VIEW, uri))
                                result.success(null)
                            }
                        }
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

    private fun usageAccessGranted(): Boolean {
        val ops = getSystemService(AppOpsManager::class.java)
        return ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
    }

    private fun recentUsage(): List<Map<String, Any>> {
        if (!usageAccessGranted()) return emptyList()
        val now = System.currentTimeMillis()
        val manager = getSystemService(UsageStatsManager::class.java)
        val events = manager.queryEvents(now - 2 * 60 * 60 * 1000L, now)
        val event = UsageEvents.Event()
        val observed = mutableListOf<Map<String, Any>>()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val foreground = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            else event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            val observedPackage = event.packageName ?: continue
            if (!foreground || observedPackage == packageName ||
                observedPackage == "com.android.systemui" ||
                packageManager.getLaunchIntentForPackage(observedPackage) == null) continue
            val label = try {
                packageManager.getApplicationLabel(packageManager.getApplicationInfo(observedPackage, 0)).toString()
            } catch (_: Exception) { observedPackage }
            observed.add(mapOf("timestamp" to event.timeStamp,
                "packageName" to observedPackage, "appName" to label))
        }
        return observed.takeLast(50)
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
            override fun onReadyForSpeech(params: Bundle?) {
                Log.d("SaathiSpeech", "onReadyForSpeech")
            }
            override fun onBeginningOfSpeech() {
                Log.d("SaathiSpeech", "onBeginningOfSpeech")
            }
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() {
                Log.d("SaathiSpeech", "onEndOfSpeech")
            }
            override fun onError(error: Int) {
                Log.w("SaathiSpeech", "onError: code=$error")
                runOnUiThread {
                    // ERROR_NO_MATCH (7) and ERROR_RECOGNIZER_BUSY (8) are
                    // transient; signal Dart with the numeric code as a string
                    // so it can decide whether to retry or surface the error.
                    speechChannel?.invokeMethod("error", error.toString())
                    destroySpeechRecognizer()
                }
            }
            override fun onResults(results: Bundle?) {
                Log.d("SaathiSpeech", "onResults received")
                runOnUiThread {
                    deliverSpeech("final", results)
                    destroySpeechRecognizer()
                }
            }
            override fun onPartialResults(partialResults: Bundle?) {
                runOnUiThread {
                    deliverSpeech("partial", partialResults)
                }
            }
            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        })

        val defaultLocale = Locale.getDefault()
        val languageTag = if (defaultLocale.toLanguageTag().isNotBlank()) defaultLocale.toLanguageTag() else "en-US"
        Log.d("SaathiSpeech", "startGoogleSpeechRecognition: locale=$languageTag")

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageTag)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, languageTag)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 2000L)
            putExtra("android.speech.extra.EXTRA_ADDITIONAL_LANGUAGES", arrayOf("en-IN", "en-US", "en-GB", "hi-IN"))
        }
        speechRecognizer?.startListening(intent)
    }

    private fun deliverSpeech(event: String, results: Bundle?) {
        val texts = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?: results?.getStringArrayList("results_recognition")
            ?: emptyList<String>()
        val speechText = texts.firstOrNull().orEmpty()
        Log.d("SaathiSpeech", "deliverSpeech: event=$event, text='$speechText', all=$texts")
        runOnUiThread {
            speechChannel?.invokeMethod(event, speechText)
        }
    }

    private fun destroySpeechRecognizer() {
        runOnUiThread {
            try {
                speechRecognizer?.destroy()
            } catch (e: Exception) {
                Log.w("SaathiSpeech", "destroySpeechRecognizer error: ${e.message}")
            }
            speechRecognizer = null
        }
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
            val defaultLocale = Locale.getDefault()
            val langResult = voice.setLanguage(defaultLocale)
            if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                voice.language = Locale.US
            }
            if (voice.speak(text, TextToSpeech.QUEUE_FLUSH, null, id) == TextToSpeech.ERROR) finishSpeech(id, true)
            return
        }
        textToSpeech = TextToSpeech(applicationContext) { status ->
            textToSpeechReady = status == TextToSpeech.SUCCESS
            if (textToSpeechReady) {
                val defaultLocale = Locale.getDefault()
                val langResult = textToSpeech?.setLanguage(defaultLocale)
                if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                    textToSpeech?.language = Locale.US
                }
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

