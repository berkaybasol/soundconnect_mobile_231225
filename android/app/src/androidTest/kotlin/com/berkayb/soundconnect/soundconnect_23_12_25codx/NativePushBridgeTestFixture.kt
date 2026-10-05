package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.app.Instrumentation
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.lifecycle.ActivityLifecycleCallback
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.Rule
import org.junit.rules.TestName
import org.junit.runner.RunWith
import java.util.UUID
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Shared real Activity/engine/Dart ownership for the isolated native suites.
 * No test methods: inventory remains explicit in each concrete suite.
 */
abstract class NativePushBridgeTestFixture {
    @get:Rule val testName = TestName()
    protected val instrumentation = InstrumentationRegistry.getInstrumentation()
    protected val context get() = instrumentation.targetContext
    protected var scenario: ActivityHandle? = null
    protected lateinit var binding: PushNotificationState.Binding
    protected lateinit var engine: FlutterEngine
    protected val recipient = UUID.randomUUID().toString()
    private val activityToken = UUID.randomUUID().toString()
    private val engineKey = AudioServicePlugin.getFlutterEngineId()
    private var engineDestroyed = false
    private var stateAcquired = false
    private val selection get() = NativeBridgeEnvironment.argumentNames.associateWith {
        InstrumentationRegistry.getArguments().getString(it)
    }
    private val fixture = NativeBridgeFixture<FlutterEngine>(
        packageName = { context.packageName },
        onMain = { onMain(it) },
        cachedEngine = { FlutterEngineCache.getInstance().get(engineKey) },
        destroyEngine = { if (!engineDestroyed) it.destroy() },
        removeEngine = { FlutterEngineCache.getInstance().remove(engineKey) },
        clearState = {
            check(readStoredRecipient() in setOf("", recipient)) { "Foreign binding retained" }
            PushNotificationState.setResetRequired(context, false)
            // Read durable state, rather than relying only on in-memory capture.
            check(readStoredRecipient().isEmpty()) { "Binding cleanup was not persisted" }
            check(!PushResetState.required(context)) { "Reset latch was not cleared" }
            check(PushNotificationState.currentBinding(context) == null)
        },
    )

    // Instrumentation.runOnMainSync does not marshal a Runnable's exception
    // back to JUnit. Catch on main, rethrow on the test thread so @After runs.
    protected fun onMain(block: () -> Unit) {
        var failure: Throwable? = null
        instrumentation.runOnMainSync {
            try { block() } catch (error: Throwable) { failure = error }
        }
        failure?.let { throw it }
    }

    private fun readStateFile(name: String): JSONObject? {
        val path = File(context.noBackupFilesDir, name)
        // AtomicFile.readFully can recover/rename a backup. Preflight must be
        // read-only and must reject unfinished storage owned by an earlier run.
        check(!File(path.path + ".bak").exists() && !File(path.path + ".new").exists()) {
            "Unfinished isolated state retained: $name"
        }
        return if (path.exists()) JSONObject(path.readText(Charsets.UTF_8)) else null
    }

    private fun readStoredRecipient(): String {
        val json = readStateFile("soundconnect-push-rendering") ?: return ""
        UUID.fromString(json.getString("epoch"))
        return json.getString("recipientId")
    }

    // ActivityScenario compares mutable launch intents. Production intentionally
    // consumes OPEN_PUSH into ACTION_MAIN, so use the real lifecycle monitor.
    protected inner class ActivityHandle(var activity: MainActivity) {
        fun onActivity(block: (MainActivity) -> Unit) = onMain { block(activity) }
        fun recreate() {
            val monitor = Instrumentation.ActivityMonitor(MainActivity::class.java.name, null, false)
            onMain {
                fixture.ownObserver { instrumentation.removeMonitor(monitor) }
                instrumentation.addMonitor(monitor)
            }
            onActivity { it.recreate() }
            val next=monitor.waitForActivityWithTimeout(15000)
            assertNotNull("Actual Android recreated Activity",next)
            assertEquals(activityToken, next!!.intent.getStringExtra("bridge.fixture"))
            onMain { check(fixture.ownsActivity(next)) { "Recreated Activity was not acquired by this test" } }
            activity=next as MainActivity
            instrumentation.waitForIdleSync()
        }
        fun close() {
            onActivity {
                if (!it.isDestroyed) {
                    fixture.checkEngineOwnership()
                    it.finish()
                }
            }
            val until=SystemClock.elapsedRealtime()+10000
            while (!activity.isDestroyed && SystemClock.elapsedRealtime()<until) SystemClock.sleep(50)
            assertTrue("Activity destroyed",activity.isDestroyed)
        }
    }

    @Before fun setup() {
        fixture.setup(preflight = {
            NativeBridgeEnvironment.requireSelected(NativeBridgeEnvironment.Device(
                Build.MANUFACTURER, Build.MODEL, Build.FINGERPRINT, Build.HARDWARE), selection)
            check(instrumentation.context.packageName == NativeBridgeFixture.PACKAGE + ".test")
            check(context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0)
            @Suppress("DEPRECATION")
            val info = context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
            check(info.metaData.getString("com.soundconnect.bridge_harness") ==
                "integration_test/native_push_bridge_harness.dart") { "Verified harness build required" }
            @Suppress("DEPRECATION")
            check(context.packageManager.getPackageInfo(context.packageName, 0).sharedUserId == null)
            @Suppress("DEPRECATION")
            check(context.packageManager.getPackageInfo(instrumentation.context.packageName, 0).sharedUserId == null)
            check(PushFeatureGate.enabled(context)) { "Harness must use the real enabled push gate" }
            check(context.getSystemService(NotificationManager::class.java).activeNotifications.isEmpty()) {
                "Preexisting isolated notification cards retained"
            }
            val reset = readStateFile("soundconnect-push-reset")
            check(readStoredRecipient().isEmpty() && (reset == null || reset.get("required") == false)) {
                "Nonempty isolated state retained"
            }
            val lifecycle = ActivityLifecycleMonitorRegistry.getInstance()
            check(Stage.values().filter { it != Stage.DESTROYED }.all {
                lifecycle.getActivitiesInStage(it).isEmpty()
            }) { "Preexisting Activity is not owned by this test" }
        }, initializeState = {
            stateAcquired = true
            PushNotificationState.setResetRequired(context, false)
            PushNotificationState.bind(context, recipient)
            binding = PushNotificationState.capture(context, recipient)!!
        })
        onMain {
            val lifecycle = ActivityLifecycleMonitorRegistry.getInstance()
            var observing = true
            val callback = ActivityLifecycleCallback { activity, stage ->
                if (observing && stage == Stage.PRE_ON_CREATE && activity is MainActivity &&
                    activity.intent.getStringExtra("bridge.fixture") == activityToken) {
                    fixture.ownActivity(activity) { ActivityHandle(activity).close() }
                }
            }
            fixture.ownObserver {
                observing = false
                lifecycle.removeLifecycleCallback(callback)
            }
            lifecycle.addLifecycleCallback(callback)
        }
    }
    protected open fun cleanupOwnedCards() = Unit

    @After fun teardown() {
        val failures = mutableListOf<Throwable>()
        if (stateAcquired) try { cleanupOwnedCards() } catch (error: Throwable) { failures.add(error) }
        try { fixture.cleanup() } catch (error: Throwable) { failures.add(error) }
        org.junit.runners.model.MultipleFailureException.assertEmpty(failures)
        // Never read or mutate unrelated runtime after a rejected setup.
        if (!stateAcquired) return
        onMain {
            check(FlutterEngineCache.getInstance().get(engineKey) == null) { "Engine cache not empty after cleanup" }
            check(!::engine.isInitialized || engineDestroyed) { "Owned engine did not report destruction" }
            check(Stage.values().filter { it != Stage.DESTROYED }.all {
                ActivityLifecycleMonitorRegistry.getInstance().getActivitiesInStage(it).isEmpty()
            }) { "Activity retained after cleanup" }
            check(context.getSystemService(NotificationManager::class.java).activeNotifications.isEmpty())
            check(readStoredRecipient().isEmpty())
            val reset = readStateFile("soundconnect-push-reset")
            check(reset == null || reset.get("required") == false) { "Durable reset not clear" }
        }
        instrumentation.sendStatus(2, Bundle().apply {
            putString("bridgeCleanup", "${selection["bridgeRunId"] ?: "emulator"}:${testName.methodName}:empty")
        })
    }
    protected fun tap(type: String = "SOCIAL_LIKE", epoch: String? = binding.epoch) = Intent(context, MainActivity::class.java).apply {
        putExtra("bridge.fixture", activityToken)
        action = PushOpenTarget.NOTIFICATION_ACTION
        putExtra("sc.push.notificationId", UUID.randomUUID().toString())
        putExtra("sc.push.recipientId", binding.recipient)
        putExtra("sc.push.type", type)
        if (type == "DM_NEW_MESSAGE") putExtra("sc.push.conversationId", UUID.randomUUID().toString())
        if (epoch != null) putExtra(PushDeliveredPolicy.EPOCH_EXTRA, epoch)
    }
    protected fun launch(intent: Intent = Intent(context, MainActivity::class.java)) {
        engine = fixture.acquireEngine(
            create = { FlutterEngine(context, null, false) },
            initialize = { owned ->
                owned.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
                    override fun onPreEngineRestart() = Unit
                    override fun onEngineWillDestroy() { engineDestroyed = true }
                })
                // Same engine/plugin/route/Dart startup used by audio_service,
                // with ownership captured before any of those steps can fail.
                GeneratedPluginRegistrant.registerWith(owned)
                check(owned.plugins.has(AudioServicePlugin::class.java)) { "Audio service plugin registration failed" }
                check(AudioServicePlugin.getFlutterEngineId() == engineKey) { "Audio engine key changed" }
                check(FlutterEngineCache.getInstance().get(engineKey) == null)
                FlutterEngineCache.getInstance().put(engineKey, owned)
                owned.navigationChannel.setInitialRoute("/")
                owned.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
            },
        )
        intent.putExtra("bridge.fixture", activityToken)
        val activity = instrumentation.startActivitySync(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as MainActivity
        scenario = ActivityHandle(activity)
        scenario!!.onActivity {
            check(fixture.ownsActivity(it)) { "Launched Activity was not acquired by this test" }
            assertSame(engine, it.provideFlutterEngine(it))
        }
        // The actual Dart peer may take time to register its channel.
        val until = SystemClock.elapsedRealtime() + 15000
        while (true) {
            try { dart("events"); return } catch (e: AssertionError) {
                if (SystemClock.elapsedRealtime() >= until) throw e
                SystemClock.sleep(100)
            }
        }
    }
    protected fun dart(method: String): Any? {
        val latch = CountDownLatch(1); var value: Any? = null; var failure: String? = null
        onMain {
            MethodChannel(engine.dartExecutor.binaryMessenger, "com.soundconnect/bridge_test")
                .invokeMethod(method, null, object: MethodChannel.Result {
                    override fun success(result: Any?) { value=result; latch.countDown() }
                    override fun error(code: String, message: String?, details: Any?) { failure=code; latch.countDown() }
                    override fun notImplemented() { failure="Dart harness unavailable"; latch.countDown() }
                })
        }
        assertTrue("Dart reply timeout: $method", latch.await(10, TimeUnit.SECONDS))
        assertNull(failure, failure); return value
    }
    protected fun events(): List<*> = dart("events") as List<*>
    protected fun expectEvent(intent: Intent) {
        // Query shares the platform messenger's ordered queue with opened.
        val values=events()
        assertEquals("exact opened delivery",1,values.size)
        assertEquals(intent.getStringExtra("sc.push.notificationId"), (values.single() as Map<*,*>)["notificationId"])
    }
}
