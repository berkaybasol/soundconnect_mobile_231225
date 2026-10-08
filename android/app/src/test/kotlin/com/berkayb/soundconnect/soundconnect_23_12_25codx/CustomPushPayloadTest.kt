package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test

class CustomPushPayloadTest {
    private val now = 1790000000000L
    private val ttl = 28L * 86400 * 1000
    private fun wire() = mapOf(
        "type" to "ADMIN_BROADCAST", "presentationVersion" to "ANDROID_CUSTOM_V1",
        "notificationId" to "50000000-0000-4000-8000-000000000001",
        "recipientId" to "70000000-0000-4000-8000-000000000001",
        "title" to "Soundconnect'te yeni bir şey var 🎵", "body" to "Birlikte müzik yapmaya hazır mısın?",
        "sentAt" to now.toString(), "expiresAt" to (now + 60_000).toString())

    @Test fun approvedDisplayCopyNeverEntersTheIdentityOnlyTap() {
        val data = wire()
        val payload = requireNotNull(VenuePushPayload.parse(data, now))
        assertTrue(payload.isCustom)
        assertTrue(payload.hasValidDisplay())
        assertEquals(data["title"], payload.title)
        assertEquals(data["body"], payload.body)
        assertEquals(setOf("notificationId", "recipientId", "type"), payload.target().keys)
        assertEquals(payload.target(), PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, payload.target()))
        assertNull(PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION, payload.target()))
        assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, payload.target() + ("conversationId" to payload.recipientId)))
        assertFalse(payload.copy(customTitle = "spoof\u202E").hasValidDisplay())
        assertFalse(payload.copy(customBody = null).hasValidDisplay())
        assertFalse(payload.copy(displayVariant = "OTHER").hasValidDisplay())
    }

    @Test fun exactEightFieldEnvelopeRejectsMissingExtraMixedVersionAndBadIdentity() {
        val data = wire()
        for (key in data.keys) assertNull(key, VenuePushPayload.parse(data - key, now))
        for (key in listOf("route", "url", "announcementId", "userId", "conversationId", "displayVariant", "avatarUrl"))
            assertNull(key, VenuePushPayload.parse(data + (key to "untrusted"), now))
        for (patch in listOf(mapOf("type" to "ADMIN_UNKNOWN"), mapOf("type" to "SOCIAL_NEW_FOLLOWER"),
            mapOf("presentationVersion" to "ANDROID_CUSTOM_V2"), mapOf("presentationVersion" to "ANDROID_OVERTHINKING_V1"),
            mapOf("notificationId" to "bad"), mapOf("recipientId" to "1-1-1-1-1")))
            assertNull(patch.toString(), VenuePushPayload.parse(data + patch, now))
    }

    @Test fun customCopyHasUtf16BoundsAndRejectsControlBidiMalformedAndBlankText() {
        val data = wire()
        for ((field, limit) in listOf("title" to 120, "body" to 500)) {
            assertNotNull(VenuePushPayload.parse(data + (field to "a".repeat(limit)), now))
            assertNotNull(VenuePushPayload.parse(data + (field to "🎵".repeat(limit / 2)), now))
            for (value in listOf("", " ", " leading", "trailing ", "a".repeat(limit + 1),
                "🎵".repeat(limit / 2) + "a", "a\nline", "a\ttext", "a\u0000text", "a\u007Ftext",
                "a\u0085text", "a\u202Etext", "a\u2066text", "a\u200Btext", "a\u2028text", "a\u2029text", "a\uD800")) {
                assertNull("$field invalid UTF16 length ${value.length}", VenuePushPayload.parse(data + (field to value), now))
            }
        }
    }

    @Test fun canonicalTimestampsBoundSkewAndBothRemainingAndOriginalLifetime() {
        val data = wire()
        for (field in listOf("sentAt", "expiresAt")) {
            for (value in listOf("+$now", "0$now", " $now", "0", "-1", "9223372036854775808"))
                assertNull("$field $value", VenuePushPayload.parse(data + (field to value), now))
        }
        assertNotNull(VenuePushPayload.parse(data + ("sentAt" to (now + 5000).toString()), now))
        assertNull(VenuePushPayload.parse(data + ("sentAt" to (now + 5001).toString()), now))
        assertNull(VenuePushPayload.parse(data + ("expiresAt" to now.toString()), now))
        assertNull(VenuePushPayload.parse(data + ("expiresAt" to (now + ttl + 1).toString()), now))
        assertNull(VenuePushPayload.parse(data + mapOf("sentAt" to (now - ttl).toString(), "expiresAt" to (now + 1).toString()), now))
        assertNotNull(VenuePushPayload.parse(data + ("expiresAt" to (now + ttl).toString()), now))
        assertNull(VenuePushPayload.parse(data, -1))
    }

    @Test fun legacyFamiliesCannotAdoptCustomDisplayCopy() {
        val payload = VenuePushPayload("50000000-0000-4000-8000-000000000001",
            "70000000-0000-4000-8000-000000000001", "SOCIAL_NEW_FOLLOWER", "DEFAULT", now, now + 60_000)
        assertTrue(payload.hasValidDisplay())
        assertEquals("Soundconnect", payload.title)
        assertEquals("Yeni bir takipçin var.", payload.body)
        assertFalse(payload.copy(customTitle = "Injected", customBody = "Injected").hasValidDisplay())
    }
}
