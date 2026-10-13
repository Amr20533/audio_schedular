package com.example.audio_scheduler

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Fires for any one of the 5 prayer alarms — which one is in the "scheduleId" extra. */
class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val scheduleId = intent.getStringExtra("scheduleId") ?: return
        Log.d("AdhanDebug", "AdhanAlarmReceiver.onReceive fired for $scheduleId")
        AlarmScheduler.scheduleNext(context, scheduleId)
        PlaybackService.start(context, scheduled = true, scheduleId = scheduleId)
    }
}