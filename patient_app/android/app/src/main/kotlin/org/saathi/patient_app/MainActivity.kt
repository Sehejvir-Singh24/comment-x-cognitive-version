package org.saathi.patient_app

import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var launcherChannel: MethodChannel? = null

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
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("ANDROID_UNAVAILABLE", "Android could not complete this action", null)
                }
            }
    }
}
