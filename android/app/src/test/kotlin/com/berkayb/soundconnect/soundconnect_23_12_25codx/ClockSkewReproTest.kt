package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class ClockSkewReproTest(private val type: String, private val version: String) {
    companion object {
        @JvmStatic @Parameterized.Parameters(name = "{0} +640ms")
        fun cases(): List<Array<String>> = listOf(
            arrayOf("SOCIAL_NEW_FOLLOWER", "ANDROID_FOLLOW_V1"),
            arrayOf("SOCIAL_NEW_BAND_FOLLOWER", "ANDROID_FOLLOW_V1"),
            arrayOf("SOCIAL_LIKE", "ANDROID_MEDIA_V1"),
            arrayOf("SOCIAL_COMMENT", "ANDROID_MEDIA_V1")
        )
    }
    @Test fun fastDeliveryAcceptsSmallFutureSkewWithoutExtendingExpiry() {
        val now = 1_790_000_000_000L
        val result = VenuePushPayload.parse(mapOf(
            "notificationId" to "50000000-0000-4000-8000-000000000001",
            "recipientId" to "70000000-0000-4000-8000-000000000001",
            "type" to type, "presentationVersion" to version,
            "displayVariant" to "DEFAULT", "sentAt" to (now + 640).toString(),
            "expiresAt" to (now + 86_400_000).toString()
        ), now)
        assertNotNull(result)
        assertEquals(now, result!!.sentAt)
        assertEquals(now + 86_400_000, result.expiresAt)
    }
}
