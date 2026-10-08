package com.berkayb.soundconnect.soundconnect_23_12_25codx

/** Versioned display data only. An authenticated, owned source authorizes navigation. */
internal data class VenuePushPayload(
    val notificationId: String,
    val recipientId: String,
    val type: String,
    val displayVariant: String,
    val sentAt: Long,
    val expiresAt: Long,
    val customTitle: String? = null,
    val customBody: String? = null
) {
    val isCustom: Boolean get() = type == CUSTOM_TYPE
    val title: String get() = if (isCustom) requireNotNull(customTitle) else "Soundconnect"
    val body: String get() = if (isCustom) requireNotNull(customBody) else requireNotNull(bodyFor(type, displayVariant))
    fun hasValidDisplay(): Boolean = if (isCustom) {
        displayVariant == "DEFAULT" && validCustomText(customTitle, 120) && validCustomText(customBody, 500)
    } else customTitle == null && customBody == null && bodyFor(type, displayVariant) != null
    fun target(): Map<String, String> = mapOf(
        "notificationId" to notificationId, "recipientId" to recipientId, "type" to type)

    companion object {
        const val CUSTOM_TYPE = "ADMIN_BROADCAST"
        const val CUSTOM_VERSION = "ANDROID_CUSTOM_V1"
        const val VERSION = "ANDROID_VENUE_V1"
        const val APPLICATION_VERSION = "ANDROID_VENUE_APPLICATION_V1"
        const val STUDIO_VERSION = "ANDROID_STUDIO_V1"
        const val COLLAB_VERSION = "ANDROID_COLLAB_V1"
        const val OVERTHINKING_VERSION = "ANDROID_OVERTHINKING_V1"
        val overthinkingTypes = setOf("OVERTHINKING_REVEAL_REQUEST_RECEIVED",
            "OVERTHINKING_REVEAL_REQUEST_APPROVED", "OVERTHINKING_REVEAL_REQUEST_REJECTED")
        val collabTypes = setOf("COLLAB_APPLICATION_RECEIVED",
            "COLLAB_APPLICATION_ACCEPTED",
            "COLLAB_APPLICATION_REJECTED",
            "COLLAB_APPLICATION_WITHDRAWN",
            "COLLAB_APPLICATION_INVALIDATED",
            "COLLAB_LISTING_EXPIRED",
            "COLLAB_JOB_COMPLETION_REQUESTED",
            "COLLAB_JOB_COMPLETED",
            "COLLAB_REVIEW_RECEIVED",
            "COLLAB_LISTING_REMOVED",
            "COLLAB_REPORT_RESOLVED")
        const val TABLE_VERSION = "ANDROID_TABLE_V1"
        val tableTypes = setOf("TABLE_JOIN_REQUEST_RECEIVED", "TABLE_JOIN_REQUEST_APPROVED",
            "TABLE_JOIN_REQUEST_REJECTED", "TABLE_PARTICIPANT_LEFT", "TABLE_REMOVED", "TABLE_CANCELLED", "TABLE_EXPIRED")
        const val BAND_VERSION = "ANDROID_BAND_V1"
        private val bandTypes = setOf("BAND_INVITE_RECEIVED", "BAND_INVITE_ACCEPTED", "BAND_INVITE_REJECTED",
            "BAND_MEMBER_REMOVED", "BAND_MEMBER_LEFT")
        const val MEDIA_VERSION = "ANDROID_MEDIA_V1"
        private val mediaTypes = setOf("SOCIAL_LIKE", "SOCIAL_COMMENT")
        const val FOLLOW_VERSION = "ANDROID_FOLLOW_V1"
        private val followTypes = setOf("SOCIAL_NEW_FOLLOWER", "SOCIAL_NEW_BAND_FOLLOWER")
        private val studioTypes = setOf("STUDIO_RESERVATION_CREATED", "STUDIO_RESERVATION_CONFLICTING_REQUESTS",
            "STUDIO_RESERVATION_APPROVED", "STUDIO_RESERVATION_REJECTED",
            "STUDIO_RESERVATION_CANCELLED_BY_CUSTOMER", "STUDIO_RESERVATION_CANCELLED_BY_STUDIO")
        private val applicationTypes = setOf("VENUE_APPLICATION_APPROVED", "VENUE_APPLICATION_REJECTED")
        private const val REQUEST = "EVENT_PERFORMER_APPROVAL_REQUESTED"
        private const val APPROVED = "EVENT_PERFORMER_APPROVED"
        private const val REJECTED = "EVENT_PERFORMER_REJECTED"
        private val fields = setOf("presentationVersion", "notificationId", "recipientId", "type",
            "displayVariant", "sentAt", "expiresAt")
        private val customFields = fields - "displayVariant" + setOf("title", "body")
        private val text = mapOf(
            ("OVERTHINKING_REVEAL_REQUEST_RECEIVED" to "DEFAULT") to "Anonim paylaşımına bir görüntüleme isteği geldi.",
            ("OVERTHINKING_REVEAL_REQUEST_APPROVED" to "DEFAULT") to "Profil görüntüleme isteğin kabul edildi.",
            ("OVERTHINKING_REVEAL_REQUEST_REJECTED" to "DEFAULT") to "Profil görüntüleme isteğin kabul edilmedi.",
            ("COLLAB_APPLICATION_RECEIVED" to "DEFAULT") to "İlanına yeni bir başvuru geldi.",
            ("COLLAB_APPLICATION_ACCEPTED" to "DEFAULT") to "İş birliği başvurun kabul edildi.",
            ("COLLAB_APPLICATION_REJECTED" to "DEFAULT") to "İş birliği başvurun kabul edilmedi.",
            ("COLLAB_APPLICATION_WITHDRAWN" to "DEFAULT") to "İlanına yapılan bir başvuru geri çekildi.",
            ("COLLAB_APPLICATION_INVALIDATED" to "DEFAULT") to "İş birliği başvurun geçersizleşti.",
            ("COLLAB_LISTING_EXPIRED" to "DEFAULT") to "İş birliği ilanının süresi doldu.",
            ("COLLAB_JOB_COMPLETION_REQUESTED" to "DEFAULT") to "İş birliğinin tamamlanması için onayın bekleniyor.",
            ("COLLAB_JOB_COMPLETED" to "DEFAULT") to "İş birliğin tamamlandı.",
            ("COLLAB_REVIEW_RECEIVED" to "DEFAULT") to "İş birliğin için yeni bir değerlendirme aldın.",
            ("COLLAB_LISTING_REMOVED" to "DEFAULT") to "İş birliği ilanın kaldırıldı.",
            ("COLLAB_REPORT_RESOLVED" to "REMOVE_LISTING") to "Bildirdiğin ilan kaldırıldı.",
            ("COLLAB_REPORT_RESOLVED" to "DISMISS") to "Bildirimin incelendi.",
            ("TABLE_JOIN_REQUEST_RECEIVED" to "DEFAULT") to "Masana yeni bir başvuru geldi.",
            ("TABLE_JOIN_REQUEST_APPROVED" to "DEFAULT") to "Masa başvurun kabul edildi.",
            ("TABLE_JOIN_REQUEST_REJECTED" to "DEFAULT") to "Masa başvurun kabul edilmedi.",
            ("TABLE_PARTICIPANT_LEFT" to "DEFAULT") to "Bir katılımcı masandan ayrıldı.",
            ("TABLE_REMOVED" to "DEFAULT") to "Masadan çıkarıldın.",
            ("TABLE_CANCELLED" to "OWNER_CANCELLED") to "Katıldığın masa kapatıldı.",
            ("TABLE_CANCELLED" to "OWNER_JOINED_ANOTHER_TABLE") to "Masa sahibi başka bir masaya katıldığı için masa kapatıldı.",
            ("TABLE_EXPIRED" to "DEFAULT") to "Katıldığın masanın süresi doldu.",
            ("BAND_INVITE_RECEIVED" to "DEFAULT") to "Yeni bir grup davetin var.",
            ("BAND_INVITE_ACCEPTED" to "DEFAULT") to "Grup davetin kabul edildi.",
            ("BAND_INVITE_REJECTED" to "DEFAULT") to "Grup davetin reddedildi.",
            ("BAND_MEMBER_REMOVED" to "DEFAULT") to "Grup üyeliğin sonlandırıldı.",
            ("BAND_MEMBER_LEFT" to "DEFAULT") to "Bir üye grubundan ayrıldı.",
            ("SOCIAL_LIKE" to "DEFAULT") to "İçeriğin yeni bir beğeni aldı.",
            ("SOCIAL_COMMENT" to "DEFAULT") to "İçeriğine yeni bir yorum yapıldı.",
            ("SOCIAL_NEW_FOLLOWER" to "DEFAULT") to "Yeni bir takipçin var.",
            ("SOCIAL_NEW_BAND_FOLLOWER" to "DEFAULT") to "Grubunun yeni bir takipçisi var.",
            ("ARTIST_VENUE_LINK_APPLICATION_REQUEST" to "DEFAULT") to "Yeni bir bağlantı isteğin var.",
            ("ARTIST_VENUE_LINK_APPLICATION_ACCEPT" to "DEFAULT") to "Bağlantı isteğin kabul edildi.",
            ("ARTIST_VENUE_LINK_APPLICATION_REJECT" to "DEFAULT") to "Bağlantı isteğin reddedildi.",
            (REQUEST to "DEFAULT") to "Bir etkinlik için katılım onayın bekleniyor.",
            (APPROVED to "DEFAULT") to "Etkinlik katılımı onaylandı.",
            (REJECTED to "DEFAULT") to "Etkinlik katılımı reddedildi.",
            (REQUEST to "PROFILE_VISIBILITY") to "Bir etkinliğin profilinde gösterilmesi için onayın bekleniyor.",
            (APPROVED to "PROFILE_VISIBILITY") to "Etkinliğin profilde gösterilmesi onaylandı.",
            (REJECTED to "PROFILE_VISIBILITY") to "Etkinliğin profilde gösterilmesi reddedildi.",
            (REQUEST to "PLAN_CONSENT") to "Etkinlik planına katılım onayın bekleniyor.",
            (APPROVED to "PLAN_CONSENT") to "Etkinlik planına katılım onaylandı.",
            (REJECTED to "PLAN_CONSENT") to "Etkinlik planına katılım reddedildi.",
            (REJECTED to "PLAN_WITHDRAWN") to "Etkinlik planına katılım geri çekildi.",
            ("VENUE_APPLICATION_APPROVED" to "DEFAULT") to "Mekân başvurun onaylandı.",
            ("VENUE_APPLICATION_REJECTED" to "DEFAULT") to "Mekân başvurun reddedildi.",
            ("STUDIO_RESERVATION_CREATED" to "STUDIO_CREATED_PENDING") to "Yeni bir stüdyo rezervasyon talebin var.",
            ("STUDIO_RESERVATION_CREATED" to "STUDIO_CREATED_CONFIRMED") to "Stüdyona yeni bir rezervasyon yapıldı.",
            ("STUDIO_RESERVATION_CONFLICTING_REQUESTS" to "STUDIO_CONFLICTING_REQUESTS") to "Çakışan stüdyo rezervasyon taleplerin var.",
            ("STUDIO_RESERVATION_APPROVED" to "STUDIO_APPROVED") to "Stüdyo rezervasyon talebin onaylandı.",
            ("STUDIO_RESERVATION_REJECTED" to "STUDIO_REJECTED") to "Stüdyo rezervasyon talebin reddedildi.",
            ("STUDIO_RESERVATION_REJECTED" to "STUDIO_REJECTED_CONFLICT") to "Çakışan bir talep onaylandığı için rezervasyon talebin reddedildi.",
            ("STUDIO_RESERVATION_CANCELLED_BY_CUSTOMER" to "STUDIO_CANCELLED_BY_CUSTOMER") to "Bir müşteri stüdyo rezervasyonunu iptal etti.",
            ("STUDIO_RESERVATION_CANCELLED_BY_STUDIO" to "STUDIO_CANCELLED_BY_STUDIO") to "Stüdyo rezervasyonun iptal edildi.",
            ("STUDIO_RESERVATION_CANCELLED_BY_STUDIO" to "STUDIO_ROOM_ARCHIVED") to "Oda arşivlendiği için stüdyo rezervasyonun iptal edildi."
        )
        fun supportsType(type: String?): Boolean = type == CUSTOM_TYPE || text.keys.any { it.first == type }
        fun bodyFor(type: String, variant: String): String? = text[type to variant]

        // Backend-normalized display text only. Never interpret markup, routes or
        // control/bidi formatting received from an untrusted Firebase message.
        internal fun validCustomText(value: String?, maxLength: Int): Boolean =
            value != null && value.isNotBlank() && value.length <= maxLength &&
                value == value.trim() && value.codePoints().noneMatch {
                    Character.isISOControl(it) || Character.getType(it) == Character.FORMAT.toInt() ||
                        Character.getType(it) == Character.SURROGATE.toInt() || it == 0x2028 || it == 0x2029
                }

        fun parse(data: Map<String, String>, now: Long): VenuePushPayload? {
            val type = data["type"] ?: return null
            val custom = type == CUSTOM_TYPE
            val overthinking = type in overthinkingTypes
            val expectedFields = when {
                custom -> customFields
                overthinking -> fields - "displayVariant"
                else -> fields
            }
            if (now < 0 || data.keys != expectedFields) return null
            // Each family has its own closed wire contract. Enrollment capability
            // is enforced by the backend; a newer family never downgrades here.
            val version = when (type) {
                CUSTOM_TYPE -> CUSTOM_VERSION
                in overthinkingTypes -> OVERTHINKING_VERSION
                in collabTypes -> COLLAB_VERSION
                in tableTypes -> TABLE_VERSION
                in bandTypes -> BAND_VERSION
                in mediaTypes -> MEDIA_VERSION
                in followTypes -> FOLLOW_VERSION
                in studioTypes -> STUDIO_VERSION
                in applicationTypes -> APPLICATION_VERSION
                else -> VERSION
            }
            if (data["presentationVersion"] != version) return null
            val variant = if (custom || overthinking) "DEFAULT" else data["displayVariant"] ?: return null
            if (custom) {
                if (!validCustomText(data["title"], 120) || !validCustomText(data["body"], 500)) return null
            } else if (bodyFor(type, variant) == null) return null
            val notification = PushNotificationPayload.uuid(data["notificationId"]) ?: return null
            val recipient = PushNotificationPayload.uuid(data["recipientId"]) ?: return null
            val expiry = data["expiresAt"]?.toLongOrNull() ?: return null
            if (expiry <= now || expiry - now > 28L * 86400 * 1000) return null
            val sent = data["sentAt"]?.toLongOrNull() ?: return null
            if (sent < 0 || sent >= expiry) return null
            // FOLLOW/MEDIA use the server's canonical positive decimal Long wire.
            // Positive operands and the ordering checks above make subtraction safe.
            if ((custom || overthinking || type in followTypes || type in mediaTypes || type in tableTypes || type in collabTypes) &&
                (data["sentAt"] != sent.toString() || data["expiresAt"] != expiry.toString())) return null
            // Fast delivery may beat a slightly slow device clock. Neither the
            // expiry-from-now limit above nor the actual payload lifetime is extended.
            if ((custom || overthinking || type in followTypes || type in mediaTypes || type in tableTypes || type in collabTypes || type in bandTypes) &&
                (sent <= 0 || sent - now > 5_000L || expiry - sent > 28L * 86400 * 1000)) return null
            return VenuePushPayload(notification, recipient, type, variant, sent.coerceAtMost(now), expiry,
                if (custom) data["title"] else null, if (custom) data["body"] else null)
        }
    }
}
