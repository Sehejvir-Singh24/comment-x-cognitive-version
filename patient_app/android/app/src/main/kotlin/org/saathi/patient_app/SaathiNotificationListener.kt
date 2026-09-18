package org.saathi.patient_app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/** Records only opt-in WhatsApp notification previews in private device storage. */
class SaathiNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(notification: StatusBarNotification?) {
        val posted = notification ?: return
        if (posted.packageName != "com.whatsapp") return
        val prefs = getSharedPreferences("saathi_notification_context", MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false)) return
        val extras = posted.notification.extras
        val sender = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val preview = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim().orEmpty()
        if (sender.isEmpty() && preview.isEmpty()) return
        val now = System.currentTimeMillis()
        val previous = try { JSONArray(prefs.getString("items", "[]")) } catch (_: Exception) { JSONArray() }
        val kept = JSONArray()
        kept.put(JSONObject()
            .put("timestamp", posted.postTime)
            .put("packageName", posted.packageName)
            .put("sender", sender.take(80))
            .put("preview", preview.take(160)))
        for (index in 0 until previous.length()) {
            val item = previous.optJSONObject(index) ?: continue
            if (item.optLong("timestamp") >= now - 24 * 60 * 60 * 1000L && kept.length() < 20) {
                kept.put(item)
            }
        }
        prefs.edit().putString("items", kept.toString()).apply()
    }
}
