package com.berkayb.soundconnect.soundconnect_23_12_25codx

import java.util.UUID

/** Validates navigation metadata without trusting an OS shortcut's cached identity. */
internal object PushOpenTarget {
    const val NOTIFICATION_ACTION = "com.soundconnect.OPEN_PUSH"
    const val CONVERSATION_ACTION = "com.soundconnect.OPEN_CONVERSATION"
    val fields = listOf("notificationId", "recipientId", "conversationId", "type")

    fun supports(action: String?): Boolean =
        action == NOTIFICATION_ACTION || action == CONVERSATION_ACTION

    fun parse(action: String?, extras: Map<String, String?>): Map<String, String>? {
        if (!supports(action)) return null
        val type = extras["type"]
        if (type != "DM_NEW_MESSAGE") {
            if (action != NOTIFICATION_ACTION || !VenuePushPayload.supportsType(type)
                || extras["conversationId"] != null) return null
            val recipient = PushNotificationPayload.uuid(extras["recipientId"]) ?: return null
            val notification = PushNotificationPayload.uuid(extras["notificationId"]) ?: return null
            return mapOf("notificationId" to notification, "recipientId" to recipient, "type" to type!!)
        }
        val recipient = PushNotificationPayload.uuid(extras["recipientId"]) ?: return null
        val conversation = PushNotificationPayload.uuid(extras["conversationId"]) ?: return null
        val eventId = if (action == CONVERSATION_ACTION) {
            // A shortcut is a repeatable user action, not a redelivered alert.
            // This ID only deduplicates navigation within Flutter. It is never
            // a server notification read ACK; chat visibility drives those ACKs.
            UUID.randomUUID().toString()
        } else {
            PushNotificationPayload.uuid(extras["notificationId"]) ?: return null
        }
        return mapOf("notificationId" to eventId, "recipientId" to recipient,
            "conversationId" to conversation, "type" to "DM_NEW_MESSAGE")
    }
}
