package com.example.klick

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
 * KlickBackgroundService — Foreground Service that keeps the app's process alive
 * when the user backgrounds the app. This allows nearby_connections Bluetooth
 * callbacks to keep firing and notifications to be delivered.
 */
class KlickBackgroundService : Service() {

    companion object {
        const val CHANNEL_ID = "klick_foreground_service"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.example.klick.START_FOREGROUND"
        const val ACTION_STOP = "com.example.klick.STOP_FOREGROUND"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                // Start as foreground with persistent notification
                startForeground(NOTIFICATION_ID, buildNotification())
            }
        }
        // Restart if killed by system — keeps Bluetooth alive
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        // App was swiped away — keep running so connections stay alive
        super.onTaskRemoved(rootIntent)
    }

    private fun buildNotification(): Notification {
        // Tapping the notification opens the app
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Klick Radio Active")
            .setContentText("Keeping your Bluetooth connections alive")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentIntent(pendingIntent)
            .setOngoing(true)           // Cannot be swiped away by user
            .setSilent(true)            // No sound for the persistent status notification
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Klick Radio Service",
                NotificationManager.IMPORTANCE_LOW   // Low = silent, no heads-up
            ).apply {
                description = "Keeps Klick Bluetooth connections active in the background"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
}
