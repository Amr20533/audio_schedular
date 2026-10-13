package com.example.audio_scheduler

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONArray
import java.util.Calendar
import java.util.Date

/**
 * Supports six fully independent daily schedules:
 *  - "audio": Home screen's general playlist
 *  - "adhan_fajr", "adhan_dhuhr", "adhan_asr", "adhan_maghrib", "adhan_isha":
 *    one alarm per prayer, each auto-armed, no manual trigger needed.
 * Each has its own prefs keys and AlarmManager request codes.
 */
object AlarmScheduler {
    private const val PREFS = "adhan_prefs"

    val adhanScheduleIds = listOf("adhan_fajr", "adhan_dhuhr", "adhan_asr", "adhan_maghrib", "adhan_isha")

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun key(scheduleId: String, name: String) = "${scheduleId}_$name"
    private fun isAdhan(scheduleId: String) = scheduleId.startsWith("adhan_")

    fun save(
        ctx: Context, scheduleId: String, enabled: Boolean, hour: Int, minute: Int,
        stopHour: Int, stopMinute: Int, paths: List<String>, label: String, reminderMinutes: Int
    ) {
        Log.d("AdhanDebug", "AlarmScheduler.save[$scheduleId] enabled=$enabled hour=$hour minute=$minute paths=${paths.size}")
        prefs(ctx).edit()
            .putBoolean(key(scheduleId, "enabled"), enabled)
            .putInt(key(scheduleId, "hour"), hour).putInt(key(scheduleId, "minute"), minute)
            .putInt(key(scheduleId, "stopHour"), stopHour).putInt(key(scheduleId, "stopMinute"), stopMinute)
            .putString(key(scheduleId, "paths"), JSONArray(paths).toString())
            .putString(key(scheduleId, "label"), label)
            .putInt(key(scheduleId, "reminderMinutes"), reminderMinutes)
            .apply()
    }

    fun loadPaths(ctx: Context, scheduleId: String): List<String> {
        val arr = JSONArray(prefs(ctx).getString(key(scheduleId, "paths"), "[]"))
        return List(arr.length()) { arr.getString(it) }
    }

    fun label(ctx: Context, scheduleId: String): String =
        prefs(ctx).getString(key(scheduleId, "label"), if (isAdhan(scheduleId)) "Adhan" else "Audio") ?: "Audio"

    private fun reminderMinutes(ctx: Context, scheduleId: String): Int =
        prefs(ctx).getInt(key(scheduleId, "reminderMinutes"), 10)

    private fun nextOccurrence(hour: Int, minute: Int, after: Long): Long {
        val cal = Calendar.getInstance().apply {
            timeInMillis = after
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (cal.timeInMillis <= after) cal.add(Calendar.DAY_OF_YEAR, 1)
        return cal.timeInMillis
    }

    fun nextStartMillis(ctx: Context, scheduleId: String): Long? {
        val p = prefs(ctx)
        if (!p.getBoolean(key(scheduleId, "enabled"), false)) return null
        return nextOccurrence(
            p.getInt(key(scheduleId, "hour"), 8),
            p.getInt(key(scheduleId, "minute"), 0),
            System.currentTimeMillis()
        )
    }

    fun stopMillisFor(ctx: Context, scheduleId: String, startMillis: Long): Long? {
        val p = prefs(ctx)
        val h = p.getInt(key(scheduleId, "stopHour"), -1)
        if (h < 0) return null
        return nextOccurrence(h, p.getInt(key(scheduleId, "stopMinute"), 0), startMillis)
    }

    private fun requestCode(scheduleId: String): Int {
        if (scheduleId == "audio") return 1001
        val idx = adhanScheduleIds.indexOf(scheduleId)
        return if (idx >= 0) 1002 + idx else 1099
    }

    private fun reminderRequestCode(scheduleId: String) = requestCode(scheduleId) + 1000

    private fun alarmIntent(ctx: Context, scheduleId: String): PendingIntent {
        val intent = if (isAdhan(scheduleId))
            Intent(ctx, AdhanAlarmReceiver::class.java).putExtra("scheduleId", scheduleId)
        else
            Intent(ctx, AlarmReceiver::class.java)
        return PendingIntent.getBroadcast(
            ctx, requestCode(scheduleId), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun reminderIntent(ctx: Context, scheduleId: String): PendingIntent {
        val intent = Intent(ctx, PreAdhanReminderReceiver::class.java).putExtra("scheduleId", scheduleId)
        return PendingIntent.getBroadcast(
            ctx, reminderRequestCode(scheduleId), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun scheduleNext(ctx: Context, scheduleId: String): Boolean {
        val trigger = nextStartMillis(ctx, scheduleId) ?: run {
            Log.d("AdhanDebug", "scheduleNext[$scheduleId]: disabled or no time, cancelling")
            cancel(ctx, scheduleId)
            return false
        }
        Log.d("AdhanDebug", "scheduleNext[$scheduleId]: arming for ${Date(trigger)}")
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val show = PendingIntent.getActivity(
            ctx, requestCode(scheduleId), Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val armed = try {
            am.setAlarmClock(AlarmManager.AlarmClockInfo(trigger, show), alarmIntent(ctx, scheduleId))
            Log.d("AdhanDebug", "scheduleNext[$scheduleId]: armed successfully")
            true
        } catch (e: SecurityException) {
            Log.e("AdhanDebug", "scheduleNext[$scheduleId]: SecurityException", e)
            false
        }
        if (armed && isAdhan(scheduleId)) armReminder(ctx, scheduleId, trigger)
        return armed
    }

    /** Arms every prayer alarm at once — called automatically on app launch, no button needed. */
    fun scheduleAllAdhan(ctx: Context) {
        adhanScheduleIds.forEach { scheduleNext(ctx, it) }
    }

    private fun armReminder(ctx: Context, scheduleId: String, mainTrigger: Long) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val minutesBefore = reminderMinutes(ctx, scheduleId)
        val reminderTrigger = mainTrigger - minutesBefore * 60_000L
        if (reminderTrigger <= System.currentTimeMillis()) {
            am.cancel(reminderIntent(ctx, scheduleId))
            return
        }
        try {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, reminderTrigger, reminderIntent(ctx, scheduleId))
            Log.d("AdhanDebug", "armReminder[$scheduleId]: armed for ${Date(reminderTrigger)}")
        } catch (e: SecurityException) {
            Log.e("AdhanDebug", "armReminder[$scheduleId]: SecurityException", e)
        }
    }

    fun cancel(ctx: Context, scheduleId: String) {
        Log.d("AdhanDebug", "AlarmScheduler.cancel[$scheduleId]")
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmIntent(ctx, scheduleId))
        if (isAdhan(scheduleId)) am.cancel(reminderIntent(ctx, scheduleId))
    }
}