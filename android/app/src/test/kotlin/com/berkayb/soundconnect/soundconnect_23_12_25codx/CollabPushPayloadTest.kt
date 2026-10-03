package com.berkayb.soundconnect.soundconnect_23_12_25codx
import org.junit.Assert.*
import org.junit.Test

class CollabPushPayloadTest {
    private val now=1_790_000_000_000L
    private val id="10000000-0000-4000-8000-000000000001"
    private fun wire(type:String="COLLAB_APPLICATION_RECEIVED")=mapOf("presentationVersion" to "ANDROID_COLLAB_V1",
        "notificationId" to id,"recipientId" to id,"type" to type,
        "displayVariant" to if(type=="COLLAB_REPORT_RESOLVED") "REMOVE_LISTING" else "DEFAULT",
        "sentAt" to now.toString(),"expiresAt" to (now+60000).toString())
    @Test fun everyTypeHasFixedCopyAndOnlyBoundIdentityTarget() {
        for(type in VenuePushPayload.collabTypes) {
            val p=VenuePushPayload.parse(wire(type),now)!!
            assertTrue(p.body.isNotBlank());assertFalse(p.body.contains(id))
            assertEquals(setOf("notificationId","recipientId","type"),p.target().keys)
            assertEquals(p.target(),PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION,p.target()))
            assertNull(PushOpenTarget.parse(PushOpenTarget.CONVERSATION_ACTION,p.target()))
            assertNull(PushOpenTarget.parse(PushOpenTarget.NOTIFICATION_ACTION,p.target()+("conversationId" to id)))
        }
    }
    @Test fun missingExtraMixedFamilyMalformedAndUnknownNeverRender() {
        for(type in VenuePushPayload.collabTypes) {
            val w=wire(type)
            for(key in w.keys) assertNull(key,VenuePushPayload.parse(w-key,now))
            for(key in listOf("listingId","applicationId","jobId","reviewId","reportId","actorId","phone","note","title","message","avatarUrl","deepLink","conversationId"))
                assertNull(key,VenuePushPayload.parse(w+(key to "private"),now))
            for((key,value) in listOf("presentationVersion" to "ANDROID_TABLE_V1","presentationVersion" to "ANDROID_COLLAB_V2",
                "type" to "COLLAB_UNKNOWN","type" to "TABLE_EXPIRED","displayVariant" to "BAD","recipientId" to "1-1-1-1-1","notificationId" to " $id"))
                assertNull("$key/$value",VenuePushPayload.parse(w+(key to value),now))
        }
    }
    @Test fun decisionsRemainDistinctAndCannotBeUsedForOtherTypes() {
        val removed=VenuePushPayload.parse(wire("COLLAB_REPORT_RESOLVED"),now)!!
        val dismissed=VenuePushPayload.parse(wire("COLLAB_REPORT_RESOLVED")+("displayVariant" to "DISMISS"),now)!!
        assertEquals("Bildirdiğin ilan kaldırıldı.",removed.body);assertEquals("Bildirimin incelendi.",dismissed.body)
        assertNull(VenuePushPayload.parse(wire("COLLAB_REPORT_RESOLVED")+("displayVariant" to "DEFAULT"),now))
        assertNull(VenuePushPayload.parse(wire()+("displayVariant" to "DISMISS"),now))
    }
    @Test fun boundedSkewNeverExtendsExpiry() {
        for(type in VenuePushPayload.collabTypes) for(skew in listOf(1L,640L,5000L)) {
            val p=VenuePushPayload.parse(wire(type)+("sentAt" to (now+skew).toString()),now)!!
            assertEquals(now,p.sentAt);assertEquals(now+60000,p.expiresAt)
            assertNull(VenuePushPayload.parse(wire(type)+("sentAt" to (now+skew).toString())+("expiresAt" to now.toString()),now))
        }
    }
    @Test fun nonCanonicalTimesOverflowAndExcessLifetimeFailClosed() {
        for(sent in listOf("0","-1","bad","+$now","0$now"," $now",(now+5001).toString(),Long.MAX_VALUE.toString()))
            assertNull(VenuePushPayload.parse(wire()+("sentAt" to sent),now))
        for(expiry in listOf(now.toString(),"bad",Long.MAX_VALUE.toString(),(now+28L*86400000+1).toString()))
            assertNull(VenuePushPayload.parse(wire()+("expiresAt" to expiry),now))
        assertNull(VenuePushPayload.parse(wire(),-1))
        assertNull(VenuePushPayload.parse(wire()+("sentAt" to (now-28L*86400000).toString()),now))
    }
}
