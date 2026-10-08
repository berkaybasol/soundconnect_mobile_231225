package com.berkayb.soundconnect.soundconnect_23_12_25codx
import org.junit.Assert.*
import org.junit.Test

class TablePushPayloadTest {
    private val now = 1_790_000_000_000L
    private val id = "10000000-0000-0000-0000-000000000001"
    private val types = VenuePushPayload.tableTypes.toList()
    private fun wire(type: String = types.first()) = mapOf("presentationVersion" to "ANDROID_TABLE_V1",
        "notificationId" to id, "recipientId" to id, "type" to type, "displayVariant" to if(type == "TABLE_CANCELLED") "OWNER_CANCELLED" else "DEFAULT",
        "sentAt" to now.toString(), "expiresAt" to (now + 60_000).toString())
    @Test fun sevenTypesHaveFixedPrivateCopyAndIdentityFreeTarget() {
        for (type in types) {
            val value = VenuePushPayload.parse(wire(type), now)!!
            assertTrue(value.body.isNotBlank())
            assertFalse(value.body.contains(id))
            assertEquals(setOf("notificationId","recipientId","type"),value.target().keys)
            assertEquals(value.target(),PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION,value.target()))
            assertNull(PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION,value.target()))
            assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION,value.target()+("conversationId" to id)))
        }
    }
    @Test fun everyMissingExtraVersionTypeVariantAndMalformedIdFailsClosed() {
        for(type in types) {
            val data = wire(type)
            for(key in data.keys) assertNull(key,VenuePushPayload.parse(data-key,now))
            for(key in listOf("actorId","mediaId","commentId","sourceUrl","followerId","bandId","profileId","username","body","avatarUrl","route","deeplink","conversationId"))
                assertNull(key,VenuePushPayload.parse(data+(key to id),now))
            for((key,value) in listOf("presentationVersion" to "ANDROID_STUDIO_V1", "presentationVersion" to "ANDROID_TABLE_V2",
                "type" to "SOCIAL_NEW_LIKE", "type" to "SOCIAL_NEW_COMMENT", "displayVariant" to "STUDIO_APPROVED",
                "recipientId" to "1-1-1-1-1", "notificationId" to " $id"))
                assertNull("$key/$value",VenuePushPayload.parse(data+(key to value),now))
        }
    }
    @Test fun timeBoundsRejectFutureSentExpiredOverflowAndExcessTtl() {
        for(sent in listOf("0","-1","bad","+${now}","0${now}"," ${now}",(now+5001).toString(),Long.MAX_VALUE.toString()))
            assertNull(VenuePushPayload.parse(wire()+("sentAt" to sent),now))
        for(expiry in listOf(now.toString(),"bad",Long.MAX_VALUE.toString(),(now+28L*86400000+1).toString()))
            assertNull(VenuePushPayload.parse(wire()+("expiresAt" to expiry),now))
        assertNull(VenuePushPayload.parse(wire()+("sentAt" to (now-28L*86400000).toString()),now))
        assertNotNull(VenuePushPayload.parse(wire()+("expiresAt" to (now+28L*86400000).toString()),now))
    }
    @Test fun twoCancellationReasonsCannotBeConfused() {
        val manual = VenuePushPayload.parse(wire("TABLE_CANCELLED"), now)!!
        val joined = VenuePushPayload.parse(wire("TABLE_CANCELLED")+("displayVariant" to "OWNER_JOINED_ANOTHER_TABLE"), now)!!
        assertNotEquals(manual.body, joined.body)
        assertTrue(joined.body.contains("başka bir masaya"))
        assertNull(VenuePushPayload.parse(wire("TABLE_CANCELLED")+("displayVariant" to "DEFAULT"), now))
        assertNull(VenuePushPayload.parse(wire("TABLE_EXPIRED")+("displayVariant" to "OWNER_CANCELLED"), now))
    }
    @Test fun smallDeviceClockSkewAllowsRealDeliveryWithoutExtendingExpiry() {
        for(type in types) for(skew in listOf(1L,640L,5000L)) {
            val value = VenuePushPayload.parse(wire(type)+("sentAt" to (now+skew).toString()),now)!!
            assertEquals(now,value.sentAt)
            assertEquals(now+60000,value.expiresAt)
            assertNull(VenuePushPayload.parse(wire(type)+("sentAt" to (now+skew).toString())+("expiresAt" to now.toString()),now))
        }
    }
}
