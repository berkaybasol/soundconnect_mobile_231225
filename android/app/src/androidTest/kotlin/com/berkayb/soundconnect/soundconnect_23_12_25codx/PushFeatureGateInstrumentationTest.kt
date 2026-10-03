package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.ComponentName
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.content.res.Resources
import android.util.AtomicFile
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

/** Isolated upgrade fixtures; never read tokens, start Firebase, or touch real OS cards. */
@Suppress("DEPRECATION")
@RunWith(AndroidJUnit4::class)
class PushFeatureGateInstrumentationTest {
    private lateinit var base: Context
    private lateinit var parent: File
    private lateinit var directory: File
    private val recipient = "10000000-0000-4000-8000-000000000001"
    private val notification = "20000000-0000-4000-8000-000000000001"

    @Before fun isolateStorage() {
        base = InstrumentationRegistry.getInstrumentation().targetContext
        parent = File(base.noBackupFilesDir, "push-feature-gate-tests")
        directory = File(parent, UUID.randomUUID().toString())
        assertTrue(directory.mkdirs())
    }

    private fun context(enabled: Boolean): Context {
        val resources = object : Resources(base.resources.assets,
            base.resources.displayMetrics, base.resources.configuration) {
            override fun getBoolean(id: Int): Boolean =
                if (id == R.bool.soundconnect_push_enabled) enabled else super.getBoolean(id)
        }
        return object : ContextWrapper(base) {
            override fun getResources(): Resources = resources
            override fun getNoBackupFilesDir(): File = directory
            override fun getSystemService(name: String): Any? {
                check(name != Context.NOTIFICATION_SERVICE) { "Fixture must not access real OS cards" }
                return super.getSystemService(name)
            }
        }
    }

    private fun bindingFixture(): PushNotificationState.Binding {
        val binding = PushNotificationState.Binding(recipient, UUID.randomUUID().toString())
        val storage = AtomicFile(File(directory, "soundconnect-push-rendering"))
        val stream = storage.startWrite()
        try {
            stream.write(JSONObject().put("recipientId", binding.recipient).put("epoch", binding.epoch)
                .toString().toByteArray(Charsets.UTF_8))
            storage.finishWrite(stream)
        } catch (error: Exception) { storage.failWrite(stream); throw error }
        return binding
    }

    @After fun removeOnlyIsolatedStorage() {
        check(directory.canonicalPath.startsWith(parent.canonicalPath + File.separator))
        check(directory.parentFile.canonicalFile == parent.canonicalFile)
        assertTrue(directory.deleteRecursively())
    }

    @Test fun mergedManifestIncomingRoutesMatchNativeBuildOptIn() {
        val expected = PushFeatureGate.enabled(base)
        val flags = PackageManager.MATCH_DISABLED_COMPONENTS
        listOf("com.google.firebase.iid.FirebaseInstanceIdReceiver",
            "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingReceiver").forEach { name ->
            assertEquals(name, expected,
                base.packageManager.getReceiverInfo(ComponentName(base.packageName, name), flags).enabled)
        }
        listOf(SoundconnectMessagingService::class.java.name,
            "com.google.firebase.messaging.FirebaseMessagingService",
            "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingBackgroundService").forEach { name ->
            assertEquals(name, expected,
                base.packageManager.getServiceInfo(ComponentName(base.packageName, name), flags).enabled)
        }
    }

    @Test fun disabledUpgradeCannotCaptureOldOwnerOrPostQueuedWork() {
        val binding = bindingFixture()
        val enabled = context(true)
        val disabled = context(false)
        assertEquals(binding, PushNotificationState.capture(enabled, recipient))
        var posts = 0
        assertNull(PushNotificationState.capture(disabled, recipient))
        assertNull(PushNotificationState.currentBinding(disabled))
        assertFalse(PushNotificationState.post(disabled, binding) { posts++; true })
        assertFalse(PushNotificationState.postInitial(disabled, binding, notification,
            System.currentTimeMillis() + 60_000) { posts++; true })
        assertNull(PushNotificationState.deliveredSnapshot(disabled, recipient))
        assertEquals(0, posts)
        assertFalse(File(directory, "soundconnect-push-deliveries.sqlite").exists())
    }

    @Test fun disabledLaunchClearsOldOwnerBeforeNotificationCleanupFailure() {
        val binding = bindingFixture()
        // Fixture deliberately rejects OS access, modelling a cleanup failure.
        // The account fence must still be durably empty for a later enabled APK.
        PushFeatureGate.onAppLaunch(context(false))
        val saved = JSONObject(File(directory, "soundconnect-push-rendering").readText())
        assertEquals("", saved.getString("recipientId"))
        assertNotEquals(binding.epoch, saved.getString("epoch"))
        assertNull(PushNotificationState.currentBinding(context(true)))
        assertFalse(PushNotificationState.current(context(true), binding))
    }

    @Test fun disabledNativeBindCannotPersistARecipient() {
        val binding = bindingFixture()
        try {
            PushNotificationState.bind(context(false), recipient)
            fail("Isolated fixture must reject notification cleanup")
        } catch (_: IllegalStateException) { }
        val saved = JSONObject(File(directory, "soundconnect-push-rendering").readText())
        assertEquals("", saved.getString("recipientId"))
        assertNotEquals(binding.epoch, saved.getString("epoch"))
        assertNull(PushNotificationState.currentBinding(context(true)))
    }

    @Test fun enabledLaunchPreservesExistingBackgroundBinding() {
        val binding = bindingFixture()
        PushFeatureGate.onAppLaunch(context(true))
        assertEquals(binding, PushNotificationState.capture(context(true), recipient))
        assertTrue(PushNotificationState.post(context(true), binding) { true })
    }
}
