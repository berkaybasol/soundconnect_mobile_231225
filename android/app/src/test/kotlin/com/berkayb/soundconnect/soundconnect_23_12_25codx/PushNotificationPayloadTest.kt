package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test
import java.util.UUID

class PushNotificationPayloadTest {
    private val now = 1000000L
    private val host = "example.cloudfront.net"
    private fun message() = mapOf("presentationVersion" to "ANDROID_DM_V1", "type" to "DM_NEW_MESSAGE",
        "notificationId" to UUID.randomUUID().toString(), "recipientId" to UUID.randomUUID().toString(),
        "conversationId" to UUID.randomUUID().toString(), "senderName" to "Deniz",
        "sentAt" to now.toString(), "expiresAt" to (now + 60000).toString(),
        "senderAvatarUrl" to "https://$host/media/a.png")
    @Test fun validMessageHasIdentityIndependentNavigationAndFixedBody() {
        val data = message() + ("body" to "Do not show original message")
        val parsed = PushNotificationPayload.parse(data, now, host)!!
        assertEquals("Deniz", parsed.senderName)
        assertEquals(data["conversationId"], parsed.target()["conversationId"])
        assertFalse(parsed.target().containsKey("senderName"))
        assertEquals("Sana bir mesaj gönderdi.", PushNotificationPayload.BODY)
    }
    @Test fun malformedAndExpiredMessagesNeverRender() {
        for ((key, value) in listOf("type" to "OTHER", "presentationVersion" to "UNKNOWN",
            "notificationId" to "x", "recipientId" to "x", "conversationId" to "x",
            "expiresAt" to now.toString(), "expiresAt" to Long.MAX_VALUE.toString())) {
            assertNull(PushNotificationPayload.parse(message() + (key to value), now, host))
        }
    }
    @Test fun arbitraryOrSignedAvatarOriginsFallBackWithoutLosingNotification() {
        for (url in listOf("http://$host/a", "https://127.0.0.1/a", "https://$host.evil.invalid/a",
            "https://user@$host/a", "https://$host:8443/a", "https://$host/a?secret=x", "https://$host/a#x")) {
            val parsed = PushNotificationPayload.parse(message() + ("senderAvatarUrl" to url), now, host)!!
            assertNull(parsed.avatarUrl)
            assertEquals("Deniz", parsed.senderName)
        }
    }
    @Test fun controlCharactersAndFutureTimestampsCannotSpoofSystemUi() {
        val parsed = PushNotificationPayload.parse(message() + mapOf("senderName" to " A\n\u202EB\t ",
            "sentAt" to (now + 60000).toString()), now, host)!!
        assertEquals("AB", parsed.senderName)
        assertEquals(now, parsed.sentAt)
    }
}
