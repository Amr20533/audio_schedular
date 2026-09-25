package com.example.adhan_player

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 13+: needed so the playback notification is visible.
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ctx = applicationContext

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "adhan/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sync" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        AlarmScheduler.save(
                            ctx,
                            enabled,
                            call.argument<Int>("hour") ?: 8,
                            call.argument<Int>("minute") ?: 0,
                            call.argument<Int>("stopHour") ?: -1,
                            call.argument<Int>("stopMinute") ?: 0,
                            call.argument<List<String>>("paths") ?: emptyList()
                        )
                        if (enabled) AlarmScheduler.scheduleNext(ctx) else AlarmScheduler.cancel(ctx)
                        result.success(AlarmScheduler.nextStartMillis(ctx))
                    }
                    "playNow" -> {
                        PlaybackService.start(ctx, scheduled = false)
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