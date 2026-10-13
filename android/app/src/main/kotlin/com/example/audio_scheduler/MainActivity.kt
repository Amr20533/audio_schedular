package com.example.audio_scheduler

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100)
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        val am = getSystemService(AlarmManager::class.java)
        return am.canScheduleExactAlarms()
    }

    private fun requestExactAlarmPermission() {
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }

    // Re-arm BOTH schedules whenever the user returns to the app — covers
    // granting the exact-alarm permission in Settings and coming back.
    override fun onResume() {
        super.onResume()
        if (canScheduleExactAlarms()) {
            AlarmScheduler.scheduleNext(this, "audio")
            AlarmScheduler.scheduleNext(this, "adhan")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ctx = applicationContext

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "adhan/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sync" -> {
                        val scheduleId = call.argument<String>("scheduleId") ?: "audio"
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        AlarmScheduler.save(
                            ctx, scheduleId, enabled,
                            call.argument<Int>("hour") ?: 8,
                            call.argument<Int>("minute") ?: 0,
                            call.argument<Int>("stopHour") ?: -1,
                            call.argument<Int>("stopMinute") ?: 0,
                            call.argument<List<String>>("paths") ?: emptyList(),
                            call.argument<String>("label") ?: "Adhan",
                            call.argument<Int>("reminderMinutes") ?: 10
                        )

                        if (enabled && !canScheduleExactAlarms()) {
                            requestExactAlarmPermission()
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        if (enabled) AlarmScheduler.scheduleNext(ctx, scheduleId)
                        else AlarmScheduler.cancel(ctx, scheduleId)
                        result.success(AlarmScheduler.nextStartMillis(ctx, scheduleId))
                    }
                    "testReminderNotification" -> {
                        PreAdhanReminderReceiver.show(ctx, "adhan_fajr")
                        result.success(null)
                    }
                    "playNow" -> {
                        val scheduleId = call.argument<String>("scheduleId") ?: "audio"
                        PlaybackService.start(ctx, scheduled = false, scheduleId = scheduleId)
                        result.success(null)
                    }
                    "stop" -> {
                        PlaybackService.stop(ctx)
                        result.success(null)
                    }
                    "openBatterySettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}