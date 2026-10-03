package com.berkayb.soundconnect.soundconnect_23_12_25codx
import org.junit.Assert.*
import org.junit.Test

class MediaPushPayloadTest {
    private val now = 1_790_000_000_000L
    private val id = "10000000-0000-0000-0000-000000000001"
    private val types = listOf("SOCIAL_LIKE", "SOCIAL_COMMENT")
    private fun wire(type: String = types.first()) = mapOf("presentationVersion" to "ANDROID_MEDIA_V1",
        "notificationId" to id, "recipientId" to id, "type" to type, "displayVariant" to "DEFAULT",
        "sentAt" to now.toString(), "expiresAt" to (now + 60_000).toString())
    @Test fun bothTypesHaveFixedPrivateCopyAndIdentityFreeTarget() {
        for ((index,type) in types.withIndex()) {
            val value = VenuePushPayload.parse(wire(type), now)!!
            assertEquals(listOf("İçeriğin yeni bir beğeni aldı.", "İçeriğine yeni bir yorum yapıldı.")[index],value.body)
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
            for((key,value) in listOf("presentationVersion" to "ANDROID_STUDIO_V1", "presentationVersion" to "ANDROID_MEDIA_V2",
                "type" to "SOCIAL_NEW_LIKE", "type" to "SOCIAL_NEW_COMMENT", "displayVariant" to "STUDIO_APPROVED",
                "recipientId" to "1-1-1-1-1", "notificationId" to " $id"))
                assertNull("$key/$value",VenuePushPayload.parse(data+(key to value),now))
        }
    }
    @Test fun timeBoundsRejectFutureSentExpiredOverflowAndExcessTtl() {
        for(sent in listOf("0","-1","bad",(now+5001).toString(),Long.MAX_VALUE.toString()))
            assertNull(VenuePushPayload.parse(wire()+("sentAt" to sent),now))
        for(expiry in listOf(now.toString(),"bad",Long.MAX_VALUE.toString(),(now+28L*86400000+1).toString()))
            assertNull(VenuePushPayload.parse(wire()+("expiresAt" to expiry),now))
        assertNull(VenuePushPayload.parse(wire()+("sentAt" to (now-28L*86400000).toString()),now))
        assertNotNull(VenuePushPayload.parse(wire()+("expiresAt" to (now+28L*86400000).toString()),now))
    }
}
