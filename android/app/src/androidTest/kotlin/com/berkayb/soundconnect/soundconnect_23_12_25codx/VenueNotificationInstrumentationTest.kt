package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.res.Resources
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.service.notification.StatusBarNotification
import android.util.AtomicFile
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

/**
 * Emulator-only real NotificationManager renderer/lifecycle checks. Account and
 * ledger storage is isolated; all IDs are random and teardown cancels only those
 * IDs. No Firebase, activity launch, API call, source account mutation or channel
 * deletion. Renderer work scheduling is disabled for isolated fixtures; actual
 * expiry/group worker scheduling and cold FCM presentation need device acceptance.
 */
@RunWith(AndroidJUnit4::class)
class VenueNotificationInstrumentationTest {
    private lateinit var base: Context
    private lateinit var context: Context
    private lateinit var manager: NotificationManager
    private lateinit var parent: File
    private lateinit var directory: File
    private lateinit var binding: PushNotificationState.Binding
    private val ids = mutableSetOf<String>()
    private val bindings = mutableSetOf<PushNotificationState.Binding>()

    @Before fun isolate() {
        assertTrue("Emulator only", Build.FINGERPRINT.contains("generic") ||
            Build.MODEL.contains("sdk_gphone") || Build.HARDWARE in setOf("ranchu", "goldfish"))
        base = InstrumentationRegistry.getInstrumentation().targetContext
        manager = base.getSystemService(NotificationManager::class.java)
        assertTrue("Existing permission must be granted", manager.areNotificationsEnabled())
        if (Build.VERSION.SDK_INT >= 26) assertNotNull(manager.getNotificationChannel(PushNotificationState.CHANNEL))
        parent = File(base.noBackupFilesDir, "venue-notification-tests")
        directory = File(parent, UUID.randomUUID().toString())
        assertTrue(directory.mkdirs())
        context = object : ContextWrapper(base) { override fun getNoBackupFilesDir(): File = directory }
        binding = bindingFixture()
        SystemClock.sleep(1_000) // Respect ordinary Android package enqueue quotas.
    }

    @After fun cleanupOnlyFixtures() {
        if (::manager.isInitialized) {
            ids.forEach { manager.cancel(it, 0) }
            bindings.forEach {
                manager.cancel(VenueNotificationGroups.summaryTag(it), VenueNotificationGroups.SUMMARY_ID)
                manager.cancel(PushNotificationGroups.summaryTag(it), PushNotificationGroups.SUMMARY_ID)
            }
            eventually("Fixture notifications removed") { owned().isEmpty() }
        }
        if (::directory.isInitialized && directory.exists()) {
            check(directory.canonicalPath.startsWith(parent.canonicalPath + File.separator))
            check(directory.parentFile.canonicalFile == parent.canonicalFile)
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test fun actualRendererUsesFixedVariantBodyAndPrivateGenericLockscreen() {
        val payload = payload()
        postVenue(payload)
        val child = child(payload.notificationId).notification
        assertEquals("Soundconnect", child.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString())
        assertEquals("Etkinlik planına katılım geri çekildi.", child.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString())
        assertEquals(Notification.VISIBILITY_PRIVATE, child.visibility)
        assertEquals(VenueNotificationGroups.groupKey(binding), child.group)
        assertEquals(R.drawable.ic_notification, child.smallIcon.resId)
        assertEquals(ContextCompat.getColor(context, R.color.soundconnect_icon_accent), child.color)
        assertNotNull(child.contentIntent)
        assertNotNull(child.deleteIntent)
        if (Build.VERSION.SDK_INT >= 31) assertTrue(child.contentIntent.isImmutable)
        assertEquals(0, child.flags and Notification.FLAG_GROUP_SUMMARY)
        assertTrue(child.flags and Notification.FLAG_AUTO_CANCEL != 0)
        assertEquals("Yeni bir bildirimin var.", child.publicVersion.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString())
        assertFalse(child.publicVersion.extras.containsKey(PushDeliveredPolicy.RECIPIENT_EXTRA))
        assertFalse(child.publicVersion.extras.containsKey(PushDeliveredPolicy.EPOCH_EXTRA))
        assertFalse(child.publicVersion.extras.containsKey(PushDeliveredPolicy.ID_EXTRA))
        assertFalse(child.publicVersion.extras.containsKey(Notification.EXTRA_MESSAGES))
        assertFalse(child.publicVersion.extras.toString().contains("PLAN_WITHDRAWN"))
        val summary = venueSummary(1).notification
        assertEquals("Yeni bir bildirimin var.", summary.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString())
        assertEquals(Notification.VISIBILITY_PRIVATE, summary.visibility)
        assertEquals(0, summary.flags and Notification.FLAG_AUTO_CANCEL)
    }

    @Test fun applicationDecisionsSharePrivateLifecycleAndLeaveDmUntouched() {
        val dm = postDm()
        val cases = mapOf("VENUE_APPLICATION_APPROVED" to "Mekân başvurun onaylandı.",
            "VENUE_APPLICATION_REJECTED" to "Mekân başvurun reddedildi.")
        val posted = mutableListOf<VenuePushPayload>()
        for ((type, expectedBody) in cases) {
            val now = System.currentTimeMillis()
            val value = VenuePushPayload.parse(mapOf(
                "presentationVersion" to "ANDROID_VENUE_APPLICATION_V1",
                "notificationId" to UUID.randomUUID().toString(),
                "recipientId" to binding.recipient, "type" to type, "displayVariant" to "DEFAULT",
                "sentAt" to now.toString(), "expiresAt" to (now + 300_000).toString()
            ), now)!!
            postVenue(value)
            val notification = child(value.notificationId).notification
            assertEquals(expectedBody, notification.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString())
            assertEquals(Notification.VISIBILITY_PRIVATE, notification.visibility)
            assertEquals("Yeni bir bildirimin var.", notification.publicVersion.extras
                .getCharSequence(Notification.EXTRA_TEXT)?.toString())
            assertEquals(R.drawable.ic_notification, notification.smallIcon.resId)
            assertFalse(notification.extras.containsKey(Notification.EXTRA_MESSAGES))
            assertFalse(renderer().post(value, binding, scheduleWork = false))
            posted.add(value)
        }
        venueSummary(2)
        PushNotificationState.dismissNotification(context, binding, posted[0].notificationId)
        eventually("Reading one decision preserves the other and DM") {
            children().map { it.tag }.toSet() == setOf(dm, posted[1].notificationId)
        }
        venueSummary(1)
        assertFalse(renderer().post(posted[0], binding, scheduleWork = false))
        dmSummary()
    }

    @Test fun duplicateDeliveryKeepsOneStableCardAndOneInboxIdentifier() {
        val payload = payload()
        postVenue(payload)
        val postedAt = child(payload.notificationId).postTime
        assertFalse(renderer().post(payload, binding, scheduleWork = false))
        assertEquals(postedAt, child(payload.notificationId).postTime)
        assertEquals(setOf(payload.notificationId), venueChildren().map { it.tag }.toSet())
        val snapshot = PushNotificationState.deliveredSnapshot(context, binding.recipient)!!
        assertEquals(listOf(payload.notificationId), snapshot["notificationIds"])
        venueSummary(1)
    }

    @Test fun dmAndVenueHaveSeparateSummaryCountsAndSharedOwnedDeliverySnapshot() {
        val dm = postDm()
        val first = postVenue()
        val second = postVenue()
        assertEquals(2, venueSummary(2).notification.number)
        assertEquals(1, dmSummary().notification.number)
        assertEquals("2 yeni bildirimin var.", venueSummary(2).notification.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString())
        assertEquals("Yeni bir mesajın var.", dmSummary().notification.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString())
        assertNotEquals(venueSummary(2).tag, dmSummary().tag)
        val snapshot = PushNotificationState.deliveredSnapshot(context, binding.recipient)!!
        assertEquals(setOf(dm, first, second), (snapshot["notificationIds"] as List<*>).toSet())
    }

    @Test fun authoritativeReadOrInboxDeleteReconciliationRemovesOnlyRequestedVenueIds() {
        val dm = postDm()
        val first = postVenue()
        val second = postVenue()
        fun dismiss(id: String) = PushNotificationState.dismissDelivered(context,
            PushDeliveredPolicy.DismissRequest(PushDeliveredPolicy.Scope(binding.recipient, binding.epoch), setOf(id)))
        dismiss(first)
        eventually("Unrelated DM and venue survive") { children().map { it.tag }.toSet() == setOf(dm, second) }
        venueSummary(1)
        dmSummary()
        assertFalse(PushNotificationLedger.mayUpdate(context, binding.recipient, first, System.currentTimeMillis()))
        dismiss(second)
        eventually("Only venue group is gone") { venueOwned().isEmpty() && children().map { it.tag }.toSet() == setOf(dm) }
        dmSummary()
    }

    @Test fun tapTombstonePreventsDuplicateOrLateUpdateWithoutRemovingDm() {
        val dm = postDm()
        val payload = payload()
        postVenue(payload)
        // MainActivity's validated notification tap calls this same entrypoint.
        PushNotificationState.dismissNotification(context, binding, payload.notificationId)
        eventually("Tapped venue disappears independently") { venueOwned().isEmpty() }
        assertFalse(renderer().post(payload, binding, scheduleWork = false))
        var updated = false
        assertFalse(PushNotificationState.post(context, binding, payload.notificationId) { updated = true; true })
        assertFalse(updated)
        assertEquals(setOf(dm), children().map { it.tag }.toSet())
        dmSummary()
    }

    @Test fun capturedVenueGroupDeletePreservesLaterVenueArrivalAndDm() {
        val dm = postDm()
        val first = postVenue()
        val second = postVenue()
        val previousDelete = venueSummary(2).notification.deleteIntent
        val later = postVenue()
        assertNotEquals(previousDelete, venueSummary(3).notification.deleteIntent)
        PushNotificationDismissReceiver().onReceive(context, Intent(PushNotificationGroups.DISMISS_GROUP_ACTION).apply {
            putExtra(PushDeliveredPolicy.RECIPIENT_EXTRA, binding.recipient)
            putExtra(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
            putStringArrayListExtra(PushNotificationGroups.IDS_EXTRA, arrayListOf(first, second))
        })
        eventually("Captured set cannot clear later/unrelated cards") { children().map { it.tag }.toSet() == setOf(dm, later) }
        venueSummary(1)
        dmSummary()
    }

    @Test fun expiryRemovesOnlyDueVenueAndItsFinalSummary() {
        val dm = postDm()
        val now = System.currentTimeMillis()
        val firstPayload = payload(expiresAt = now + 120_000)
        val secondPayload = payload(expiresAt = now + 240_000)
        postVenue(firstPayload)
        postVenue(secondPayload)
        PushNotificationState.expireNotification(context, binding, firstPayload.notificationId,
            firstPayload.expiresAt - 1, firstPayload.expiresAt)
        assertEquals(2, venueChildren().size)
        PushNotificationState.expireNotification(context, binding, firstPayload.notificationId,
            firstPayload.expiresAt, firstPayload.expiresAt)
        eventually("Only first venue expires") { venueChildren().map { it.tag }.toSet() == setOf(secondPayload.notificationId) }
        venueSummary(1)
        PushNotificationState.expireNotification(context, binding, secondPayload.notificationId,
            secondPayload.expiresAt, secondPayload.expiresAt)
        eventually("Final venue expiry removes only venue summary") { venueOwned().isEmpty() }
        assertEquals(setOf(dm), children().map { it.tag }.toSet())
        dmSummary()
    }

    @Test fun logoutNotificationClearIncludesBothSummariesOnMinimumApi() {
        postDm()
        postVenue()
        // clearDelivered is the exact notification cleanup used by bind/logout.
        // Do not call bind here: its shortcut cleanup must not affect real fixtures.
        val testKeys = owned().map { it.key }.toSet()
        assertTrue("Never clear an unrelated app notification", manager.activeNotifications.all { it.key in testKeys })
        PushNotificationState.clearDelivered(context)
        eventually("DM and sc.venue summary clear even on API24-25") { owned().isEmpty() }
    }

    @Test fun previousEpochCannotPostDismissExpireOrRepairCurrentVenueGroup() {
        val old = binding
        binding = bindingFixture(old.recipient)
        val currentPayload = payload()
        postVenue(currentPayload)
        val originalSummary = venueSummary(1)
        assertFalse(renderer().post(payload().copy(recipientId = old.recipient), old, scheduleWork = false))
        PushNotificationState.dismissGroup(context, old, setOf(currentPayload.notificationId))
        PushNotificationState.expireNotification(context, old, currentPayload.notificationId, currentPayload.expiresAt, Long.MAX_VALUE)
        assertTrue(VenueGroupReconcileWorker.reconcile(context, old.recipient, old.epoch, 0)
            is androidx.work.ListenableWorker.Result.Success)
        assertEquals(setOf(currentPayload.notificationId), venueChildren().map { it.tag }.toSet())
        assertEquals(originalSummary.postTime, venueSummary(1).postTime)
    }

    @Test fun disabledResetForegroundAndWrongRecipientFailBeforeReservation() {
        val candidate = payload()
        @Suppress("DEPRECATION")
        val disabledResources = object : Resources(base.resources.assets, base.resources.displayMetrics,
            base.resources.configuration) {
            override fun getBoolean(id: Int): Boolean = if (id == R.bool.soundconnect_push_enabled) false else super.getBoolean(id)
        }
        val disabled = object : ContextWrapper(context) { override fun getResources(): Resources = disabledResources }
        assertFalse(VenueNotificationRenderer(disabled) { false }.post(candidate, binding, scheduleWork = false))
        assertFalse(VenueNotificationRenderer(context) { true }.post(candidate, binding, scheduleWork = false))
        assertFalse(renderer().post(candidate.copy(recipientId = UUID.randomUUID().toString()), binding, scheduleWork = false))
        PushResetState.setRequired(context, true)
        try { assertFalse(renderer().post(candidate, binding, scheduleWork = false)) }
        finally { PushResetState.setRequired(context, false) }
        assertFalse(PushNotificationLedger.seen(context, binding.recipient, candidate.notificationId, System.currentTimeMillis()))
        assertTrue(owned().isEmpty())
    }

    @Test fun pendingVenueRepairCannotRecreateDismissedGroupOrChildren() {
        val first = postVenue()
        val second = postVenue()
        PushNotificationState.dismissGroup(context, binding, setOf(first, second))
        eventually("Both dismissed venue children and summary gone") { venueOwned().isEmpty() }
        assertTrue(VenueGroupReconcileWorker.reconcile(context, binding.recipient, binding.epoch, 0)
            is androidx.work.ListenableWorker.Result.Success)
        assertTrue(venueOwned().isEmpty())
    }

    @Test fun allStudioVariantsRenderPrivateFixedCopyAlongsideDmVenueAndApplication() {
        val dm = postDm()
        val venue = postVenue()
        val now = System.currentTimeMillis()
        val application = VenuePushPayload(UUID.randomUUID().toString(), binding.recipient,
            "VENUE_APPLICATION_APPROVED", "DEFAULT", now, now + 300_000)
        postVenue(application)
        val cases = listOf(
            Triple("STUDIO_RESERVATION_CREATED", "STUDIO_CREATED_PENDING", "Yeni bir stüdyo rezervasyon talebin var."),
            Triple("STUDIO_RESERVATION_CREATED", "STUDIO_CREATED_CONFIRMED", "Stüdyona yeni bir rezervasyon yapıldı."),
            Triple("STUDIO_RESERVATION_CONFLICTING_REQUESTS", "STUDIO_CONFLICTING_REQUESTS", "Çakışan stüdyo rezervasyon taleplerin var."),
            Triple("STUDIO_RESERVATION_APPROVED", "STUDIO_APPROVED", "Stüdyo rezervasyon talebin onaylandı."),
            Triple("STUDIO_RESERVATION_REJECTED", "STUDIO_REJECTED", "Stüdyo rezervasyon talebin reddedildi."),
            Triple("STUDIO_RESERVATION_REJECTED", "STUDIO_REJECTED_CONFLICT", "Çakışan bir talep onaylandığı için rezervasyon talebin reddedildi."),
            Triple("STUDIO_RESERVATION_CANCELLED_BY_CUSTOMER", "STUDIO_CANCELLED_BY_CUSTOMER", "Bir müşteri stüdyo rezervasyonunu iptal etti."),
            Triple("STUDIO_RESERVATION_CANCELLED_BY_STUDIO", "STUDIO_CANCELLED_BY_STUDIO", "Stüdyo rezervasyonun iptal edildi."),
            Triple("STUDIO_RESERVATION_CANCELLED_BY_STUDIO", "STUDIO_ROOM_ARCHIVED", "Oda arşivlendiği için stüdyo rezervasyonun iptal edildi."))
        val studio = mutableListOf<VenuePushPayload>()
        for ((type, variant, expectedBody) in cases) {
            val value = studioPayload(type, variant)
            postVenue(value)
            val notification = child(value.notificationId).notification
            assertEquals(expectedBody, notification.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString())
            assertEquals(Notification.CATEGORY_EVENT, notification.category)
            assertEquals(Notification.VISIBILITY_PRIVATE, notification.visibility)
            assertEquals(R.drawable.ic_notification, notification.smallIcon.resId)
            assertEquals(ContextCompat.getColor(context, R.color.soundconnect_icon_accent), notification.color)
            assertEquals("Yeni bir bildirimin var.", notification.publicVersion.extras
                .getCharSequence(Notification.EXTRA_TEXT)?.toString())
            assertFalse(notification.extras.containsKey(Notification.EXTRA_MESSAGES))
            assertFalse(notification.publicVersion.extras.toString().contains("STUDIO_"))
            assertFalse(renderer().post(value, binding, scheduleWork = false))
            studio.add(value)
        }
        venueSummary(11)
        dmSummary()
        val removed = studio.first()
        PushNotificationState.dismissDelivered(context, PushDeliveredPolicy.DismissRequest(
            PushDeliveredPolicy.Scope(binding.recipient, binding.epoch), setOf(removed.notificationId)))
        val expected = setOf(dm, venue, application.notificationId) + studio.drop(1).map { it.notificationId }
        eventually("Reading one studio alert preserves every unrelated module") {
            children().map { it.tag }.toSet() == expected
        }
        venueSummary(10)
        val snapshot = PushNotificationState.deliveredSnapshot(context, binding.recipient)!!
        assertEquals(expected, (snapshot["notificationIds"] as List<*>).toSet())
        assertFalse(renderer().post(removed, binding, scheduleWork = false))
    }

    @Test fun studioExpiryAndTapCannotResurrectOrRemoveOtherBusinessCards() {
        val dm = postDm()
        val venue = postVenue()
        val first = studioPayload("STUDIO_RESERVATION_APPROVED", "STUDIO_APPROVED")
        val second = studioPayload("STUDIO_RESERVATION_CANCELLED_BY_STUDIO", "STUDIO_ROOM_ARCHIVED")
        postVenue(first)
        postVenue(second)
        PushNotificationState.expireNotification(context, binding, first.notificationId, first.expiresAt, first.expiresAt)
        eventually("Only the due studio child expires") {
            children().map { it.tag }.toSet() == setOf(dm, venue, second.notificationId)
        }
        assertFalse(renderer().post(first, binding, scheduleWork = false))
        PushNotificationState.dismissNotification(context, binding, second.notificationId)
        eventually("Tapped studio child leaves DM and venue") {
            children().map { it.tag }.toSet() == setOf(dm, venue)
        }
        venueSummary(1)
        dmSummary()
        assertFalse(renderer().post(second, binding, scheduleWork = false))
        assertTrue(VenueGroupReconcileWorker.reconcile(context, binding.recipient, binding.epoch, 0)
            is androidx.work.ListenableWorker.Result.Success)
        assertEquals(setOf(dm, venue), children().map { it.tag }.toSet())
    }

    @Test fun studioSessionAndInvalidRenderGuardsNeverReserveARejectedAlert() {
        val candidate = studioPayload("STUDIO_RESERVATION_CREATED", "STUDIO_CREATED_PENDING")
        ids.add(candidate.notificationId)
        val old = binding
        binding = bindingFixture(old.recipient)
        assertFalse(renderer().post(candidate, old, scheduleWork = false))
        assertFalse(renderer().post(candidate.copy(recipientId = UUID.randomUUID().toString()), binding, scheduleWork = false))
        assertFalse(renderer().post(candidate.copy(type = "VENUE_APPLICATION_APPROVED"), binding, scheduleWork = false))
        assertFalse(renderer().post(candidate.copy(displayVariant = "DEFAULT"), binding, scheduleWork = false))
        assertFalse(renderer().post(candidate.copy(expiresAt = System.currentTimeMillis()), binding, scheduleWork = false))
        assertFalse(VenueNotificationRenderer(context) { true }.post(candidate, binding, scheduleWork = false))
        PushResetState.setRequired(context, true)
        try { assertFalse(renderer().post(candidate, binding, scheduleWork = false)) }
        finally { PushResetState.setRequired(context, false) }
        assertFalse(PushNotificationLedger.seen(context, binding.recipient, candidate.notificationId, System.currentTimeMillis()))
        assertTrue(owned().isEmpty())
        postVenue(candidate)
        assertFalse(renderer().post(candidate, old, scheduleWork = false))
        PushNotificationState.dismissGroup(context, old, setOf(candidate.notificationId))
        assertEquals(setOf(candidate.notificationId), venueChildren().map { it.tag }.toSet())
    }

    private fun studioPayload(type: String, variant: String): VenuePushPayload {
        val now = System.currentTimeMillis()
        return VenuePushPayload.parse(mapOf(
            "presentationVersion" to "ANDROID_STUDIO_V1", "type" to type, "displayVariant" to variant,
            "notificationId" to UUID.randomUUID().toString(), "recipientId" to binding.recipient,
            "sentAt" to now.toString(), "expiresAt" to (now + 300_000).toString()), now)!!
    }

    private fun renderer() = VenueNotificationRenderer(context) { false }

    private fun payload(expiresAt: Long = System.currentTimeMillis() + 300_000) = VenuePushPayload(
        UUID.randomUUID().toString(), binding.recipient, "EVENT_PERFORMER_REJECTED", "PLAN_WITHDRAWN",
        System.currentTimeMillis(), expiresAt)

    private fun postVenue(value: VenuePushPayload = payload()): String {
        ids.add(value.notificationId)
        SystemClock.sleep(600)
        assertTrue(renderer().post(value, binding, scheduleWork = false))
        eventually("Venue child accepted by real OS") { children().any { it.tag == value.notificationId } }
        SystemClock.sleep(600)
        PushNotificationState.reconcileVenueGroup(context, binding, scheduleRepair = false)
        venueSummary(venueChildren().size)
        return value.notificationId
    }

    private fun postDm(): String {
        val id = UUID.randomUUID().toString()
        ids.add(id)
        val expiry = System.currentTimeMillis() + 300_000
        val notification = NotificationCompat.Builder(context, PushNotificationState.CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(ContextCompat.getColor(context, R.color.soundconnect_icon_accent))
            .setContentTitle("QA DM fixture").setContentText(PushNotificationPayload.BODY)
            .setGroup(PushNotificationGroups.groupKey(binding)).setOnlyAlertOnce(true).setSilent(true)
            .addExtras(Bundle().apply {
                putString(PushDeliveredPolicy.RECIPIENT_EXTRA, binding.recipient)
                putString(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
                putString(PushDeliveredPolicy.ID_EXTRA, id)
                putLong(PushNotificationGroups.EXPIRY_EXTRA, expiry)
            }).build()
        SystemClock.sleep(600)
        assertTrue(PushNotificationState.postInitial(context, binding, id, expiry) { manager.notify(id, 0, notification); true })
        eventually("DM fixture accepted") { children().any { it.tag == id } }
        SystemClock.sleep(600)
        PushNotificationState.reconcileGroup(context, binding, scheduleRepair = false)
        dmSummary()
        return id
    }

    private fun bindingFixture(recipient: String = UUID.randomUUID().toString()): PushNotificationState.Binding {
        val value = PushNotificationState.Binding(recipient, UUID.randomUUID().toString())
        bindings.add(value)
        val file = AtomicFile(File(directory, "soundconnect-push-rendering"))
        val stream = file.startWrite()
        try {
            stream.write(JSONObject().put("recipientId", value.recipient).put("epoch", value.epoch)
                .toString().toByteArray(Charsets.UTF_8))
            file.finishWrite(stream)
        } catch (error: Exception) { file.failWrite(stream); throw error }
        return value
    }

    private fun owned(): List<StatusBarNotification> = manager.activeNotifications.filter { active ->
        active.tag in ids || bindings.any { active.tag == VenueNotificationGroups.summaryTag(it) ||
            active.tag == PushNotificationGroups.summaryTag(it) }
    }
    private fun children() = owned().filter { it.id == 0 && it.tag in ids }
    private fun venueOwned() = owned().filter { it.notification.group == VenueNotificationGroups.groupKey(binding) }
    private fun venueChildren() = venueOwned().filter { it.id == 0 }
    private fun child(id: String) = children().single { it.tag == id }
    private fun venueSummary(count: Int): StatusBarNotification {
        eventually("Venue summary count $count") { venueOwned().any { it.id == VenueNotificationGroups.SUMMARY_ID && it.notification.number == count } }
        return venueOwned().single { it.id == VenueNotificationGroups.SUMMARY_ID }
    }
    private fun dmSummary(): StatusBarNotification {
        eventually("DM summary remains independent") { owned().any { it.tag == PushNotificationGroups.summaryTag(binding) } }
        return owned().single { it.tag == PushNotificationGroups.summaryTag(binding) }
    }
    private fun eventually(message: String, test: () -> Boolean) {
        val until = SystemClock.elapsedRealtime() + 5_000
        while (!test() && SystemClock.elapsedRealtime() < until) SystemClock.sleep(25)
        assertTrue(message, test())
    }
}
