package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.Context
import android.content.Intent

/** Shared by warm delivery and the delayed cold-start handoff to Dart. */
internal object NativePushOpen {
    fun target(context: Context, intent: Intent?): Map<String, String>? {
        if (!PushFeatureGate.enabled(context) || intent == null || !PushOpenTarget.supports(intent.action)) return null
        val target = PushOpenTarget.parse(intent.action,
            PushOpenTarget.fields.associateWith { intent.getStringExtra("sc.push.$it") }) ?: return null
        if (intent.action == PushOpenTarget.NOTIFICATION_ACTION) {
            val epoch = PushNotificationPayload.uuid(intent.getStringExtra(PushDeliveredPolicy.EPOCH_EXTRA))
            val binding = epoch?.let { PushNotificationState.Binding(target.getValue("recipientId"), it) }
            if (target["type"] in VenuePushPayload.collabTypes || target["type"] in VenuePushPayload.tableTypes || target["type"] in setOf("SOCIAL_NEW_FOLLOWER", "SOCIAL_NEW_BAND_FOLLOWER", "SOCIAL_LIKE", "SOCIAL_COMMENT",
                    "BAND_INVITE_RECEIVED", "BAND_INVITE_ACCEPTED", "BAND_INVITE_REJECTED", "BAND_MEMBER_REMOVED", "BAND_MEMBER_LEFT")) {
                if (binding == null || !PushNotificationState.current(context, binding)) return null
            }
            if (binding != null) try {
                // OS dismissal is distinct from a server read receipt.
                PushNotificationState.dismissNotification(context, binding, target.getValue("notificationId"))
            } catch (_: Exception) { /* Dart independently authorizes exact lookup and ACK. */ }
        }
        return target
    }
}
