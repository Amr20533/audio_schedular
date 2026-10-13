package com.example.audio_scheduler

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Fires at the Home screen's scheduled audio time. Independent of Adhan. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AdhanDebug", "AlarmReceiver[audio].onReceive fired")
        AlarmScheduler.scheduleNext(context, "audio")
        PlaybackService.start(context, scheduled = true, scheduleId = "audio")
    }
}