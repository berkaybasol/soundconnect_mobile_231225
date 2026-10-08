package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test

class PushShortcutScopeTest {
    private val firstUser = "10000000-0000-0000-0000-000000000001"
    private val secondUser = "10000000-0000-0000-0000-000000000002"
    private val oldEpoch = "20000000-0000-0000-0000-000000000001"
    private val newEpoch = "20000000-0000-0000-0000-000000000002"
    private val conversation = "30000000-0000-0000-0000-000000000001"

    @Test fun reloginNeverReusesAnOldShortcutEvenForTheSameConversation() {
        val old = PushShortcutScope.id(firstUser, oldEpoch, conversation)
        val fresh = PushShortcutScope.id(firstUser, newEpoch, conversation)
        assertNotEquals(old, fresh)
        assertEquals(listOf(old), PushShortcutScope.staleIds(listOf(old, fresh), firstUser, newEpoch))
    }

    @Test fun delayedCleanupPreservesTheAccountCurrentAfterEnumeration() {
        val old = PushShortcutScope.id(firstUser, oldEpoch, conversation)
        val fresh = PushShortcutScope.id(secondUser, newEpoch, conversation)
        val capturedOsIds = listOf(old, fresh)
        assertEquals(listOf(old), PushShortcutScope.staleIds(capturedOsIds, secondUser, newEpoch))
    }

    @Test fun shortcutPublishedAfterEnumerationCannotBeDeletedByTheOldSnapshot() {
        val old = PushShortcutScope.id(firstUser, oldEpoch, conversation)
        val capturedOsIds = listOf(old)
        val fresh = PushShortcutScope.id(secondUser, newEpoch, conversation)
        assertFalse(PushShortcutScope.staleIds(capturedOsIds, secondUser, newEpoch).contains(fresh))
    }

    @Test fun logoutRemovesOwnedLegacyAndNewShortcutsButPreservesOtherFeatures() {
        val legacy = "soundconnect-dm-$firstUser-$conversation"
        val current = PushShortcutScope.id(firstUser, oldEpoch, conversation)
        assertEquals(listOf(legacy, current),
            PushShortcutScope.staleIds(listOf(legacy, current, "audio-library"), null, null))
    }

    @Test fun anotherRecipientCannotBeProtectedByReusingTheCurrentEpoch() {
        val ours = PushShortcutScope.id(firstUser, newEpoch, conversation)
        val foreign = PushShortcutScope.id(secondUser, newEpoch, conversation)
        assertEquals(listOf(foreign), PushShortcutScope.staleIds(listOf(ours, foreign), firstUser, newEpoch))
    }
}
