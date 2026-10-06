package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test

class PushOpenTargetTest {
    private val recipient = "10000000-0000-0000-0000-000000000001"
    private val conversation = "20000000-0000-0000-0000-000000000001"
    private val notice = "30000000-0000-0000-0000-000000000001"
    private fun extras(): Map<String, String?> = mapOf("recipientId" to recipient,
        "conversationId" to conversation, "type" to "DM_NEW_MESSAGE")

    @Test fun allSupportedNotificationFixturesPreserveExactMetadata() {
        assertEquals(45, NativePushOpenCases.types.toSet().size)
        for (type in NativePushOpenCases.types) {
            val fields = mapOf("recipientId" to recipient, "notificationId" to notice, "type" to type) +
                if (type == "DM_NEW_MESSAGE") mapOf("conversationId" to conversation) else emptyMap()
            assertEquals(type, fields, PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, fields))
            if (type != "DM_NEW_MESSAGE") {
                assertTrue(type, VenuePushPayload.supportsType(type))
                assertNull(PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION, fields))
                assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, fields + ("conversationId" to conversation)))
            }
        }
    }

    @Test fun repeatedShortcutTapsHaveDistinctNavigationIdsWithoutNotificationIdentity() {
        val first = PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION, extras())!!
        val second = PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION, extras())!!
        assertNotEquals(first["notificationId"], second["notificationId"])
        assertNotNull(PushNotificationPayload.uuid(first["notificationId"]))
        assertNotNull(PushNotificationPayload.uuid(second["notificationId"]))
        assertEquals(recipient, first["recipientId"])
        assertEquals(conversation, first["conversationId"])
        assertEquals(first - "notificationId", second - "notificationId")
    }

    @Test fun realNotificationRedeliveryPreservesStableDeduplicationId() {
        val input = extras() + ("notificationId" to notice)
        val first = PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, input)
        val second = PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, input)
        assertEquals(notice, first!!["notificationId"])
        assertEquals(first, second)
        assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION, extras()))
        assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION,
            extras() + ("notificationId" to "malformed")))
    }

    @Test fun shortcutCannotReuseStaleNotificationIdOrExposeCachedSenderMetadata() {
        val parsed = PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION,
            extras() + mapOf("notificationId" to notice, "senderName" to "Cached identity",
                "senderAvatarUrl" to "https://example.invalid/avatar"))!!
        assertNotEquals(notice, parsed["notificationId"])
        assertEquals(setOf("notificationId", "recipientId", "conversationId", "type"), parsed.keys)
    }

    @Test fun bothActionsRejectInvalidRecipientsConversationsAndUnsupportedTypes() {
        for (action in listOf(PushOpenTarget.CONVERSATION_ACTION, PushOpenTarget.NOTIFICATION_ACTION)) {
            val valid = extras() + ("notificationId" to notice)
            for (field in listOf("recipientId", "conversationId")) {
                assertNull(PushOpenTarget.parse(action, valid - field))
                assertNull(PushOpenTarget.parse(action, valid + (field to "malformed")))
            }
            assertNull(PushOpenTarget.parse(action, valid + ("type" to "OTHER")))
            assertNull(PushOpenTarget.parse(action, valid - "type"))
        }
        assertNull(PushOpenTarget.parse(null, extras()))
        assertNull(PushOpenTarget.parse("android.intent.action.VIEW", extras()))
    }
}
