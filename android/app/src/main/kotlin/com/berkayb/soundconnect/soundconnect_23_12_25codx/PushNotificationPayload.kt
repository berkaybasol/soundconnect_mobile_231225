package com.berkayb.soundconnect.soundconnect_23_12_25codx

import java.net.URI
import java.util.UUID

/** Data contract only. Neither message text nor identity drives navigation. */
data class PushNotificationPayload(
    val notificationId: String,
    val recipientId: String,
    val conversationId: String,
    val senderName: String,
    val avatarUrl: String?,
    val sentAt: Long,
    val expiresAt: Long
) {
    fun target(): Map<String, String> = mapOf(
        "notificationId" to notificationId, "recipientId" to recipientId,
        "conversationId" to conversationId, "type" to "DM_NEW_MESSAGE"
    )
    companion object {
        const val VERSION = "ANDROID_DM_V1"
        const val BODY = "Sana bir mesaj gönderdi."
        private val uuidPattern = Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
        fun uuid(value: String?): String? = value?.takeIf { uuidPattern.matches(it) }?.let { UUID.fromString(it).toString() }
        fun parse(data: Map<String, String>, now: Long, allowedAvatarHost: String): PushNotificationPayload? {
            if (data["presentationVersion"] != VERSION || data["type"] != "DM_NEW_MESSAGE") return null
            val notification = uuid(data["notificationId"]) ?: return null
            val recipient = uuid(data["recipientId"]) ?: return null
            val conversation = uuid(data["conversationId"]) ?: return null
            val expiry = data["expiresAt"]?.toLongOrNull() ?: return null
            if (expiry <= now || expiry - now > 28L * 86400 * 1000) return null
            val rawName = data["senderName"].orEmpty().codePoints()
                .filter { !Character.isISOControl(it) && Character.getType(it) != Character.FORMAT.toInt() }
                .limit(80).toArray()
            val name = String(rawName, 0, rawName.size).trim().ifEmpty { "Kullanıcı" }
            val sent = data["sentAt"]?.toLongOrNull()?.coerceIn(0, now) ?: now
            return PushNotificationPayload(notification, recipient, conversation, name,
                safeAvatar(data["senderAvatarUrl"], allowedAvatarHost), sent, expiry)
        }
        fun safeAvatar(raw: String?, allowedHost: String): String? {
            if (raw == null || raw.length > 1500 || allowedHost.isBlank()) return null
            return try {
                val uri = URI(raw)
                raw.takeIf { uri.scheme.equals("https", true) && uri.host.equals(allowedHost, true)
                    && uri.userInfo == null && uri.rawQuery == null && uri.fragment == null
                    && (uri.port == -1 || uri.port == 443) }
            } catch (_: Exception) { null }
        }
    }
}
