package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test

class PushNotificationLedgerPolicyTest {
    private class Entries(private val saved: MutableMap<Pair<String, String>, Long>) : PushLedgerEntries {
        override fun removeExpired(now: Long) { saved.entries.removeAll { it.value <= now } }
        override fun contains(recipient: String, notification: String) = saved.containsKey(recipient to notification)
        override fun count() = saved.size.toLong()
        override fun insert(recipient: String, notification: String, expiresAt: Long) { saved[recipient to notification] = expiresAt }
    }

    @Test fun restartAndAccountChangesDoNotErasePreviousDeliveryKeys() {
        val saved = mutableMapOf<Pair<String, String>, Long>()
        assertTrue(PushNotificationLedgerPolicy.reserve(Entries(saved), "account-a", "notice", 500, 100))
        // A fresh storage wrapper models a new process; changing account is not pruning.
        assertTrue(PushNotificationLedgerPolicy.reserve(Entries(saved), "account-b", "notice", 500, 110))
        assertFalse(PushNotificationLedgerPolicy.reserve(Entries(saved), "account-a", "notice", 500, 120))
        assertEquals(2, saved.size)
    }

    @Test fun moreThan128DeliveriesStillSuppressTheFirstDismissedDelivery() {
        val saved = mutableMapOf<Pair<String, String>, Long>()
        val entries = Entries(saved)
        repeat(300) { assertTrue(PushNotificationLedgerPolicy.reserve(entries, "a", "n-$it", 500, 100)) }
        assertFalse(PushNotificationLedgerPolicy.reserve(entries, "a", "n-0", 500, 101))
        assertEquals(300, saved.size)
    }

    @Test fun fullLedgerRejectsNewPostsWithoutEvictingUnexpiredRecords() {
        val saved = mutableMapOf<Pair<String, String>, Long>()
        val entries = Entries(saved)
        repeat(3) { assertTrue(PushNotificationLedgerPolicy.reserve(entries, "a", "n-$it", 500, 100, maximum = 3)) }
        assertFalse(PushNotificationLedgerPolicy.reserve(entries, "b", "new", 500, 101, maximum = 3))
        assertEquals(setOf("n-0", "n-1", "n-2"), saved.keys.map { it.second }.toSet())
        assertFalse(PushNotificationLedgerPolicy.reserve(entries, "a", "n-0", 500, 101, maximum = 3))
    }

    @Test fun onlyExpiredRecordsFreeCapacityAtTheExpiryBoundary() {
        val saved = mutableMapOf(("a" to "old") to 200L, ("a" to "live") to 500L)
        val entries = Entries(saved)
        assertFalse(PushNotificationLedgerPolicy.reserve(entries, "a", "new", 500, 199, maximum = 2))
        assertTrue(PushNotificationLedgerPolicy.reserve(entries, "a", "new", 500, 200, maximum = 2))
        assertFalse(saved.containsKey("a" to "old"))
        assertTrue(saved.containsKey("a" to "live"))
    }

    @Test fun expiredAndUnboundedReservationsNeverOccupyStorage() {
        val saved = mutableMapOf<Pair<String, String>, Long>()
        val entries = Entries(saved)
        for (expiry in listOf(99L, 100L, Long.MAX_VALUE)) {
            assertFalse(PushNotificationLedgerPolicy.reserve(entries, "a", "n", expiry, 100))
        }
        assertTrue(saved.isEmpty())
        assertTrue(PushNotificationLedgerPolicy.reserve(entries, "a", "n",
            100 + PushNotificationLedgerPolicy.MAX_TTL_MILLIS, 100))
    }
}
