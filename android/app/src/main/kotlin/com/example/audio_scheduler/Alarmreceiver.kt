package com.example.adhan_player

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fires at the scheduled time: re-arms tomorrow's alarm, then starts playback. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AlarmScheduler.scheduleNext(context)
        PlaybackService.start(context, scheduled = true)
    }
}