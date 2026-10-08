package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test

class ClockSkewBandRegressionTest {
    @Test fun allFiveBandTypesKeepTheirExistingTemporalContract() {
        val now = 1_790_000_000_000L
        val ttl = 2_419_200_000L
        for (type in listOf("BAND_INVITE_RECEIVED", "BAND_INVITE_ACCEPTED", "BAND_INVITE_REJECTED",
                "BAND_MEMBER_REMOVED", "BAND_MEMBER_LEFT")) {
            val data = mapOf("notificationId" to "50000000-0000-4000-8000-000000000001",
                "recipientId" to "70000000-0000-4000-8000-000000000001", "type" to type,
                "presentationVersion" to "ANDROID_BAND_V1", "displayVariant" to "DEFAULT",
                "sentAt" to now.toString(), "expiresAt" to (now + 60000).toString())
            for (skew in listOf(0L, 640L, 5000L, 5001L)) {
                assertEquals("$type/$skew", skew <= 5000,
                    VenuePushPayload.parse(data + ("sentAt" to (now + skew).toString()), now) != null)
            }
            assertNull(VenuePushPayload.parse(data + ("expiresAt" to now.toString()), now))
            assertNull(VenuePushPayload.parse(data + ("expiresAt" to (now + ttl + 1).toString()), now))
            assertNotNull(VenuePushPayload.parse(data + ("sentAt" to "+$now"), now))
            // Native BAND already applies the remaining-life limit; preserve it.
            assertNull(VenuePushPayload.parse(data + mapOf("sentAt" to (now + 640).toString(),
                "expiresAt" to (now + 640 + ttl).toString()), now))
        }
    }
}
