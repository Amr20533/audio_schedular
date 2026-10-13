package com.example.audio_scheduler

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import java.io.File

/**
 * Plays whichever schedule ([scheduleId]: "audio" or "adhan") triggered it.
 * Requests audio focus unconditionally, regardless of whether anything else
 * is currently playing — this interrupts other apps and lets them resume
 * once playback ends, every time, with the app locked or not.
 */
class PlaybackService : Service() {

    private var player: MediaPlayer? = null
    private var playlist: List<String> = emptyList()
    private var index = 0
    private var failures = 0
    private var loop = false
    private var scheduleId = "audio"
    private val handler = Handler(Looper.getMainLooper())

    private val audioManager by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }
    private var focusRequest: AudioFocusRequest? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AdhanDebug", "PlaybackService.onStartCommand action=${intent?.action}")

        if (intent?.action == ACTION_STOP) {
            Log.d("AdhanDebug", "PlaybackService: stop requested")
            stopSelf()
            return START_NOT_STICKY
        }

        scheduleId = intent?.getStringExtra(EXTRA_SCHEDULE_ID) ?: "audio"
        startInForeground()
        requestAudioFocus()

        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        playlist = AlarmScheduler.loadPaths(this, scheduleId).filter { File(it).exists() }
        Log.d("AdhanDebug", "PlaybackService[$scheduleId]: loaded playlist, ${playlist.size} playable file(s)")
        index = 0
        failures = 0

        val stopAt = intent?.getLongExtra(EXTRA_STOP_AT, 0L) ?: 0L
        loop = stopAt > 0L
        if (stopAt > 0L) {
            val delay = (stopAt - System.currentTimeMillis()).coerceAtLeast(0L)
            handler.postDelayed({ stopSelf() }, delay)
        }

        if (playlist.isEmpty()) {
            Log.w("AdhanDebug", "PlaybackService[$scheduleId]: playlist is EMPTY — stopping")
            stopSelf()
            return START_NOT_STICKY
        }
        playCurrent()
        return START_NOT_STICKY
    }

    private fun playCurrent() {
        if (index >= playlist.size) {
            if (loop) index = 0 else {
                Log.d("AdhanDebug", "PlaybackService[$scheduleId]: playlist finished")
                stopSelf(); return
            }
        }
        releasePlayer()
        val path = playlist[index]
        Log.d("AdhanDebug", "PlaybackService[$scheduleId]: playing [$index] $path")
        try {
            val mp = MediaPlayer()
            player = mp
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            mp.setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
            mp.setDataSource(path)
            mp.setOnPreparedListener {
                Log.d("AdhanDebug", "PlaybackService[$scheduleId]: prepared, starting playback")
                failures = 0
                it.start()
            }
            mp.setOnCompletionListener { handler.post { index++; playCurrent() } }
            mp.setOnErrorListener { _, what, extra ->
                Log.e("AdhanDebug", "PlaybackService[$scheduleId]: MediaPlayer error what=$what extra=$extra for $path")
                handler.post { onTrackFailed() }
                true
            }
            mp.prepareAsync()
        } catch (e: Exception) {
            Log.e("AdhanDebug", "PlaybackService[$scheduleId]: exception starting $path", e)
            onTrackFailed()
        }
    }

    private fun onTrackFailed() {
        failures++
        if (failures >= playlist.size) {
            Log.w("AdhanDebug", "PlaybackService[$scheduleId]: all tracks failed, stopping")
            stopSelf(); return
        }
        index++
        playCurrent()
    }

    private fun releasePlayer() {
        player?.let { try { it.release() } catch (_: Exception) {} }
        player = null
    }

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= 26) {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attrs)
                .setWillPauseWhenDucked(false)
                .build()
            focusRequest = request
            val result = audioManager.requestAudioFocus(request)
            Log.d("AdhanDebug", "requestAudioFocus result=$result")
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            )
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= 26) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }

    private fun startInForeground() {
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Audio playback", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val label = AlarmScheduler.label(this, scheduleId)
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
            .setContentTitle("Playing $label")
            .setContentText("Tap Stop to end playback early")
            .setContentIntent(openApp)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stop)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIF_ID, notification)
        }
        Log.d("AdhanDebug", "PlaybackService[$scheduleId]: foreground notification shown")
    }

    override fun onDestroy() {
        Log.d("AdhanDebug", "PlaybackService[$scheduleId].onDestroy")
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        abandonAudioFocus()
        super.onDestroy()
    }

    companion object {
        const val ACTION_STOP = "com.example.audio_scheduler.action.STOP"
        private const val EXTRA_STOP_AT = "stop_at"
        private const val EXTRA_SCHEDULE_ID = "schedule_id"
        private const val CHANNEL_ID = "playback"
        private const val NOTIF_ID = 42

        fun start(ctx: Context, scheduled: Boolean, scheduleId: String = "audio") {
            Log.d("AdhanDebug", "PlaybackService.start(scheduled=$scheduled, scheduleId=$scheduleId)")
            val intent = Intent(ctx, PlaybackService::class.java)
                .putExtra(EXTRA_SCHEDULE_ID, scheduleId)
            if (scheduled) {
                AlarmScheduler.stopMillisFor(ctx, scheduleId, System.currentTimeMillis())
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