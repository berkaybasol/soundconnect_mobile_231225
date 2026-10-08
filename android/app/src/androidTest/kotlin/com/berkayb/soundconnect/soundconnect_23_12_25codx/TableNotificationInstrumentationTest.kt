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
class TableNotificationInstrumentationTest {
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
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(android.app.NotificationChannel(PushNotificationState.CHANNEL, "Soundconnect bildirimleri", NotificationManager.IMPORTANCE_HIGH))
        parent = File(base.noBackupFilesDir, "table31-notification-tests")
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

    private fun media(type: String = "TABLE_JOIN_REQUEST_RECEIVED"): VenuePushPayload {
        val now = System.currentTimeMillis()
        return VenuePushPayload.parse(mapOf("presentationVersion" to "ANDROID_TABLE_V1",
            "type" to type,"displayVariant" to if(type == "TABLE_CANCELLED") "OWNER_CANCELLED" else "DEFAULT","notificationId" to UUID.randomUUID().toString(),
            "recipientId" to binding.recipient,"sentAt" to now.toString(),"expiresAt" to (now+300_000).toString()),now)!!
    }
    private fun tap(value: VenuePushPayload, epoch: String? = binding.epoch) = Intent(PushOpenTarget.NOTIFICATION_ACTION).apply {
        value.target().forEach { (key,value) -> putExtra("sc.push.$key",value) }
        if(epoch != null) putExtra(PushDeliveredPolicy.EPOCH_EXTRA,epoch)
    }
    @Test fun eightTableVariantsUseExistingIconsPrivatePublicCopyAndDistinctIntents() {
        val first=media(); val second=media("TABLE_JOIN_REQUEST_APPROVED")
        for(value in listOf(first,second,media("TABLE_JOIN_REQUEST_REJECTED"),media("TABLE_REMOVED"),media("TABLE_PARTICIPANT_LEFT"),media("TABLE_CANCELLED"),media("TABLE_CANCELLED").copy(displayVariant="OWNER_JOINED_ANOTHER_TABLE"),media("TABLE_EXPIRED"))) {
            postVenue(value)
            val n=child(value.notificationId).notification
            assertEquals(value.body,n.extras.getCharSequence(Notification.EXTRA_TEXT).toString())
            assertEquals(Notification.VISIBILITY_PRIVATE,n.visibility)
            assertEquals(R.drawable.ic_notification,n.smallIcon.resId)
            assertEquals(ContextCompat.getColor(context,R.color.soundconnect_icon_accent),n.color)
            assertEquals("Yeni bir bildirimin var.",n.publicVersion.extras.getCharSequence(Notification.EXTRA_TEXT).toString())
            assertFalse(n.publicVersion.extras.toString().contains(binding.recipient))
            assertFalse(renderer().post(value,binding,scheduleWork=false))
        }
        assertNotEquals(child(first.notificationId).notification.contentIntent,child(second.notificationId).notification.contentIntent)
        venueSummary(8)
    }
    @Test fun tapExactReadExpiryAndGroupDeletePreserveSiblingsAndCannotResurrect() {
        val dm=postDm();val venue=postVenue();val first=media();val second=media("TABLE_JOIN_REQUEST_APPROVED")
        postVenue(first);postVenue(second)
        assertEquals(first.target(),NativePushOpen.target(context,tap(first)))
        eventually("Tap preserves siblings") { children().map {it.tag}.toSet()==setOf(dm,venue,second.notificationId) }
        assertFalse(renderer().post(first,binding,scheduleWork=false))
        PushNotificationState.expireNotification(context,binding,second.notificationId,second.expiresAt,second.expiresAt)
        eventually("Expiry preserves DM and venue") {children().map {it.tag}.toSet()==setOf(dm,venue)}
        assertFalse(renderer().post(second,binding,scheduleWork=false))
        val later=media();postVenue(later)
        PushNotificationState.dismissDelivered(context,PushDeliveredPolicy.DismissRequest(PushDeliveredPolicy.Scope(binding.recipient,binding.epoch),setOf(later.notificationId)))
        eventually("Exact read preserves siblings") {children().map {it.tag}.toSet()==setOf(dm,venue)}
        val captured=media();postVenue(captured);val newest=media();postVenue(newest)
        PushNotificationDismissReceiver().onReceive(context,Intent(PushNotificationGroups.DISMISS_GROUP_ACTION).apply {
            putExtra(PushDeliveredPolicy.RECIPIENT_EXTRA,binding.recipient);putExtra(PushDeliveredPolicy.EPOCH_EXTRA,binding.epoch)
            putStringArrayListExtra(PushNotificationGroups.IDS_EXTRA,arrayListOf(venue,captured.notificationId))
        })
        eventually("Captured delete preserves later arrival") {children().map {it.tag}.toSet()==setOf(dm,newest.notificationId)}
        venueSummary(1);dmSummary()
    }
    @Test fun staleSameAccountEpochDifferentAccountLogoutAndResetNeverNavigateOrMutateCurrentCards() {
        val old=binding;val oldPayload=media();val oldTap=tap(oldPayload)
        binding=bindingFixture(old.recipient);val current=media();postVenue(current)
        assertNull(NativePushOpen.target(context,oldTap))
        assertNull(NativePushOpen.target(context,tap(current,null)))
        assertFalse(renderer().post(oldPayload,old,scheduleWork=false))
        PushNotificationState.dismissGroup(context,old,setOf(current.notificationId))
        assertEquals(setOf(current.notificationId),venueChildren().map {it.tag}.toSet())
        val currentTap=tap(current);binding=bindingFixture()
        assertNull(NativePushOpen.target(context,currentTap))
        PushResetState.setRequired(context,true)
        try { assertNull(NativePushOpen.target(context,tap(media()))) }
        finally {PushResetState.setRequired(context,false)}
        val logoutTap=tap(media());PushNotificationState.bind(context,null)
        assertNull(NativePushOpen.target(context,logoutTap))
    }
    @Test fun foregroundWrongRecipientAndResetDoNotReserveMediaCards() {
        val value=media()
        assertFalse(VenueNotificationRenderer(context){true}.post(value,binding,scheduleWork=false))
        assertFalse(renderer().post(value.copy(recipientId=UUID.randomUUID().toString()),binding,scheduleWork=false))
        PushResetState.setRequired(context,true)
        try {assertFalse(renderer().post(value,binding,scheduleWork=false))} finally {PushResetState.setRequired(context,false)}
        assertFalse(PushNotificationLedger.seen(context,binding.recipient,value.notificationId,System.currentTimeMillis()))
        assertTrue(owned().isEmpty())
    }

    @Test fun receiverRejectsTableTypesForWrongBindingMalformedWireAndReset() {
        for (type in VenuePushPayload.tableTypes) {
            val value = media(type)
            val wire = value.target() + mapOf("presentationVersion" to "ANDROID_TABLE_V1",
                "displayVariant" to if(type == "TABLE_CANCELLED") "OWNER_CANCELLED" else "DEFAULT", "sentAt" to value.sentAt.toString(), "expiresAt" to value.expiresAt.toString())
            assertFalse(renderer().receive(wire + ("recipientId" to UUID.randomUUID().toString())))
            assertFalse(renderer().receive(wire + ("actorId" to binding.recipient)))
            PushResetState.setRequired(context, true)
            try { assertFalse(renderer().receive(wire)) } finally { PushResetState.setRequired(context, false) }
            assertFalse(PushNotificationLedger.seen(context, binding.recipient, value.notificationId, System.currentTimeMillis()))
        }
        assertTrue(owned().isEmpty())
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
