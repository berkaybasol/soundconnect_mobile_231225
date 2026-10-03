package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.app.Notification
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
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
 * Emulator-only real NotificationManager tests. The production group builder,
 * cancellation entrypoints and durable update guards run with an isolated
 * binding/ledger directory and random scoped IDs. No activity, Firebase, network,
 * real account binding, channel deletion or cancelAll operation is used.
 * Child fixtures deliberately bypass the renderer's foreground/shortcut path;
 * FCM and OEM presentation are separate device checks.
 */
@RunWith(AndroidJUnit4::class)
class PushNotificationGroupsInstrumentationTest {
    private lateinit var base: Context
    private lateinit var context: Context
    private lateinit var manager: NotificationManager
    private lateinit var parent: File
    private lateinit var directory: File
    private lateinit var binding: PushNotificationState.Binding
    private val ids = mutableSetOf<String>()
    private val bindings = mutableSetOf<PushNotificationState.Binding>()

    @Before fun isolateBindingAndLedger() {
        assertTrue("Run this suite only on an emulator", Build.FINGERPRINT.contains("generic") ||
            Build.MODEL.contains("sdk_gphone") || Build.HARDWARE in setOf("ranchu", "goldfish"))
        base = InstrumentationRegistry.getInstrumentation().targetContext
        manager = base.getSystemService(NotificationManager::class.java)
        assertTrue("Notification permission must already be enabled", manager.areNotificationsEnabled())
        if (Build.VERSION.SDK_INT >= 26) {
            assertNotNull("Initialize the existing DM channel before running this suite",
                manager.getNotificationChannel(PushNotificationState.CHANNEL))
        }
        parent = File(base.noBackupFilesDir, "push-group-tests")
        directory = File(parent, UUID.randomUUID().toString())
        assertTrue(directory.mkdirs())
        context = object : ContextWrapper(base) {
            override fun getNoBackupFilesDir(): File = directory
        }
        binding = bindingFixture()
        // These are independent lifecycle checks, not a throughput test. The
        // emulator logged NotificationService enqueue-rate shedding at 5.39/7.77
        // per second when adjacent cases posted fixtures without any cadence.
        // Keep the platform limit unchanged and let the previous case settle.
        SystemClock.sleep(1_000)
    }

    @After fun removeOnlyTestOwnedNotificationsAndStorage() {
        if (::manager.isInitialized) {
            ids.forEach { manager.cancel(it, 0) }
            bindings.forEach { manager.cancel(PushNotificationGroups.summaryTag(it), PushNotificationGroups.SUMMARY_ID) }
            eventually("Only test-owned notifications are removed") { testNotifications().isEmpty() }
        }
        if (::directory.isInitialized && directory.exists()) {
            check(directory.canonicalPath.startsWith(parent.canonicalPath + File.separator))
            check(directory.parentFile.canonicalFile == parent.canonicalFile)
            assertTrue(directory.deleteRecursively())
        }
    }

    @Test fun twoChildrenShareDedicatedSummaryAndRemainIndividualInboxIdentifiers() {
        val first = postChild()
        val second = postChild()
        val summary = awaitSummary()
        assertTrue(summary.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0)
        assertEquals("Opening the summary must not auto-cancel unread children",
            0, summary.notification.flags and Notification.FLAG_AUTO_CANCEL)
        assertNotNull(summary.notification.contentIntent)
        assertNotNull(summary.notification.deleteIntent)
        assertEquals(PushNotificationGroups.groupKey(binding), summary.notification.group)
        assertEquals(R.drawable.ic_notification, summary.notification.smallIcon.resId)
        assertEquals(0, summary.notification.iconLevel)
        assertEquals(ContextCompat.getColor(context, R.color.soundconnect_group_accent), summary.notification.color)
        assertEquals(2, summary.notification.number)
        if (Build.VERSION.SDK_INT >= 26) {
            assertEquals(Notification.GROUP_ALERT_CHILDREN, summary.notification.groupAlertBehavior)
        }
        val childAccent = ContextCompat.getColor(context, R.color.soundconnect_icon_accent)
        children(binding).forEach {
            // Preserve the intended shared-resource, distinct-accent pairing;
            // rendered badge colors still require separate OEM visual checks.
            assertEquals(summary.notification.smallIcon.resId, it.notification.smallIcon.resId)
            assertEquals(0, it.notification.iconLevel)
            assertEquals(childAccent, it.notification.color)
            assertNotEquals(summary.notification.color, it.notification.color)
            assertEquals(PushNotificationGroups.groupKey(binding), it.notification.group)
            assertEquals(0, it.notification.flags and Notification.FLAG_GROUP_SUMMARY)
        }
        assertEquals(setOf(first, second), children(binding).map { it.tag }.toSet())
        val snapshot = PushNotificationState.deliveredSnapshot(context, binding.recipient)!!
        assertEquals(setOf(first, second), (snapshot["notificationIds"] as List<*>).toSet())
    }

    @Test fun successfulReadDismissalKeepsOtherChildAndItsSummary() {
        val first = postChild()
        val second = postChild()
        PushNotificationState.dismissDelivered(context, PushDeliveredPolicy.DismissRequest(
            PushDeliveredPolicy.Scope(binding.recipient, binding.epoch), setOf(first)))
        eventually("Only the read child disappears") { children(binding).map { it.tag }.toSet() == setOf(second) }
        awaitSummary()
        assertFalse(PushNotificationLedger.mayUpdate(context, binding.recipient, first, System.currentTimeMillis()))
        assertTrue(PushNotificationLedger.mayUpdate(context, binding.recipient, second, System.currentTimeMillis()))
    }

    @Test fun finalChildDismissalRemovesSummaryWithoutRepostingItOnReconcile() {
        val first = postChild()
        val second = postChild()
        PushNotificationState.dismissNotification(context, binding, first)
        eventually("One child remains") { children(binding).map { it.tag }.toSet() == setOf(second) }
        awaitSummary()
        PushNotificationState.dismissNotification(context, binding, second)
        eventually("Final child and summary disappear") { owned(binding).isEmpty() }
        PushNotificationState.reconcileGroup(context, binding)
        assertTrue(owned(binding).isEmpty())
    }

    @Test fun dismissedChildCannotBeResurrectedByAnAvatarUpdateOrDuplicateDelivery() {
        val first = postChild()
        val second = postChild()
        val delete = PushNotificationGroups.deleteIntent(context, binding, setOf(first))
        if (Build.VERSION.SDK_INT >= 31) assertTrue(delete.isImmutable)
        val otherEpoch = binding.copy(epoch = UUID.randomUUID().toString())
        assertNotEquals(delete, PushNotificationGroups.deleteIntent(context, otherEpoch, setOf(first)))
        @Suppress("DEPRECATION")
        val receiver = base.packageManager.getReceiverInfo(
            ComponentName(base, PushNotificationDismissReceiver::class.java), 0)
        assertFalse("Notification dismissal entrypoint must not be exported", receiver.exported)
        PushNotificationDismissReceiver().onReceive(context, Intent(PushNotificationGroups.DISMISS_ACTION).apply {
            putExtra(PushDeliveredPolicy.RECIPIENT_EXTRA, binding.recipient)
            putExtra(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
            putStringArrayListExtra(PushNotificationGroups.IDS_EXTRA, arrayListOf(first))
        })
        var avatarActionRan = false
        assertFalse(PushNotificationState.post(context, binding, first) { avatarActionRan = true; true })
        assertFalse(avatarActionRan)
        assertFalse(PushNotificationState.postInitial(context, binding, first,
            System.currentTimeMillis() + 60_000) { fail("Dismissed deliveries must stay deduplicated"); true })
        PushNotificationState.reconcileGroup(context, binding)
        eventually("Only the unread sibling remains") { children(binding).map { it.tag }.toSet() == setOf(second) }
        awaitSummary()
    }

    @Test fun capturedGroupDismissalPreservesAChildThatArrivedAfterTheSnapshot() {
        val first = postChild()
        val second = postChild()
        val captured = setOf(first, second)
        val capturedDelete = awaitSummary().notification.deleteIntent
        val later = postChild()
        assertNotEquals("A later arrival must not mutate the old summary callback",
            capturedDelete, awaitSummary().notification.deleteIntent)
        PushNotificationDismissReceiver().onReceive(context, Intent(PushNotificationGroups.DISMISS_GROUP_ACTION).apply {
            putExtra(PushDeliveredPolicy.RECIPIENT_EXTRA, binding.recipient)
            putExtra(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
            putStringArrayListExtra(PushNotificationGroups.IDS_EXTRA, ArrayList(captured))
        })
        eventually("New arrivals are outside the dismissed group snapshot") {
            children(binding).map { it.tag }.toSet() == setOf(later)
        }
        awaitSummary()
        assertTrue(PushNotificationLedger.mayUpdate(context, binding.recipient, later, System.currentTimeMillis()))
    }

    @Test fun oldEpochDismissalExpiryAndReconcileCannotTouchNewLoginGroup() {
        val old = binding
        val oldId = postChild()
        binding = bindingFixture(old.recipient)
        val currentId = postChild()
        val currentSummary = awaitSummary()
        assertNotEquals(PushNotificationGroups.summaryTag(old), currentSummary.tag)
        PushNotificationState.dismissNotification(context, old, currentId)
        PushNotificationState.dismissGroup(context, old, setOf(oldId, currentId))
        PushNotificationState.expireNotification(context, old, currentId, 1, Long.MAX_VALUE)
        PushNotificationState.reconcileGroup(context, old)
        assertEquals(setOf(currentId), children(binding).map { it.tag }.toSet())
        assertEquals(currentSummary.tag, awaitSummary().tag)
        assertTrue(PushNotificationLedger.mayUpdate(context, binding.recipient, currentId, System.currentTimeMillis()))
    }

    @Test fun expiryRemovesOnlyDueChildAndFinalExpiryRemovesSummary() {
        val now = System.currentTimeMillis()
        val firstExpiry = now + 120_000
        val secondExpiry = now + 240_000
        val first = postChild(expiresAt = firstExpiry)
        val second = postChild(expiresAt = secondExpiry)
        PushNotificationState.expireNotification(context, binding, first, firstExpiry, now)
        assertEquals(setOf(first, second), children(binding).map { it.tag }.toSet())
        PushNotificationState.expireNotification(context, binding, first, firstExpiry - 1, firstExpiry)
        assertEquals("A mismatched expiry must not cancel a valid delivery",
            setOf(first, second), children(binding).map { it.tag }.toSet())
        PushNotificationState.expireNotification(context, binding, first, firstExpiry, firstExpiry)
        eventually("Only due child expires") { children(binding).map { it.tag }.toSet() == setOf(second) }
        awaitSummary()
        PushNotificationState.expireNotification(context, binding, second, secondExpiry, secondExpiry)
        eventually("Final expiry removes group") { owned(binding).isEmpty() }
    }

    @Test fun delayedExpiryStillRemovesOwnedCardAfterAnotherReservationPrunesItsLedgerRow() {
        val oldExpiry = System.currentTimeMillis() + 6_000
        // No OS timeout is set on fixture children: this retains the card just as
        // API 24-25 can when the expiry worker was delayed. The live sibling keeps
        // the summary's own deadline from cascading to the group first.
        val old = postChild(expiresAt = oldExpiry)
        val live = postChild(expiresAt = oldExpiry + 300_000)
        eventually("Old fixture reaches its real expiry") { System.currentTimeMillis() >= oldExpiry }
        val pruningReservation = UUID.randomUUID().toString()
        assertTrue(PushNotificationLedger.reserve(context, binding.recipient, pruningReservation,
            System.currentTimeMillis() + 300_000, System.currentTimeMillis()))
        assertNull("Reservation pruning has removed the expired dedup row",
            PushNotificationLedger.expiry(context, binding.recipient, old))
        assertEquals("The delayed worker still has an active OS card to remove",
            setOf(old, live), children(binding).map { it.tag }.toSet())
        PushNotificationState.expireNotification(context, binding, old, oldExpiry)
        eventually("Pruned ledger history must not leave an expired OS child orphaned") {
            children(binding).map { it.tag }.toSet() == setOf(live)
        }
        awaitSummary(expectedCount = 1)
        assertTrue(PushNotificationLedger.mayUpdate(context, binding.recipient, live, System.currentTimeMillis()))
    }

    @Test fun unpacedBurstAndStaleSummaryAreReconciledWithoutRepostingChildren() {
        val burst = (1..8).map { postChild(paced = false) }.toSet()
        eventually("The real OS accepts children from the burst") { children(binding).isNotEmpty() }
        // Allow the OS quota to recover, as the coalesced worker's delay does.
        // The initial burst above has no fixture pacing and no quota override.
        // Android/OEM quotas own acceptance; count only actually active children.
        SystemClock.sleep(2_500)
        val accepted = children(binding).map { it.tag }.toSet()
        assertTrue(accepted.isNotEmpty() && burst.containsAll(accepted))
        System.out.println("DM_BURST attempted=${burst.size} active=${accepted.size}")
        repairGroup()
        val summary = awaitSummary(expectedCount = accepted.size)
        val childTimes = children(binding).associate { it.tag to it.postTime }
        SystemClock.sleep(1_000)
        val staleCount = accepted.size + 100
        val stale = Notification.Builder.recoverBuilder(context, summary.notification).setNumber(staleCount).build()
        manager.notify(summary.tag, summary.id, stale)
        eventually("A stale OS count is observable") {
            owned(binding).any { it.id == PushNotificationGroups.SUMMARY_ID && it.notification.number == staleCount }
        }
        SystemClock.sleep(1_000)
        assertTrue("An unconfirmed notify must request a later confirmation",
            repairGroup() is androidx.work.ListenableWorker.Result.Retry)
        awaitSummary(expectedCount = accepted.size)
        assertTrue(repairGroup() is androidx.work.ListenableWorker.Result.Success)
        assertEquals("Summary repair never posts a child", childTimes,
            children(binding).associate { it.tag to it.postTime })
    }

    @Test fun pendingRepairAfterGroupDismissalCannotRecreateSummaryOrChildren() {
        val first = postChild()
        val second = postChild()
        val scheduledBinding = binding
        PushNotificationState.dismissGroup(context, binding, setOf(first, second))
        eventually("Dismissal finishes before the scheduled repair runs") { owned(binding).isEmpty() }
        assertTrue(repairGroup(scheduledBinding) is androidx.work.ListenableWorker.Result.Success)
        assertTrue(owned(binding).isEmpty())
        assertFalse(PushNotificationLedger.mayUpdate(context, binding.recipient, first, System.currentTimeMillis()))
        assertFalse(PushNotificationLedger.mayUpdate(context, binding.recipient, second, System.currentTimeMillis()))
    }

    @Test fun pendingRepairFromPreviousLoginCannotChangeTheCurrentGroup() {
        val oldBinding = binding
        postChild()
        binding = bindingFixture(oldBinding.recipient)
        val currentChild = postChild()
        val summary = awaitSummary()
        assertTrue(repairGroup(oldBinding) is androidx.work.ListenableWorker.Result.Success)
        assertEquals(setOf(currentChild), children(binding).map { it.tag }.toSet())
        assertEquals(summary.postTime, awaitSummary().postTime)
    }

    private fun repairGroup(value: PushNotificationState.Binding = binding) =
        PushGroupReconcileWorker.reconcile(context, value.recipient, value.epoch, 0)

    @Test fun lockScreenSummaryContainsNoSenderOrMessagePreview() {
        val privateName = "QA-private-sender-${UUID.randomUUID()}"
        postChild(senderName = privateName)
        postChild(senderName = privateName)
        val summary = awaitSummary().notification
        assertEquals(Notification.VISIBILITY_PRIVATE, summary.visibility)
        val publicVersion = summary.publicVersion
        assertNotNull(publicVersion)
        assertEquals(R.drawable.ic_notification, publicVersion.smallIcon.resId)
        assertEquals(0, publicVersion.iconLevel)
        assertEquals(ContextCompat.getColor(context, R.color.soundconnect_group_accent), publicVersion.color)
        assertEquals("Soundconnect", publicVersion.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString())
        assertFalse(publicVersion.extras.toString().contains(privateName))
        assertFalse(publicVersion.extras.containsKey(Notification.EXTRA_MESSAGES))
        assertFalse(publicVersion.extras.containsKey(Notification.EXTRA_TEXT_LINES))
        assertFalse(publicVersion.extras.containsKey(PushDeliveredPolicy.RECIPIENT_EXTRA))
        assertFalse(publicVersion.extras.containsKey(PushDeliveredPolicy.EPOCH_EXTRA))
        assertFalse(publicVersion.extras.containsKey(PushDeliveredPolicy.ID_EXTRA))
        assertFalse(publicVersion.extras.getCharSequence(Notification.EXTRA_TEXT).isNullOrBlank())
    }

    private fun bindingFixture(recipient: String = UUID.randomUUID().toString()): PushNotificationState.Binding {
        val value = PushNotificationState.Binding(recipient, UUID.randomUUID().toString())
        bindings.add(value)
        val storage = AtomicFile(File(directory, "soundconnect-push-rendering"))
        val stream = storage.startWrite()
        try {
            stream.write(JSONObject().put("recipientId", value.recipient).put("epoch", value.epoch)
                .toString().toByteArray(Charsets.UTF_8))
            storage.finishWrite(stream)
        } catch (error: Exception) {
            storage.failWrite(stream)
            throw error
        }
        return value
    }

    private fun postChild(senderName: String = "QA group fixture",
                          expiresAt: Long = System.currentTimeMillis() + 300_000,
                          paced: Boolean = true): String {
        val id = UUID.randomUUID().toString()
        ids.add(id)
        val child = NotificationCompat.Builder(context, PushNotificationState.CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(ContextCompat.getColor(context, R.color.soundconnect_icon_accent))
            .setContentTitle(senderName).setContentText(PushNotificationPayload.BODY)
            .setGroup(PushNotificationGroups.groupKey(binding))
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)
            .setOnlyAlertOnce(true).setSilent(true)
            .addExtras(Bundle().apply {
                putString(PushDeliveredPolicy.RECIPIENT_EXTRA, binding.recipient)
                putString(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
                putString(PushDeliveredPolicy.ID_EXTRA, id)
                putLong(PushNotificationGroups.EXPIRY_EXTRA, expiresAt)
            }).build()
        // One fixture emits a child plus a summary. Pace these real OS enqueues
        // explicitly instead of retrying a shed update or lifting Android quotas.
        if (paced) SystemClock.sleep(500)
        assertTrue(PushNotificationState.postInitial(context, binding, id, expiresAt) {
            manager.notify(id, 0, child)
            if (!paced) PushNotificationGroups.reconcileLocked(context, binding, child, id, scheduleRepair = false)
            true
        })
        if (paced) {
            eventually("Fixture child reaches NotificationManager") { children(binding).any { it.tag == id } }
            SystemClock.sleep(500)
            PushNotificationState.reconcileGroup(context, binding, scheduleRepair = false)
            awaitSummary()
        }
        return id
    }

    private fun owned(value: PushNotificationState.Binding): List<StatusBarNotification> =
        manager.activeNotifications.filter {
            it.tag == PushNotificationGroups.summaryTag(value) ||
                (it.tag in ids && it.notification.extras.getString(PushDeliveredPolicy.RECIPIENT_EXTRA) == value.recipient &&
                    it.notification.extras.getString(PushDeliveredPolicy.EPOCH_EXTRA) == value.epoch)
        }

    private fun children(value: PushNotificationState.Binding) = owned(value).filter { it.id == 0 && it.tag in ids }

    private fun testNotifications(): List<StatusBarNotification> = manager.activeNotifications.filter {
        it.tag in ids || bindings.any { value -> it.tag == PushNotificationGroups.summaryTag(value) }
    }

    private fun awaitSummary(expectedCount: Int = children(binding).size): StatusBarNotification {
        eventually("Scoped summary reaches NotificationManager") {
            owned(binding).any { it.tag == PushNotificationGroups.summaryTag(binding) &&
                it.id == PushNotificationGroups.SUMMARY_ID && it.notification.number == expectedCount }
        }
        return owned(binding).single { it.tag == PushNotificationGroups.summaryTag(binding) && it.id == PushNotificationGroups.SUMMARY_ID }
    }

    private fun eventually(message: String, predicate: () -> Boolean) {
        val deadline = SystemClock.elapsedRealtime() + 5_000
        while (!predicate() && SystemClock.elapsedRealtime() < deadline) SystemClock.sleep(25)
        assertTrue(message, predicate())
    }
}
