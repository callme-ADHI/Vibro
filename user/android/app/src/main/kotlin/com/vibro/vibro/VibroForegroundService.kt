package com.vibro.vibro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * VIBRO Foreground Service
 *
 * Keeps the app alive in the background so that:
 *  • Deaf phone: TCP server stays active waiting for Connected phone
 *  • Connected phone: TCP connection + speech recognition keeps running
 *
 * Start from MainActivity / Flutter via platform channel.
 */
class VibroForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "vibro_foreground_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.vibro.vibro.START_FOREGROUND"
        const val ACTION_STOP = "com.vibro.vibro.STOP_FOREGROUND"
        const val EXTRA_MODE = "mode"   // "deaf" or "connected"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val mode = intent?.getStringExtra(EXTRA_MODE) ?: "deaf"

        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(true)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val notification = buildNotification(mode)
                startForeground(NOTIFICATION_ID, notification)
            }
        }

        // Restart on kill to keep connection alive
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Reschedule ourselves if the task is swiped away
        val restartIntent = Intent(applicationContext, VibroForegroundService::class.java)
        restartIntent.setPackage(packageName)
        startService(restartIntent)
        super.onTaskRemoved(rootIntent)
    }

    private fun buildNotification(mode: String): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (mode == "deaf") "Vibro — Listening for alerts" else "Vibro — Connected & monitoring"
        val text = if (mode == "deaf") "Your phone is ready to receive name alerts via WiFi." 
                   else "Detecting names and sending alerts via WiFi."

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Vibro Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Vibro active in the background for real-time alerts"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
