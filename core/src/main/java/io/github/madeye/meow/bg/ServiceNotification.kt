package io.github.madeye.meow.bg

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.os.Build
import androidx.core.app.NotificationCompat

class ServiceNotification(
    private val service: Service,
    profileName: String,
    channelId: String,
) {
    companion object {
        private const val NOTIFICATION_ID = 1
    }

    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = service.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(channelId, "Mihomo VPN Service", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val notification = NotificationCompat.Builder(service, channelId)
            .setContentTitle("Mihomo")
            .setContentText(if (profileName.isNotEmpty()) "Connected: $profileName" else "Connecting...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
        service.startForeground(NOTIFICATION_ID, notification)
    }

    fun destroy() {
        service.stopForeground(Service.STOP_FOREGROUND_REMOVE)
    }
}
