package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.Context
import android.content.Intent

/** Shared by warm delivery and the delayed cold-start handoff to Dart. */
internal object NativePushOpen {
    data class Accepted(val target: Map<String, String>, val binding: PushNotificationState.Binding)

    fun target(context: Context, intent: Intent?): Map<String, String>? = accept(context, intent)?.target

    fun accept(context: Context, intent: Intent?): Accepted? {
        if (!PushFeatureGate.enabled(context) || intent == null || !PushOpenTarget.supports(intent.action)) return null
        val target = PushOpenTarget.parse(intent.action,
            PushOpenTarget.fields.associateWith { intent.getStringExtra("sc.push.$it") }) ?: return null
        val binding = if (intent.action == PushOpenTarget.NOTIFICATION_ACTION) {
            val epoch = PushNotificationPayload.uuid(intent.getStringExtra(PushDeliveredPolicy.EPOCH_EXTRA)) ?: return null
            PushNotificationState.Binding(target.getValue("recipientId"), epoch)
        } else {
            // A repeatable conversation shortcut captures this user selection's
            // current session; a notification must retain its original epoch.
            PushNotificationState.capture(context, target.getValue("recipientId")) ?: return null
        }
        if (!PushNotificationState.current(context, binding)) return null
        if (intent.action == PushOpenTarget.NOTIFICATION_ACTION) {
            try {
                // OS dismissal is distinct from a server read receipt.
                PushNotificationState.dismissNotification(context, binding, target.getValue("notificationId"))
            } catch (_: Exception) { /* Dart independently authorizes exact lookup and ACK. */ }
        }
        // Dismissal may race a logout. Never replace the captured binding with
        // a newer one, even when the same recipient signs in again.
        if (!PushNotificationState.current(context, binding)) return null
        return Accepted(target, binding)
    }
}
