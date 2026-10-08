package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test
import java.util.UUID

class PushDeliveredPolicyTest {
    private val recipient = "aaaaaaaa-0000-4000-8000-000000000001"
    private val epoch = "bbbbbbbb-0000-4000-8000-000000000001"
    private val scope = PushDeliveredPolicy.Scope(recipient, epoch)
    private val first = "cccccccc-0000-4000-8000-000000000001"
    private val second = "cccccccc-0000-4000-8000-000000000002"
    private fun entry(id: String = first) = PushDeliveredPolicy.Entry(id, 0, true, recipient, epoch, id)
    private fun args(ids: Any? = listOf(first)): Map<String, Any?> = mapOf("recipientId" to recipient,
        "bindingEpoch" to epoch, "notificationIds" to ids)

    @Test fun snapshotReturnsOnlyIdentifiersOwnedByCurrentChannelAndEpoch() {
        val good = entry()
        val mixed = listOf(good, good, entry(second), good.copy(channelMatches = false),
            good.copy(androidId = 1), good.copy(tag = second), good.copy(recipientId = UUID.randomUUID().toString()),
            good.copy(bindingEpoch = UUID.randomUUID().toString()), good.copy(notificationId = null),
            good.copy(notificationId = "bad"), good.copy(notificationId = first.uppercase(), tag = first.uppercase()))
        val snapshot = PushDeliveredPolicy.snapshot(scope, recipient, mixed)!!
        assertEquals(listOf(first, second), snapshot.notificationIds)
        assertEquals(setOf("recipientId", "bindingEpoch", "notificationIds"), snapshot.toMap().keys)
    }

    @Test fun noBindingOrDifferentAccountReturnsNullButEmptyOwnedSetIsAValidSnapshot() {
        assertNull(PushDeliveredPolicy.snapshot(null, recipient, listOf(entry())))
        assertNull(PushDeliveredPolicy.snapshot(scope, UUID.randomUUID().toString(), listOf(entry())))
        assertNull(PushDeliveredPolicy.snapshot(scope.copy(bindingEpoch = "bad"), recipient, listOf(entry())))
        assertEquals(emptyList<String>(), PushDeliveredPolicy.snapshot(scope, recipient, emptyList())!!.notificationIds)
    }

    @Test fun snapshotCapIsDeterministicAndDoesNotLeakOtherEntries() {
        val many = (1..130).map { entry("cccccccc-0000-4000-8000-${it.toString().padStart(12, '0')}") }
        val ids = PushDeliveredPolicy.snapshot(scope, recipient, many.reversed())!!.notificationIds
        assertEquals(100, ids.size)
        assertEquals(many.take(100).map { it.notificationId }, ids)
    }

    @Test fun malformedAndUnboundedChannelArgumentsAreRejectedAsAWhole() {
        for (bad in listOf(null, "bad", 7, listOf(first, 7), listOf(first, "bad"), List(101) { first })) {
            assertNull(PushDeliveredPolicy.dismissRequest(args(bad)))
        }
        assertNull(PushDeliveredPolicy.dismissRequest(args() + ("recipientId" to recipient.uppercase())))
        assertNull(PushDeliveredPolicy.dismissRequest(args() + ("bindingEpoch" to null)))
        assertNull(PushDeliveredPolicy.snapshotRecipient(recipient))
        assertNull(PushDeliveredPolicy.snapshotRecipient(mapOf("recipientId" to 1)))
        assertEquals(recipient, PushDeliveredPolicy.snapshotRecipient(mapOf("recipientId" to recipient)))
        assertTrue(PushDeliveredPolicy.dismissRequest(args(emptyList<String>()))!!.notificationIds.isEmpty())
        assertEquals(setOf(first), PushDeliveredPolicy.dismissRequest(args(listOf(first, first)))!!.notificationIds)
    }

    @Test fun partialDismissPreservesUnreadOtherChannelsAndUnknownIds() {
        val active = listOf(entry(), entry(second), entry().copy(channelMatches = false),
            entry().copy(bindingEpoch = UUID.randomUUID().toString()))
        val request = PushDeliveredPolicy.dismissRequest(args(listOf(first, UUID.randomUUID().toString())))!!
        assertEquals(listOf(entry()), PushDeliveredPolicy.dismissTargets(scope, request, active))
        assertEquals(active, listOf(entry(), entry(second), active[2], active[3]))
    }

    @Test fun oldSnapshotCannotDismissAfterLogoutOrSameAccountRelogin() {
        val request = PushDeliveredPolicy.dismissRequest(args())!!
        val newEpoch = UUID.randomUUID().toString()
        assertTrue(PushDeliveredPolicy.dismissTargets(null, request, listOf(entry())).isEmpty())
        assertTrue(PushDeliveredPolicy.dismissTargets(scope.copy(bindingEpoch = newEpoch), request,
            listOf(entry().copy(bindingEpoch = newEpoch))).isEmpty())
        assertTrue(PushDeliveredPolicy.dismissTargets(scope.copy(recipientId = UUID.randomUUID().toString()),
            request, listOf(entry())).isEmpty())
        assertTrue(PushDeliveredPolicy.dismissTargets(scope, request, emptyList()).isEmpty())
    }
}
