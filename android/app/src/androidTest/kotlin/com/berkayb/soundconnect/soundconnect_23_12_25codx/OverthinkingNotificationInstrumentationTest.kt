package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.app.Notification
import android.app.NotificationManager
import android.os.Bundle
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

/** Real renderer -> NotificationManager -> rendered PendingIntent -> Activity -> Dart.
 * Uses the same acquired warmtest fixture on hosted emulators and the exact selected Vivo.
 */
@RunWith(AndroidJUnit4::class)
class OverthinkingNotificationInstrumentationTest : NativePushBridgeTestFixture() {
    private val manager get() = context.getSystemService(NotificationManager::class.java)
    private val ids = mutableSetOf<String>()
    private val bindings = mutableSetOf<PushNotificationState.Binding>()
    private fun renderer() = VenueNotificationRenderer(context) { false }
    private fun value(type: String = VenuePushPayload.overthinkingTypes.first()): VenuePushPayload {
        val now = System.currentTimeMillis()
        return requireNotNull(VenuePushPayload.parse(mapOf(
            "presentationVersion" to "ANDROID_OVERTHINKING_V1", "type" to type,
            "notificationId" to UUID.randomUUID().toString(), "recipientId" to recipient,
            "sentAt" to now.toString(), "expiresAt" to (now + 300_000).toString()), now))
    }
    private fun eventually(label: String, condition: () -> Boolean) {
        val until = SystemClock.elapsedRealtime() + 10_000
        while (!condition() && SystemClock.elapsedRealtime() < until) SystemClock.sleep(50)
        assertTrue(label, condition())
    }
    private fun children() = manager.activeNotifications.filter { it.id == 0 && it.tag in ids }
    private fun child(id: String) = children().single { it.tag == id }.notification
    private fun post(payload: VenuePushPayload) {
        assertTrue("Owned warmtest requires notification permission", manager.areNotificationsEnabled())
        ids.add(payload.notificationId); bindings.add(binding)
        SystemClock.sleep(650) // Android package enqueue quota, as in existing family fixtures.
        assertTrue(renderer().post(payload, binding, scheduleWork = false))
        eventually("Real child visible") { children().any { it.tag == payload.notificationId } }
        SystemClock.sleep(650)
        PushNotificationState.reconcileVenueGroup(context, binding, scheduleRepair = false)
    }
    private fun summary(count: Int): Notification {
        eventually("Existing venue summary count $count") {
            manager.activeNotifications.any { it.tag == VenueNotificationGroups.summaryTag(binding) && it.notification.number == count }
        }
        return manager.activeNotifications.single { it.tag == VenueNotificationGroups.summaryTag(binding) }.notification
    }
    private fun dm(): String {
        val id = UUID.randomUUID().toString(); ids.add(id); bindings.add(binding)
        val expiry = System.currentTimeMillis() + 300_000
        val card = NotificationCompat.Builder(context, PushNotificationState.CHANNEL)
            .setSmallIcon(R.drawable.ic_notification).setContentTitle("Owned independent DM fixture")
            .setContentText(PushNotificationPayload.BODY).setSilent(true)
            .setGroup(PushNotificationGroups.groupKey(binding))
            .addExtras(Bundle().apply {
                putString(PushDeliveredPolicy.RECIPIENT_EXTRA, recipient)
                putString(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
                putString(PushDeliveredPolicy.ID_EXTRA, id)
                putLong(PushNotificationGroups.EXPIRY_EXTRA, expiry)
            }).build()
        SystemClock.sleep(650)
        assertTrue(PushNotificationState.postInitial(context, binding, id, expiry) { manager.notify(id, 0, card); true })
        eventually("Independent DM exists") { children().any { it.tag == id } }
        return id
    }
    override fun cleanupOwnedCards() {
        ids.forEach { manager.cancel(it, 0) }
        bindings.forEach {
            manager.cancel(VenueNotificationGroups.summaryTag(it), VenueNotificationGroups.SUMMARY_ID)
            manager.cancel(PushNotificationGroups.summaryTag(it), PushNotificationGroups.SUMMARY_ID)
        }
        eventually("Only acquired cards removed") { children().isEmpty() }
    }

    @Test fun threeRenderedCardsDeliverExactPrivateSafeTargetsThroughActualPendingIntents() {
        launch(); assertNull(dart("initial"))
        val values = VenuePushPayload.overthinkingTypes.map(::value)
        values.forEach(::post); summary(3)
        val dm = dm()
        val intents = values.map { child(it.notificationId).contentIntent }
        assertEquals(3, intents.toSet().size)
        values.forEachIndexed { index, payload ->
            val card = child(payload.notificationId)
            assertEquals(payload.body, card.extras.getCharSequence(Notification.EXTRA_TEXT).toString())
            assertEquals(Notification.VISIBILITY_PRIVATE, card.visibility)
            assertEquals(R.drawable.ic_notification, card.smallIcon.resId)
            assertEquals(ContextCompat.getColor(context, R.color.soundconnect_icon_accent), card.color)
            assertEquals("Yeni bir bildirimin var.", card.publicVersion.extras.getCharSequence(Notification.EXTRA_TEXT).toString())
            assertFalse(card.publicVersion.extras.toString().contains(recipient))
            assertEquals(binding.epoch, card.extras.getString(PushDeliveredPolicy.EPOCH_EXTRA))
            assertEquals(payload.notificationId, card.extras.getString(PushDeliveredPolicy.ID_EXTRA))
            card.contentIntent.send() // Never substitute a hand-built Intent for the rendered card.
            eventually("Rendered card reached Dart") { events().size == index + 1 }
            assertEquals(payload.target(), events()[index])
            assertEquals(setOf("notificationId", "recipientId", "type"), (events()[index] as Map<*, *>).keys)
            eventually("Exact tap preserved independent siblings") {
                children().map { it.tag }.toSet() == values.drop(index + 1).map { it.notificationId }.toSet() + dm
            }
        }
    }

    @Test fun duplicateDismissExpiryAndCapturedGroupDeleteNeverResurrectOrRemoveLaterSibling() {
        val a = value(); val b = value(); post(a); post(b)
        val dm = dm()
        assertFalse(renderer().post(a, binding, scheduleWork = false))
        PushNotificationState.dismissNotification(context, binding, a.notificationId)
        assertFalse(renderer().post(a, binding, scheduleWork = false))
        PushNotificationState.expireNotification(context, binding, b.notificationId, b.expiresAt, b.expiresAt)
        assertFalse(renderer().post(b, binding, scheduleWork = false))
        eventually("Dismiss and expiry preserve DM") { children().map { it.tag }.toSet() == setOf(dm) }
        val captured = value(); post(captured)
        val delete = summary(1).deleteIntent
        val later = value(); post(later)
        delete.send()
        eventually("Rendered group-delete snapshot preserves later arrival") { children().map { it.tag }.toSet() == setOf(dm, later.notificationId) }
        assertFalse(renderer().post(captured, binding, scheduleWork = false))
        summary(1)
    }

    @Test fun rejectedCapturePostAndWireInputsLeaveNoCardOrLedgerReservation() {
        for (type in VenuePushPayload.overthinkingTypes) {
            val payload = value(type)
            val wire = payload.target() + mapOf("presentationVersion" to "ANDROID_OVERTHINKING_V1",
                "sentAt" to payload.sentAt.toString(), "expiresAt" to payload.expiresAt.toString())
            assertFalse(renderer().receive(wire + ("recipientId" to UUID.randomUUID().toString())))
            assertFalse(renderer().receive(wire + ("postTitle" to "private extra")))
            assertFalse(renderer().receive(wire + ("notificationId" to "malformed")))
            assertFalse(VenueNotificationRenderer(context) { true }.post(payload, binding, scheduleWork = false))
            assertFalse(renderer().post(payload.copy(expiresAt = System.currentTimeMillis() - 1), binding, scheduleWork = false))
            PushResetState.setRequired(context, true)
            try { assertFalse(renderer().receive(wire)); assertFalse(renderer().post(payload, binding, scheduleWork = false)) }
            finally { PushResetState.setRequired(context, false) }
            assertFalse(PushNotificationLedger.seen(context, recipient, payload.notificationId, System.currentTimeMillis()))
        }
        val old = binding; val payload = value()
        PushNotificationState.bind(context, null); PushNotificationState.bind(context, recipient)
        binding = requireNotNull(PushNotificationState.capture(context, recipient))
        assertFalse(renderer().post(payload, old, scheduleWork = false))
        assertFalse(PushNotificationLedger.seen(context, recipient, payload.notificationId, System.currentTimeMillis()))
        assertTrue(manager.activeNotifications.isEmpty())
    }

    @Test fun renderedPendingIntentRetainsOldEpochAcrossSameRecipientRebind() {
        launch(); dart("initial")
        val payload = value(); post(payload)
        val pending = child(payload.notificationId).contentIntent
        val old = binding
        PushNotificationState.bind(context, null); PushNotificationState.bind(context, recipient)
        binding = requireNotNull(PushNotificationState.capture(context, recipient))
        assertNotEquals(old.epoch, binding.epoch)
        val sibling = value(); post(sibling)
        pending.send(); instrumentation.waitForIdleSync()
        assertTrue(events().isEmpty()); assertNotNull(child(sibling.notificationId))
    }

    @Test fun renderedTargetCapturedBeforeHandshakeCannotAdoptReboundEpoch() {
        launch() // Dart exists, but the native initialMessage handshake has not happened.
        val payload = value(); post(payload)
        child(payload.notificationId).contentIntent.send(); instrumentation.waitForIdleSync()
        eventually("Actual rendered tap consumed its card") { children().isEmpty() }
        PushNotificationState.bind(context, null); PushNotificationState.bind(context, recipient)
        binding = requireNotNull(PushNotificationState.capture(context, recipient))
        assertNull(dart("initial")); assertTrue(events().isEmpty())
    }
}
