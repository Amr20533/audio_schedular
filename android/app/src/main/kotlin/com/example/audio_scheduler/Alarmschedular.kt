package com.example.adhan_player

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import java.util.Calendar

/**
 * Stores the schedule + playlist (so the alarm works with the app closed and
 * after reboot) and arms the next daily alarm.
 *
 * Uses setAlarmClock(): exact, survives Doze, and needs no special permission.
 * Trade-off: Android shows a small "alarm" icon in the status bar.
 */
object AlarmScheduler {
    private const val PREFS = "adhan_prefs"
    private const val REQUEST_CODE = 1001

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(
        ctx: Context, enabled: Boolean, hour: Int, minute: Int,
        stopHour: Int, stopMinute: Int, paths: List<String>
    ) {
        prefs(ctx).edit()
            .putBoolean("enabled", enabled)
            .putInt("hour", hour).putInt("minute", minute)
            .putInt("stopHour", stopHour).putInt("stopMinute", stopMinute)
            .putString("paths", JSONArray(paths).toString())
            .apply()
    }

    fun loadPaths(ctx: Context): List<String> {
        val arr = JSONArray(prefs(ctx).getString("paths", "[]"))
        return List(arr.length()) { arr.getString(it) }
    }

    /** Next wall-clock occurrence of hour:minute strictly after [after]. */
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

    fun nextStartMillis(ctx: Context): Long? {
        val p = prefs(ctx)
        if (!p.getBoolean("enabled", false)) return null
        return nextOccurrence(p.getInt("hour", 8), p.getInt("minute", 0), System.currentTimeMillis())
    }

    /** When a run that starts at [startMillis] should stop, or null if no stop time is set. */
    fun stopMillisFor(ctx: Context, startMillis: Long): Long? {
        val p = prefs(ctx)
        val h = p.getInt("stopHour", -1)
        if (h < 0) return null
        return nextOccurrence(h, p.getInt("stopMinute", 0), startMillis)
    }

    private fun alarmIntent(ctx: Context): PendingIntent =
        PendingIntent.getBroadcast(
            ctx, REQUEST_CODE, Intent(ctx, AlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    fun scheduleNext(ctx: Context) {
        val trigger = nextStartMillis(ctx) ?: run { cancel(ctx); return }
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val show = PendingIntent.getActivity(
            ctx, 0, Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        am.setAlarmClock(AlarmManager.AlarmClockInfo(trigger, show), alarmIntent(ctx))
    }

    fun cancel(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmIntent(ctx))
    }
}