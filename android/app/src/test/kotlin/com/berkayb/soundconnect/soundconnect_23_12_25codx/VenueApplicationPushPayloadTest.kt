package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test

class VenueApplicationPushPayloadTest {
    private val now = 1_790_000_000_000L
    private val recipient = "10000000-0000-0000-0000-000000000001"
    private val notification = "20000000-0000-0000-0000-000000000001"
    private val decisions = mapOf(
        "VENUE_APPLICATION_APPROVED" to "Mekân başvurun onaylandı.",
        "VENUE_APPLICATION_REJECTED" to "Mekân başvurun reddedildi."
    )
    private fun data(type: String) = mapOf(
        "presentationVersion" to "ANDROID_VENUE_APPLICATION_V1",
        "notificationId" to notification, "recipientId" to recipient, "type" to type,
        "displayVariant" to "DEFAULT", "sentAt" to now.toString(),
        "expiresAt" to (now + 60_000).toString()
    )

    @Test fun decisionsHaveFixedCopyAndAnOpaqueTapTarget() {
        for ((type, body) in decisions) {
            val payload = VenuePushPayload.parse(data(type), now)!!
            assertEquals(body, payload.body)
            assertEquals(mapOf("notificationId" to notification, "recipientId" to recipient,
                "type" to type), payload.target())
            assertEquals(payload.target(), PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, payload.target()))
            assertNull(PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION, payload.target()))
            assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION,
                payload.target() + ("conversationId" to recipient)))
        }
    }

    @Test fun presentationVersionsCannotBeCrossedOrDowngraded() {
        for (type in decisions.keys) {
            for (version in listOf("ANDROID_VENUE_V1", "ANDROID_DM_V1", "ANDROID_VENUE_APPLICATION_V2", "")) {
                assertNull(VenuePushPayload.parse(data(type) + ("presentationVersion" to version), now))
            }
        }
        for (type in listOf("EVENT_PERFORMER_APPROVED", "ARTIST_VENUE_LINK_APPLICATION_ACCEPT", "OTHER")) {
            assertNull(VenuePushPayload.parse(data(type), now))
        }
    }

    @Test fun decisionsRejectReasonsIdentitiesNavigationAndNondefaultVariants() {
        for (type in decisions.keys) {
            val valid = data(type)
            for (key in valid.keys) assertNull(VenuePushPayload.parse(valid - key, now))
            for (key in listOf("applicationId", "venueId", "venueName", "reason", "body", "deeplink", "email", "role")) {
                assertNull("Private/arbitrary $key", VenuePushPayload.parse(valid + (key to "untrusted"), now))
            }
            for (variant in listOf("PROFILE_VISIBILITY", "PLAN_CONSENT", "PLAN_WITHDRAWN", "", "default")) {
                assertNull(VenuePushPayload.parse(valid + ("displayVariant" to variant), now))
            }
            assertNull(VenuePushPayload.parse(valid + ("recipientId" to "malformed"), now))
            assertNull(VenuePushPayload.parse(valid + ("notificationId" to "malformed"), now))
            assertNull(VenuePushPayload.parse(valid + ("expiresAt" to now.toString()), now))
            assertNull(VenuePushPayload.parse(valid + ("sentAt" to "-1"), now))
        }
    }
}
