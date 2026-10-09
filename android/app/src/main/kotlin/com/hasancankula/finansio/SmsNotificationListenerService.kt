package com.hasancankula.finansio

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

const val SMS_LISTENER_CHANNEL = "com.hasancankula.finansio/sms_listener"

class SmsNotificationListenerService : NotificationListenerService() {

    companion object {
        @Volatile
        var messenger: BinaryMessenger? = null

        fun emitPayload(payload: String) {
            messenger?.let { m ->
                MethodChannel(m, SMS_LISTENER_CHANNEL).invokeMethod("onNotification", payload)
            }
        }

        fun emitConnected(connected: Boolean) {
            messenger?.let { m ->
                MethodChannel(m, SMS_LISTENER_CHANNEL).invokeMethod("onListenerConnected", connected)
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        sbn ?: return
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        if (text.isBlank()) return

        val joined = if (title.isNotBlank()) "$title $text" else text
        emitPayload(joined)
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        emitConnected(true)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        emitConnected(false)
    }
}
