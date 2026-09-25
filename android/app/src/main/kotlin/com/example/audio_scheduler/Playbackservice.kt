package com.example.adhan_player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import java.io.File

/**
 * Foreground service that plays the saved playlist in order.
 * - No stop time: plays the list once, then stops itself.
 * - Stop time set: loops the list until that time.
 */
class PlaybackService : Service() {

    private var player: MediaPlayer? = null
    private var playlist: List<String> = emptyList()
    private var index = 0
    private var failures = 0
    private var loop = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        startInForeground()

        // Reset (also covers a second start while already playing).
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        playlist = AlarmScheduler.loadPaths(this).filter { File(it).exists() }
        index = 0
        failures = 0

        val stopAt = intent?.getLongExtra(EXTRA_STOP_AT, 0L) ?: 0L
        loop = stopAt > 0L
        if (stopAt > 0L) {
            val delay = (stopAt - System.currentTimeMillis()).coerceAtLeast(0L)
            handler.postDelayed({ stopSelf() }, delay)
        }

        if (playlist.isEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }
        playCurrent()
        return START_NOT_STICKY
    }

    private fun playCurrent() {
        if (index >= playlist.size) {
            if (loop) index = 0 else { stopSelf(); return }
        }
        releasePlayer()
        try {
            val mp = MediaPlayer()
            player = mp
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    // Switch to USAGE_ALARM to play on the alarm volume instead.
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            mp.setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
            mp.setDataSource(playlist[index])
            mp.setOnPreparedListener { failures = 0; it.start() }
            mp.setOnCompletionListener { handler.post { index++; playCurrent() } }
            mp.setOnErrorListener { _, _, _ -> handler.post { onTrackFailed() }; true }
            mp.prepareAsync()
        } catch (e: Exception) {
            onTrackFailed()
        }
    }

    private fun onTrackFailed() {
        failures++
        if (failures >= playlist.size) { stopSelf(); return }  // nothing playable
        index++
        playCurrent()
    }

    private fun releasePlayer() {
        player?.let { try { it.release() } catch (_: Exception) {} }
        player = null
    }

    private fun startInForeground() {
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Audio playback", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        val stop = PendingIntent.getService(
            this, 1,
            Intent(this, PlaybackService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE
        )
        val builder =
            if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID)
            else Notification.Builder(this)
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Playing scheduled audio")
            .setContentIntent(openApp)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stop)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        super.onDestroy()
    }

    companion object {
        const val ACTION_STOP = "com.example.adhan_player.action.STOP"
        private const val EXTRA_STOP_AT = "stop_at"
        private const val CHANNEL_ID = "playback"
        private const val NOTIF_ID = 42

        fun start(ctx: Context, scheduled: Boolean) {
            val intent = Intent(ctx, PlaybackService::class.java)
            if (scheduled) {
                AlarmScheduler.stopMillisFor(ctx, System.currentTimeMillis())
                    ?.let { intent.putExtra(EXTRA_STOP_AT, it) }
            }
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(intent)
            else ctx.startService(intent)
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, PlaybackService::class.java))
        }
    }
}