package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test

class StudioPushPayloadTest {
    private val now = 1_790_000_000_000L
    private val recipient = "10000000-0000-0000-0000-000000000001"
    private val notification = "20000000-0000-0000-0000-000000000001"
    private val cases = listOf(
        Case("STUDIO_RESERVATION_CREATED", "STUDIO_CREATED_PENDING", "Yeni bir stüdyo rezervasyon talebin var."),
        Case("STUDIO_RESERVATION_CREATED", "STUDIO_CREATED_CONFIRMED", "Stüdyona yeni bir rezervasyon yapıldı."),
        Case("STUDIO_RESERVATION_CONFLICTING_REQUESTS", "STUDIO_CONFLICTING_REQUESTS", "Çakışan stüdyo rezervasyon taleplerin var."),
        Case("STUDIO_RESERVATION_APPROVED", "STUDIO_APPROVED", "Stüdyo rezervasyon talebin onaylandı."),
        Case("STUDIO_RESERVATION_REJECTED", "STUDIO_REJECTED", "Stüdyo rezervasyon talebin reddedildi."),
        Case("STUDIO_RESERVATION_REJECTED", "STUDIO_REJECTED_CONFLICT", "Çakışan bir talep onaylandığı için rezervasyon talebin reddedildi."),
        Case("STUDIO_RESERVATION_CANCELLED_BY_CUSTOMER", "STUDIO_CANCELLED_BY_CUSTOMER", "Bir müşteri stüdyo rezervasyonunu iptal etti."),
        Case("STUDIO_RESERVATION_CANCELLED_BY_STUDIO", "STUDIO_CANCELLED_BY_STUDIO", "Stüdyo rezervasyonun iptal edildi."),
        Case("STUDIO_RESERVATION_CANCELLED_BY_STUDIO", "STUDIO_ROOM_ARCHIVED", "Oda arşivlendiği için stüdyo rezervasyonun iptal edildi.")
    )
    private fun data(value: Case = cases.first()) = mapOf(
        "presentationVersion" to "ANDROID_STUDIO_V1", "notificationId" to notification,
        "recipientId" to recipient, "type" to value.type, "displayVariant" to value.variant,
        "sentAt" to now.toString(), "expiresAt" to (now + 60_000).toString())

    @Test fun exactSixTypeNineVariantMatrixHasOnlyNineValidCombinations() {
        var accepted = 0
        val expected = cases.map { it.type to it.variant }.toSet()
        val variants = cases.map { it.variant } + listOf("DEFAULT", "PROFILE_VISIBILITY", "CREATED", "", "studio_created_pending")
        assertEquals(6, cases.map { it.type }.toSet().size)
        for (type in cases.map { it.type }.toSet()) {
            assertTrue(VenuePushPayload.supportsType(type))
            for (variant in variants) {
                val parsed = VenuePushPayload.parse(data() + mapOf("type" to type, "displayVariant" to variant), now)
                assertEquals("$type/$variant", (type to variant) in expected, parsed != null)
                if (parsed != null) {
                    accepted++
                    assertEquals(cases.single { it.type == type && it.variant == variant }.body, parsed.body)
                }
            }
        }
        assertEquals(9, accepted)
        for (type in listOf("STUDIO_APPLICATION_APPROVED", "STUDIO_RESERVATION_EXPIRED", "STUDIO", "", "OTHER")) {
            assertFalse(VenuePushPayload.supportsType(type))
            assertNull(VenuePushPayload.parse(data() + ("type" to type), now))
        }
    }

    @Test fun studioCannotDowngradeOrBorrowOtherFamilyVersions() {
        for (value in cases) {
            for (version in listOf("ANDROID_DM_V1", "ANDROID_VENUE_V1", "ANDROID_VENUE_APPLICATION_V1",
                "ANDROID_NATIVE_V4", "ANDROID_STUDIO_V2", "", "android_studio_v1")) {
                assertNull(VenuePushPayload.parse(data(value) + ("presentationVersion" to version), now))
            }
            assertNull(PushNotificationPayload.parse(data(value), now, "images.example.invalid"))
        }
        for (type in listOf("DM_NEW_MESSAGE", "ARTIST_VENUE_LINK_APPLICATION_REQUEST",
            "EVENT_PERFORMER_APPROVED", "VENUE_APPLICATION_APPROVED", "VENUE_APPLICATION_REJECTED")) {
            assertNull(VenuePushPayload.parse(data() + mapOf("type" to type, "displayVariant" to "DEFAULT"), now))
        }
    }

    @Test fun everyVariantRequiresExactlySevenFieldsWithoutPrivateIdentityOrNavigationData() {
        for (value in cases) {
            val valid = data(value)
            assertEquals(7, valid.size)
            for (key in valid.keys) assertNull("Missing $key", VenuePushPayload.parse(valid - key, now))
            for (key in listOf("category", "module", "action", "reservationId", "roomId", "roomName",
                "studioProfileId", "studioName", "requesterId", "localDate", "zoneId", "contactPhone",
                "totalPrice", "senderName", "senderAvatarUrl", "body", "title", "conversationId", "deeplink")) {
                assertNull("Extra $key", VenuePushPayload.parse(valid + (key to "untrusted"), now))
            }
        }
    }

    @Test fun identifiersAreCanonicalButMalformedAndPaddedIdsFailClosed() {
        for (field in listOf("notificationId", "recipientId")) {
            for (invalid in listOf("", "1-1-1-1-1", "malformed", " $recipient", "$recipient ", "null")) {
                assertNull(VenuePushPayload.parse(data() + (field to invalid), now))
            }
            val uppercase = "ABCDABCD-ABCD-ABCD-ABCD-ABCDABCDABCD"
            val parsed = VenuePushPayload.parse(data() + (field to uppercase), now)!!
            assertEquals(uppercase.lowercase(), parsed.target()[field])
        }
    }

    @Test fun timestampAndExpiryBoundsHoldForEveryStudioVariant() {
        val maximumTtl = 28L * 86400 * 1000
        for (value in cases) {
            val valid = data(value)
            for (expiry in listOf("-1", "bad", now.toString(), (now - 1).toString(),
                (now + maximumTtl + 1).toString(), Long.MAX_VALUE.toString(), Long.MIN_VALUE.toString())) {
                assertNull(VenuePushPayload.parse(valid + ("expiresAt" to expiry), now))
            }
            assertNotNull(VenuePushPayload.parse(valid + ("expiresAt" to (now + maximumTtl).toString()), now))
            for (sent in listOf("-1", "bad", (now + 60_000).toString(), Long.MAX_VALUE.toString())) {
                assertNull(VenuePushPayload.parse(valid + ("sentAt" to sent), now))
            }
            assertEquals(now, VenuePushPayload.parse(valid + ("sentAt" to (now + 1).toString()), now)!!.sentAt)
            assertNull(VenuePushPayload.parse(valid, -1))
        }
    }

    @Test fun tapTargetIsStableOpaqueAndNeverAConversationShortcut() {
        for (value in cases) {
            val target = VenuePushPayload.parse(data(value), now)!!.target()
            assertEquals(mapOf("notificationId" to notification, "recipientId" to recipient, "type" to value.type), target)
            assertEquals(target, PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, target))
            assertEquals(target, PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION,
                target + mapOf("roomName" to "stale", "reservationId" to "untrusted")))
            assertNull(PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION, target))
            assertNull(PushOpenTarget.parse("android.intent.action.VIEW", target))
            for (conversation in listOf("", recipient)) {
                assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, target + ("conversationId" to conversation)))
            }
            for (field in listOf("notificationId", "recipientId", "type")) {
                assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, target - field))
                assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, target + (field to "malformed")))
            }
        }
    }

    @Test fun existingVenueAndApplicationContractsRemainDistinctAndSupported() {
        val variants = listOf(
            Triple("ANDROID_VENUE_V1", "ARTIST_VENUE_LINK_APPLICATION_ACCEPT", "DEFAULT"),
            Triple("ANDROID_VENUE_V1", "EVENT_PERFORMER_APPROVED", "PROFILE_VISIBILITY"),
            Triple("ANDROID_VENUE_V1", "EVENT_PERFORMER_REJECTED", "PLAN_WITHDRAWN"),
            Triple("ANDROID_VENUE_APPLICATION_V1", "VENUE_APPLICATION_APPROVED", "DEFAULT"),
            Triple("ANDROID_VENUE_APPLICATION_V1", "VENUE_APPLICATION_REJECTED", "DEFAULT"))
        for ((version, type, variant) in variants) {
            val valid = data() + mapOf("presentationVersion" to version, "type" to type, "displayVariant" to variant)
            val parsed = VenuePushPayload.parse(valid, now)!!
            assertEquals(type, parsed.type)
            assertEquals(parsed.target(), PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, parsed.target()))
            assertNull(VenuePushPayload.parse(valid + ("presentationVersion" to "ANDROID_STUDIO_V1"), now))
            for (studio in cases) assertNull(VenuePushPayload.parse(valid + ("displayVariant" to studio.variant), now))
        }
    }

    @Test fun existingDmStillUsesConversationIdentityAndCannotEnterBusinessParser() {
        val conversation = "30000000-0000-0000-0000-000000000001"
        val valid = data() - "displayVariant" + mapOf("presentationVersion" to "ANDROID_DM_V1",
            "type" to "DM_NEW_MESSAGE", "conversationId" to conversation, "senderName" to "Sender")
        val dm = PushNotificationPayload.parse(valid, now, "images.example.invalid")!!
        assertEquals(conversation, dm.conversationId)
        assertEquals(dm.target(), PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, dm.target()))
        assertNull(VenuePushPayload.parse(valid, now))
        assertNotNull(PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION, dm.target() - "notificationId"))
    }

    private data class Case(val type: String, val variant: String, val body: String)
}

