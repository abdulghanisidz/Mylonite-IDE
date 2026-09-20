package com.offlinemobileide.aioide.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.offlinemobileide.aioide.MainActivity

/**
 * InferenceForegroundService
 *
 * Android Foreground Service that keeps the process alive during AI model
 * inference sessions. Required because LLM inference can take many seconds
 * to minutes, and Android will kill background processes aggressively.
 *
 * Architecture: 05-OFFLINE-AI.md §13.4, NFR-008, CON-004
 *
 * Lifecycle:
 *   Started:  When LocalAIProvider begins a generation session
 *   Stopped:  When generation completes, is cancelled, or model is unloaded
 *
 * TODO (Phase 9): Wire this service to LocalAIProvider (Dart FFI layer).
 *   Update notification text dynamically (model name, tokens/sec).
 *   Add cancel action that triggers generation cancellation via abort flag.
 */
class InferenceForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "ide_inference_channel"
        const val NOTIFICATION_ID = 1002
        const val ACTION_CANCEL = "com.offlinemobileide.aioide.ACTION_CANCEL_INFERENCE"
        const val EXTRA_MODEL_NAME = "model_name"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL) {
            stopSelf()
            return START_NOT_STICKY
        }
        val modelName = intent?.getStringExtra(EXTRA_MODEL_NAME) ?: "Local Model"
        startForeground(NOTIFICATION_ID, buildNotification(modelName))
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        // Phase 9: signal cancellation to the FFI inference loop
    }

    private fun buildNotification(modelName: String): Notification {
        val cancelIntent = Intent(this, InferenceForegroundService::class.java).apply {
            action = ACTION_CANCEL
        }
        val cancelPendingIntent = PendingIntent.getService(
            this, 0, cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val openIntent = Intent(this, MainActivity::class.java)
        val openPendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("AI is thinking")
            .setContentText("$modelName is generating a response")
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setContentIntent(openPendingIntent)
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_delete,
                    "Cancel",
                    cancelPendingIntent
                ).build()
            )
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "AI Inference",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shown while an AI model is generating a response"
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
