package com.example.audio_scheduler

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/** Fires a few minutes before any one of the 5 prayer alarms. Plain notification only. */
class PreAdhanReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val scheduleId = intent.getStringExtra("scheduleId") ?: "adhan_fajr"
        Log.d("AdhanDebug", "PreAdhanReminderReceiver fired for $scheduleId")
        show(context, scheduleId)
    }

    companion object {
        private const val CHANNEL_ID = "prayer_reminders"
        private const val NOTIF_ID = 77

        fun show(context: Context, scheduleId: String) {
            val label = AlarmScheduler.label(context, scheduleId)

            if (Build.VERSION.SDK_INT >= 26) {
                val channel = NotificationChannel(
                    CHANNEL_ID, "Prayer reminders", NotificationManager.IMPORTANCE_HIGH
                )
                context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
            }

            val openApp = PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
            )

            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL_ID)
                else Notification.Builder(context)

            val notification = builder
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle("اقتربت صلاة $label")
                .setContentText("$label prayer is approaching")
                .setContentIntent(openApp)
                .setAutoCancel(true)
                .build()

            context.getSystemService(NotificationManager::class.java)
                .notify(NOTIF_ID, notification)
        }
    }
}