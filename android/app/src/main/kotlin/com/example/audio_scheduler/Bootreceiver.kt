package com.example.audio_scheduler

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Alarms are wiped on reboot / app update / timezone change — re-arm everything. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AlarmScheduler.scheduleNext(context, "audio")
        AlarmScheduler.scheduleAllAdhan(context)
    }
}