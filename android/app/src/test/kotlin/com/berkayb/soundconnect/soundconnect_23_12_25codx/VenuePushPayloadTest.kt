package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test

class VenuePushPayloadTest {
    private val now = 1_790_000_000_000L
    private val recipient = "10000000-0000-0000-0000-000000000001"
    private val notification = "20000000-0000-0000-0000-000000000001"
    private val connections = listOf("ARTIST_VENUE_LINK_APPLICATION_REQUEST",
        "ARTIST_VENUE_LINK_APPLICATION_ACCEPT", "ARTIST_VENUE_LINK_APPLICATION_REJECT")
    private val events = listOf("EVENT_PERFORMER_APPROVAL_REQUESTED",
        "EVENT_PERFORMER_APPROVED", "EVENT_PERFORMER_REJECTED")
    private fun data(type: String = events.last(), variant: String = "PLAN_WITHDRAWN") = mapOf(
        "presentationVersion" to "ANDROID_VENUE_V1", "notificationId" to notification,
        "recipientId" to recipient, "type" to type, "displayVariant" to variant,
        "sentAt" to now.toString(), "expiresAt" to (now + 60_000).toString())

    @Test fun exactTypeVariantMatrixHasThirteenAcceptedCombinations() {
        var accepted = 0
        for (type in connections + events) {
            for (variant in listOf("DEFAULT", "PROFILE_VISIBILITY", "PLAN_CONSENT", "PLAN_WITHDRAWN")) {
                val expected = variant == "DEFAULT" || (type in events && variant != "PLAN_WITHDRAWN") ||
                    (type == "EVENT_PERFORMER_REJECTED" && variant == "PLAN_WITHDRAWN")
                val parsed = VenuePushPayload.parse(data(type, variant), now)
                assertEquals("$type/$variant", expected, parsed != null)
                if (parsed != null) { accepted++; assertTrue(parsed.body.isNotBlank()) }
            }
        }
        assertEquals(13, accepted)
        for (unsupported in listOf("DM_NEW_MESSAGE", "EVENT_VENUE_APPROVED", "VENUE_APPLICATION_REJECTED", "OTHER")) {
            assertNull(VenuePushPayload.parse(data(unsupported, "DEFAULT"), now))
        }
        assertNull(VenuePushPayload.parse(data(variant = "UNKNOWN"), now))
    }

    @Test fun missingExtraBusinessOrArbitraryDisplayFieldsFailClosed() {
        val valid = data()
        for (key in valid.keys) assertNull("Missing $key", VenuePushPayload.parse(valid - key, now))
        for (key in listOf("conversationId", "venueId", "requestId", "planId", "body", "senderName", "deeplink")) {
            assertNull("Untrusted $key", VenuePushPayload.parse(valid + (key to recipient), now))
        }
        assertNull(VenuePushPayload.parse(valid + ("presentationVersion" to "ANDROID_DM_V1"), now))
    }

    @Test fun identifiersAreCanonicalizedAndMalformedIdsReject() {
        for (key in listOf("notificationId", "recipientId")) {
            assertNull(VenuePushPayload.parse(data() + (key to "1-1-1-1-1"), now))
            assertNull(VenuePushPayload.parse(data() + (key to " $recipient"), now))
        }
        val uppercase = "ABCDABCD-ABCD-ABCD-ABCD-ABCDABCDABCD"
        assertEquals(uppercase.lowercase(), VenuePushPayload.parse(data() + ("recipientId" to uppercase), now)!!.recipientId)
    }

    @Test fun expiryAndSentTimeAreBoundedWithoutOverflowOrImplicitFallback() {
        for (expiry in listOf(now, now - 1, now + 28L * 86400 * 1000 + 1, Long.MAX_VALUE)) {
            assertNull(VenuePushPayload.parse(data() + ("expiresAt" to expiry.toString()), now))
        }
        assertNotNull(VenuePushPayload.parse(data() + ("expiresAt" to (now + 28L * 86400 * 1000).toString()), now))
        for (sent in listOf("-1", "not-time", Long.MAX_VALUE.toString(), (now + 60_000).toString())) {
            assertNull(VenuePushPayload.parse(data() + ("sentAt" to sent), now))
        }
        assertEquals(now, VenuePushPayload.parse(data() + ("sentAt" to (now + 1).toString()), now)!!.sentAt)
        assertNull(VenuePushPayload.parse(data(), -1))
    }

    @Test fun withdrawalCopyDiffersFromRejectionAndTargetContainsOnlyThreeIds() {
        val withdrawal = VenuePushPayload.parse(data(), now)!!
        val rejection = VenuePushPayload.parse(data(variant = "PLAN_CONSENT"), now)!!
        assertTrue(withdrawal.body.contains("geri çekildi"))
        assertFalse(withdrawal.body.contains("reddedildi"))
        assertTrue(rejection.body.contains("reddedildi"))
        assertEquals(mapOf("notificationId" to notification, "recipientId" to recipient,
            "type" to "EVENT_PERFORMER_REJECTED"), withdrawal.target())
    }

    @Test fun venueNotificationTapRejectsConversationOrShortcutAndPreservesStableId() {
        for (type in connections + events) {
            val extras = mapOf("notificationId" to notification, "recipientId" to recipient, "type" to type)
            assertEquals(extras, PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, extras))
            assertNull(PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION, extras))
            assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, extras + ("conversationId" to recipient)))
            assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, extras + ("conversationId" to "")))
            assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, extras - "notificationId"))
            assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, extras + ("recipientId" to "malformed")))
        }
    }
}
