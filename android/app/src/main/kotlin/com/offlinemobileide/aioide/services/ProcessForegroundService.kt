package com.offlinemobileide.aioide.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.offlinemobileide.aioide.MainActivity
import com.offlinemobileide.aioide.R

/**
 * ProcessForegroundService
 *
 * Android Foreground Service that keeps the process alive during long-running
 * code execution sessions (Python, JavaScript, future runtimes).
 *
 * This service must be started before any execution that is expected to
 * take longer than approximately 30 seconds, to prevent Android from
 * killing the process when the app goes to the background.
 *
 * Architecture: 04-RUNTIME-SYSTEM.md §5.4, NFR-008, CON-004
 *
 * Lifecycle:
 *   Started:  When ProcessManager determines execution may be long-running
 *   Stopped:  When the execution completes, times out, or is cancelled
 *
 * TODO (Phase 4): Wire this service to ProcessChannel and ProcessManager.
 *   Add a "Stop" action to the notification that cancels the running process.
 */
class ProcessForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "ide_process_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "com.offlinemobileide.aioide.ACTION_STOP_PROCESS"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(NOTIFICATION_ID, buildNotification())
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        // Phase 4: notify ProcessManager that service was stopped
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, ProcessForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val openIntent = Intent(this, MainActivity::class.java)
        val openPendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Code is running")
            .setContentText("Tap to return to the IDE")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(openPendingIntent)
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_delete,
                    "Stop",
                    stopPendingIntent
                ).build()
            )
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Code Execution",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shown while code is running in the background"
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
