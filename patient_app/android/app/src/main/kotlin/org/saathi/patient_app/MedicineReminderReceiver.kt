package org.saathi.patient_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/** Android system bridge for a daily medicine notification.
 * Flutter supplies only a Passport entry's label, time, and caregiver note.
 */
class MedicineReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Medicine"
        val time = intent.getStringExtra(EXTRA_TIME) ?: return
        val instructions = intent.getStringExtra(EXTRA_INSTRUCTIONS) ?: ""
        showNotification(context, id, title, time, instructions)
        schedule(context, id, title, time, instructions)
    }

    companion object {
        private const val CHANNEL_ID = "medicine_reminders"
        private const val EXTRA_ID = "id"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TIME = "time"
        private const val EXTRA_INSTRUCTIONS = "instructions"

        fun schedule(context: Context, id: String, title: String, time: String, instructions: String) {
            val parts = time.split(":")
            if (parts.size != 2) return
            val hour = parts[0].toIntOrNull() ?: return
            val minute = parts[1].toIntOrNull() ?: return
            if (hour !in 0..23 || minute !in 0..59) return
            val whenToNotify = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
            }
            val manager = context.getSystemService(AlarmManager::class.java)
            manager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                whenToNotify.timeInMillis,
                pendingIntent(context, id, title, time, instructions),
            )
        }

        fun cancel(context: Context, id: String) {
            val manager = context.getSystemService(AlarmManager::class.java)
            manager.cancel(pendingIntent(context, id, "Medicine", "00:00", ""))
        }

        private fun pendingIntent(context: Context, id: String, title: String, time: String, instructions: String): PendingIntent {
            val intent = Intent(context, MedicineReminderReceiver::class.java).apply {
                putExtra(EXTRA_ID, id)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TIME, time)
                putExtra(EXTRA_INSTRUCTIONS, instructions)
            }
            return PendingIntent.getBroadcast(
                context,
                id.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun showNotification(context: Context, id: String, title: String, time: String, instructions: String) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                return
            }
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "Medicine reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                        description = "Daily medicine reminders from Saathi"
                    },
                )
            }
            val openApp = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val contentIntent = openApp?.let {
                PendingIntent.getActivity(context, id.hashCode(), it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }
            val message = if (instructions.isBlank()) "It is time for $title." else "It is time for $title. $instructions"
            val notification = android.app.Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle("Medicine reminder")
                .setContentText(message)
                .setStyle(android.app.Notification.BigTextStyle().bigText(message))
                .setAutoCancel(true)
                .setContentIntent(contentIntent)
                .build()
            manager.notify(id.hashCode(), notification)
        }
    }
}
