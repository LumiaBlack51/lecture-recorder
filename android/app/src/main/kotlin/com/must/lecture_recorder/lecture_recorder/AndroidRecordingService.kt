package com.must.lecture_recorder.lecture_recorder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class AndroidRecordingService : Service(), RecordingEventListener {
    private val notificationHandler = Handler(Looper.getMainLooper())
    private val notificationRefreshRunnable = object : Runnable {
        override fun run() {
            refreshNotification()
            if (RecordingCoordinator.hasActiveRecording()) {
                notificationHandler.postDelayed(this, 1000L)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        RecordingCoordinator.addListener(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            actionStop -> {
                RecordingCoordinator.stopRecording()
                return START_NOT_STICKY
            }
            actionTogglePause -> {
                val snapshot = RecordingCoordinator.getRecordingState()
                val isPaused = snapshot?.get("isPaused") as? Boolean ?: false
                if (isPaused) {
                    RecordingCoordinator.resumeRecording()
                } else {
                    RecordingCoordinator.pauseRecording()
                }
            }
        }

        startForegroundCompat(buildNotification())
        startNotificationTicker()
        return START_STICKY
    }

    override fun onDestroy() {
        notificationHandler.removeCallbacksAndMessages(null)
        RecordingCoordinator.removeListener(this)
        super.onDestroy()
    }

    override fun onRecordingEvent(event: Map<String, Any?>) {
        refreshNotification()

        if ((event["type"] as? String) == "stopped") {
            notificationHandler.removeCallbacksAndMessages(null)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
            return
        }
        startForeground(notificationId, notification)
    }

    private fun buildNotification(): Notification {
        val snapshot = RecordingCoordinator.getRecordingState()
        val isPaused = snapshot?.get("isPaused") as? Boolean ?: false
        val courseName = snapshot?.get("courseName") as? String
        val segmentIndex = (snapshot?.get("segmentIndex") as? Number)?.toInt() ?: 0
        val elapsedMillis = (snapshot?.get("elapsedMillis") as? Number)?.toLong() ?: 0L

        val title = if (isPaused) {
            getString(R.string.notification_title_paused)
        } else {
            getString(R.string.notification_title_recording)
        }
        val text = if (courseName.isNullOrBlank()) {
            getString(R.string.notification_text_idle)
        } else {
            getString(
                R.string.notification_text_progress,
                courseName,
                segmentIndex.toString().padStart(2, '0'),
                formatElapsed(elapsedMillis),
            )
        }
        val bigText = if (courseName.isNullOrBlank()) {
            text
        } else {
            getString(
                if (isPaused) {
                    R.string.notification_text_paused
                } else {
                    R.string.notification_text_recording
                },
                courseName,
            )
        }

        val launchIntent = (packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val launchPendingIntent = PendingIntent.getActivity(
            this,
            1001,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val togglePauseIntent = Intent(this, AndroidRecordingService::class.java).apply {
            action = actionTogglePause
        }
        val togglePausePendingIntent = PendingIntent.getService(
            this,
            1002,
            togglePauseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val stopIntent = Intent(this, AndroidRecordingService::class.java).apply {
            action = actionStop
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1003,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, notificationChannelId)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(launchPendingIntent)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(
                0,
                getString(
                    if (isPaused) {
                        R.string.notification_action_resume
                    } else {
                        R.string.notification_action_pause
                    },
                ),
                togglePausePendingIntent,
            )
            .addAction(
                0,
                getString(R.string.notification_action_stop),
                stopPendingIntent,
            )
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            notificationChannelId,
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.notification_channel_description)
            setShowBadge(false)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun refreshNotification() {
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(notificationId, buildNotification())
    }

    private fun startNotificationTicker() {
        notificationHandler.removeCallbacksAndMessages(null)
        notificationHandler.post(notificationRefreshRunnable)
    }

    private fun formatElapsed(elapsedMillis: Long): String {
        val totalSeconds = (elapsedMillis / 1000L).coerceAtLeast(0L)
        val hours = totalSeconds / 3600L
        val minutes = (totalSeconds % 3600L) / 60L
        val seconds = totalSeconds % 60L
        return "%02d:%02d:%02d".format(hours, minutes, seconds)
    }

    companion object {
        private const val notificationChannelId = "lecture_recorder_background_v2"
        private const val notificationId = 4106
        private const val actionTogglePause =
            "com.must.lecture_recorder.lecture_recorder.action.TOGGLE_PAUSE"
        private const val actionStop =
            "com.must.lecture_recorder.lecture_recorder.action.STOP"

        fun start(context: Context) {
            val intent = Intent(context, AndroidRecordingService::class.java)
            ContextCompat.startForegroundService(context, intent)
        }
    }
}
