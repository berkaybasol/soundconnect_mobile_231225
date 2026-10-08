package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.Context
import android.content.ContextWrapper
import android.database.sqlite.SQLiteDatabase
import android.util.AtomicFile
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Uses a random isolated subdirectory in target UID's no-backup storage, never the app's
 * real binding/ledger. No activities, Firebase, network or OS notifications.
 * Binding fixtures exercise AtomicFile capture/post without invoking bind(),
 * since bind() intentionally clears the application's visible notifications.
 */
@Suppress("DEPRECATION")
@RunWith(AndroidJUnit4::class)
class PushNotificationLedgerInstrumentationTest {
    private lateinit var base: Context
    private lateinit var parent: File
    private lateinit var directory: File
    private lateinit var context: Context
    private val recipient = "10000000-0000-4000-8000-000000000001"
    private val otherRecipient = "10000000-0000-4000-8000-000000000002"
    private val notification = "20000000-0000-4000-8000-000000000001"

    @Before fun isolateStorage() {
        base = InstrumentationRegistry.getInstrumentation().targetContext
        parent = File(base.noBackupFilesDir, "push-ledger-tests")
        directory = File(parent, UUID.randomUUID().toString())
        assertTrue(directory.mkdirs())
        context = isolatedContext()
    }

    private fun isolatedContext(): Context = object : ContextWrapper(base) {
        override fun getNoBackupFilesDir(): File = directory
        override fun getSystemService(name: String): Any? {
            check(name != Context.NOTIFICATION_SERVICE) { "Ledger tests must not access real notifications" }
            return super.getSystemService(name)
        }
    }

    @After fun removeOnlyIsolatedStorage() {
        check(directory.canonicalPath.startsWith(parent.canonicalPath + File.separator))
        check(directory.parentFile.canonicalFile == parent.canonicalFile)
        assertTrue(directory.deleteRecursively())
    }

    private fun bindingFixture(user: String = recipient, epoch: String = UUID.randomUUID().toString()): PushNotificationState.Binding {
        val storage = AtomicFile(File(directory, "soundconnect-push-rendering"))
        val stream = storage.startWrite()
        try {
            stream.write(JSONObject().put("recipientId", user).put("epoch", epoch).toString().toByteArray(Charsets.UTF_8))
            storage.finishWrite(stream)
        } catch (error: Exception) {
            storage.failWrite(stream)
            throw error
        }
        return PushNotificationState.Binding(user, epoch)
    }

    @Test fun sqliteReopenKeepsRecipientSpecificDeliveryKeys() {
        val now = System.currentTimeMillis()
        assertTrue(PushNotificationLedger.reserve(context, recipient, notification, now + 60_000, now))
        assertTrue(File(directory, "soundconnect-push-deliveries.sqlite").isFile)
        val reopened = isolatedContext()
        assertTrue(PushNotificationLedger.seen(reopened, recipient, notification, now))
        assertFalse(PushNotificationLedger.reserve(reopened, recipient, notification, now + 60_000, now))
        assertTrue(PushNotificationLedger.reserve(reopened, otherRecipient, notification, now + 60_000, now))
    }

    @Test fun sqlitePrunesOnlyExpiredEntriesAndHasExpiryIndex() {
        val now = System.currentTimeMillis()
        val liveId = UUID.randomUUID().toString()
        assertTrue(PushNotificationLedger.reserve(context, recipient, notification, now + 100, now))
        assertTrue(PushNotificationLedger.reserve(context, recipient, liveId, now + 60_000, now))
        assertTrue(PushNotificationLedger.reserve(context, recipient, UUID.randomUUID().toString(), now + 60_000, now + 100))
        assertFalse(PushNotificationLedger.seen(context, recipient, notification, now + 100))
        assertTrue(PushNotificationLedger.seen(context, recipient, liveId, now + 100))
        openIsolatedDatabase().use { database ->
            database.rawQuery("SELECT COUNT(*) FROM deliveries", null).use { cursor ->
                assertTrue(cursor.moveToFirst()); assertEquals(2, cursor.getInt(0))
            }
            database.rawQuery("SELECT 1 FROM sqlite_master WHERE type='index' AND name='deliveries_expiry'", null).use {
                assertTrue(it.moveToFirst())
            }
        }
    }

    @Test fun fullSqliteLedgerRejectsExtraPostsWithoutEvictingOldKeys() {
        val now = System.currentTimeMillis()
        assertTrue(PushNotificationLedger.reserve(context, recipient, notification, now + 60_000, now))
        openIsolatedDatabase().use { database ->
            database.beginTransaction()
            try {
                database.compileStatement("INSERT INTO deliveries(recipient_id,notification_id,expires_at) VALUES(?,?,?)").use { statement ->
                    for (index in 1 until PushNotificationLedgerPolicy.MAX_ENTRIES.toInt()) {
                        statement.bindString(1, recipient)
                        statement.bindString(2, "30000000-0000-4000-8000-${index.toString().padStart(12, '0')}")
                        statement.bindLong(3, now + 60_000)
                        statement.executeInsert()
                    }
                }
                database.setTransactionSuccessful()
            } finally { database.endTransaction() }
        }
        assertFalse(PushNotificationLedger.reserve(context, otherRecipient, UUID.randomUUID().toString(), now + 60_000, now))
        assertTrue(PushNotificationLedger.seen(context, recipient, notification, now))
        openIsolatedDatabase().use { database ->
            database.rawQuery("SELECT COUNT(*) FROM deliveries", null).use { cursor ->
                assertTrue(cursor.moveToFirst()); assertEquals(PushNotificationLedgerPolicy.MAX_ENTRIES, cursor.getLong(0))
            }
        }
    }

    @Test fun newPersistedLoginEpochRejectsOldWorkAndPreservesSeenKeys() {
        val oldBinding = bindingFixture()
        val expiresAt = System.currentTimeMillis() + 60_000
        var actions = 0
        assertTrue(PushNotificationState.postInitial(context, oldBinding, notification, expiresAt) { actions++; true })
        // Serialized null binding followed by same-account login has a new epoch.
        bindingFixture(user = "")
        assertNull(PushNotificationState.capture(context, recipient))
        val newBinding = bindingFixture()
        assertEquals(newBinding, PushNotificationState.capture(isolatedContext(), recipient))
        assertFalse(PushNotificationState.post(context, oldBinding) { actions++; true })
        assertFalse(PushNotificationState.postInitial(context, newBinding, notification, expiresAt) { actions++; true })
        assertTrue(PushNotificationState.postInitial(context, newBinding, UUID.randomUUID().toString(), expiresAt) { actions++; true })
        assertEquals(2, actions)
    }

    @Test fun concurrentInitialCallbacksReserveAndRunOnlyOnce() {
        val binding = bindingFixture()
        val expiresAt = System.currentTimeMillis() + 60_000
        val actions = AtomicInteger()
        val workers = Executors.newFixedThreadPool(4)
        try {
            val futures = (1..16).map {
                workers.submit(Callable {
                    PushNotificationState.postInitial(context, binding, notification, expiresAt) { actions.incrementAndGet(); true }
                })
            }
            assertEquals(1, futures.count { it.get(10, TimeUnit.SECONDS) })
            assertEquals(1, actions.get())
        } finally { workers.shutdownNow() }
    }

    @Test fun failureAfterDurableReservationDoesNotReplayInitialPost() {
        val binding = bindingFixture()
        val expiresAt = System.currentTimeMillis() + 60_000
        assertFalse(PushNotificationState.postInitial(context, binding, notification, expiresAt) { throw IllegalStateException("simulated renderer interruption") })
        var repeated = false
        assertFalse(PushNotificationState.postInitial(isolatedContext(), binding, notification, expiresAt) { repeated = true; true })
        assertFalse(repeated)
        assertTrue(PushNotificationState.seen(context, binding, notification))
    }

    @Test fun staleDismissNeverQueriesRealNotificationsAfterSameAccountRelogin() {
        val old = bindingFixture()
        val request = PushDeliveredPolicy.DismissRequest(
            PushDeliveredPolicy.Scope(old.recipient, old.epoch), setOf(notification))
        val newBinding = bindingFixture()
        // This isolated Context throws on any NotificationManager access.
        PushNotificationState.dismissDelivered(context, request)
        assertEquals(newBinding, PushNotificationState.currentBinding(context))
        bindingFixture(user = "")
        PushNotificationState.dismissDelivered(context, request)
        assertNull(PushNotificationState.currentBinding(context))
    }

    @Test fun anotherAccountCannotObtainDeliveredSnapshotOrReadOsNotifications() {
        val binding = bindingFixture()
        assertNull(PushNotificationState.deliveredSnapshot(context, otherRecipient))
        assertEquals(binding, PushNotificationState.currentBinding(context))
    }

    @Test fun dismissedReservationSurvivesReopenAndBlocksAvatarEvenWhenOsStillLooksActive() {
        val binding = bindingFixture()
        val now = System.currentTimeMillis()
        val otherId = UUID.randomUUID().toString()
        assertTrue(PushNotificationState.postInitial(context, binding, notification, now + 60_000) { true })
        assertTrue(PushNotificationState.postInitial(context, binding, otherId, now + 60_000) { true })
        assertTrue(PushNotificationState.post(context, binding, notification) { true })
        PushNotificationLedger.markDismissed(context, recipient, setOf(notification, UUID.randomUUID().toString()))
        PushNotificationLedger.markDismissed(context, recipient, setOf(notification))
        var reposted = false
        assertFalse(PushNotificationState.post(isolatedContext(), binding, notification) { reposted = true; true })
        assertFalse(reposted)
        assertTrue(PushNotificationState.post(context, binding, otherId) { true })
        assertTrue(PushNotificationLedger.seen(context, recipient, notification, now))
        assertFalse(PushNotificationLedger.reserve(context, recipient, notification, now + 60_000, now))
        assertFalse(PushNotificationLedger.mayUpdate(context, otherRecipient, notification, now))
        openIsolatedDatabase().use { database ->
            assertEquals(1L, android.database.DatabaseUtils.queryNumEntries(database, "dismissed_deliveries"))
            assertEquals(2L, android.database.DatabaseUtils.queryNumEntries(database, "deliveries"))
        }
    }

    @Test fun dismissedRowsExpireWithTheirReservationsAndStorageFailureNeverRunsAvatarAction() {
        val binding = bindingFixture()
        val now = System.currentTimeMillis()
        assertTrue(PushNotificationLedger.reserve(context, recipient, notification, now + 100, now))
        PushNotificationLedger.markDismissed(context, recipient, setOf(notification))
        assertTrue(PushNotificationLedger.reserve(context, recipient, UUID.randomUUID().toString(), now + 60_000, now + 100))
        openIsolatedDatabase().use { database ->
            assertEquals(0L, android.database.DatabaseUtils.queryNumEntries(database, "dismissed_deliveries"))
            database.execSQL("DROP TABLE dismissed_deliveries")
            database.execSQL("CREATE VIEW dismissed_deliveries AS SELECT recipient_id,notification_id,expires_at FROM deliveries")
        }
        // Creating the required index on a view fails: fail closed, with no OS access.
        var reposted = false
        assertFalse(PushNotificationState.post(context, binding, notification) { reposted = true; true })
        assertFalse(reposted)
        try {
            PushNotificationLedger.markDismissed(context, recipient, setOf(notification))
            fail("Storage failure must be propagated before any cancellation")
        } catch (_: android.database.sqlite.SQLiteException) { }
    }

    @Test fun nativeResetLatchSurvivesReopenAndSuppressesOldBindingAndAvatarPosts() {
        val binding = bindingFixture()
        val expiresAt = System.currentTimeMillis() + 60_000
        assertFalse("Existing installs migrate without a reset", PushResetState.required(context))
        assertTrue(PushNotificationState.postInitial(context, binding, notification, expiresAt) { true })
        PushResetState.setRequired(context, true)
        val reopened = isolatedContext()
        assertTrue(PushResetState.required(reopened))
        assertNull(PushNotificationState.capture(reopened, binding.recipient))
        assertNull(PushNotificationState.currentBinding(reopened))
        assertFalse(PushNotificationState.post(reopened, binding, notification) { fail("Reset blocks avatar delivery"); true })
        assertFalse(PushNotificationState.postInitial(reopened, binding, UUID.randomUUID().toString(), expiresAt) {
            fail("Reset blocks old-account initial delivery"); true
        })
        PushResetState.setRequired(reopened, false)
        assertFalse(PushResetState.required(context))
        assertEquals(binding, PushNotificationState.currentBinding(context))
    }

    @Test fun corruptResetLatchFailsClosedInsteadOfLookingLikeALegacyInstall() {
        val binding = bindingFixture()
        File(directory, "soundconnect-push-reset").writeText("{\"required\":\"false\"}")
        try { PushResetState.required(context); fail("A string is not a stored Boolean") }
        catch (_: java.io.IOException) { }
        assertTrue(PushResetState.blocksRendering(context))
        assertNull(PushNotificationState.capture(context, binding.recipient))
        assertNull(PushNotificationState.currentBinding(context))
        PushResetState.setRequired(context, true)
        assertTrue(PushResetState.required(context))
    }

    @Test fun interruptedFirstResetWriteAndUnreadableStorageCannotAuthorizeRendering() {
        bindingFixture()
        File(directory, "soundconnect-push-reset.new").writeText("{\"required\":true}")
        assertTrue(PushResetState.blocksRendering(context))
        val fileAsDirectory = File(directory, "not-a-directory").apply { writeText("fixture") }
        val unavailable = object : ContextWrapper(context) {
            override fun getNoBackupFilesDir(): File = fileAsDirectory
        }
        assertTrue(PushResetState.blocksRendering(unavailable))
    }

    @Test fun clearingNativeResetLatchRequiresSuccessfulBindingCleanup() {
        bindingFixture()
        // This fixture denies NotificationManager operations to reproduce a
        // native cleanup failure after the independent reset marker is persisted.
        try { PushNotificationState.setResetRequired(context, true); fail("Fixture denies cleanup") }
        catch (_: IllegalStateException) { }
        assertTrue(PushResetState.required(context))
        try { PushNotificationState.setResetRequired(context, false); fail("Fixture still denies cleanup") }
        catch (_: IllegalStateException) { }
        assertTrue("Failed native cleanup must leave the reset fence set", PushResetState.required(context))
        assertNull(PushNotificationState.currentBinding(context))
    }

    @Test fun groupRepairRetriesUnavailableStorageWithABoundedAttemptBudget() {
        val binding = bindingFixture()
        // This Context deliberately denies NotificationManager access. The worker
        // treats unavailable native state as unconfirmed, without posting anything.
        assertTrue(PushGroupReconcileWorker.reconcile(context, binding.recipient, binding.epoch, 0)
            is androidx.work.ListenableWorker.Result.Retry)
        assertTrue(PushGroupReconcileWorker.reconcile(context, binding.recipient, binding.epoch, 3)
            is androidx.work.ListenableWorker.Result.Success)
        assertTrue(PushGroupReconcileWorker.reconcile(context, binding.recipient, binding.epoch, 0, stopped = true)
            is androidx.work.ListenableWorker.Result.Success)
    }

    private fun openIsolatedDatabase(): SQLiteDatabase = SQLiteDatabase.openDatabase(
        File(directory, "soundconnect-push-deliveries.sqlite").absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
}
