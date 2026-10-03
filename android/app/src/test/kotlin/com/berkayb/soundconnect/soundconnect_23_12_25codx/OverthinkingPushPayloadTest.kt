package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test

class OverthinkingPushPayloadTest {
    private val now=1790000000000L
    private fun wire(type:String)=mapOf("type" to type,"presentationVersion" to "ANDROID_OVERTHINKING_V1",
        "notificationId" to "50000000-0000-4000-8000-000000000001",
        "recipientId" to "70000000-0000-4000-8000-000000000001",
        "sentAt" to now.toString(),"expiresAt" to (now+60000).toString())
    @Test fun threeTypesRenderGenericTextAndOnlyExactIdentityTap() {
        for(type in VenuePushPayload.overthinkingTypes) {
            val p=requireNotNull(VenuePushPayload.parse(wire(type),now))
            assertTrue(p.body.isNotBlank())
            assertEquals(setOf("notificationId","recipientId","type"),p.target().keys)
            assertEquals(p.target(),PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION,p.target()))
            assertNull(PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION,p.target()))
            assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION,p.target()+mapOf("recipientId" to "bad")))
        }
    }
    @Test fun missingExtraPrivateMixedAndUnknownValuesFailClosed() {
        for(type in VenuePushPayload.overthinkingTypes) {
            val original=wire(type)
            for(key in original.keys) assertNull(key,VenuePushPayload.parse(original-key,now))
            for(key in listOf("displayVariant","postId","revealRequestId","authorId","requesterId","postTitle","content","avatarUrl","canViewAuthor"))
                assertNull(key,VenuePushPayload.parse(original+mapOf(key to "private"),now))
            for(patch in listOf(mapOf("type" to "OVERTHINKING_UNKNOWN"),mapOf("type" to "COLLAB_APPLICATION_RECEIVED"),
                mapOf("presentationVersion" to "ANDROID_COLLAB_V1"),mapOf("presentationVersion" to "ANDROID_OVERTHINKING_V2"),
                mapOf("notificationId" to "bad"),mapOf("recipientId" to "1-1-1-1-1")))
                assertNull(VenuePushPayload.parse(original+patch,now))
        }
    }
    @Test fun canonicalTimeSkewAndLifetimeNeverExtendExpiry() {
        val original=wire("OVERTHINKING_REVEAL_REQUEST_RECEIVED")
        for(value in listOf("+$now","0$now"," $now","0","-1","9223372036854775808",(now+5001).toString()))
            assertNull(value,VenuePushPayload.parse(original+mapOf("sentAt" to value),now))
        assertNotNull(VenuePushPayload.parse(original+mapOf("sentAt" to (now+5000).toString()),now))
        assertNull(VenuePushPayload.parse(original+mapOf("expiresAt" to now.toString()),now))
        assertNull(VenuePushPayload.parse(original+mapOf("expiresAt" to (now+28L*86400*1000+1).toString()),now))
        assertNull(VenuePushPayload.parse(original,-1))
    }
}
