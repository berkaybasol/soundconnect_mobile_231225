package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.Intent
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Real Activity/FlutterEngine/MethodChannel/Dart; synthetic taps, no API/FCM.
 * Build ONLY with native_push_bridge_harness.dart and isolated .warmtest ID.
 */
@RunWith(AndroidJUnit4::class)
class NativePushBridgeLifecycleTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private var scenario: ActivityHandle? = null
    private lateinit var binding: PushNotificationState.Binding
    private lateinit var engine: FlutterEngine

    // ActivityScenario compares mutable launch intents. Production intentionally
    // consumes OPEN_PUSH into ACTION_MAIN, so use the real lifecycle monitor.
    private inner class ActivityHandle(var activity: MainActivity) {
        fun onActivity(block: (MainActivity) -> Unit) = instrumentation.runOnMainSync { block(activity) }
        fun recreate() {
            val monitor=instrumentation.addMonitor(MainActivity::class.java.name, null, false)
            onActivity { it.recreate() }
            val next=monitor.waitForActivityWithTimeout(15000)
            instrumentation.removeMonitor(monitor)
            assertNotNull("Actual Android recreated Activity",next)
            activity=next as MainActivity
            instrumentation.waitForIdleSync()
        }
        fun close() {
            onActivity { it.finish() }
            val until=SystemClock.elapsedRealtime()+10000
            while (!activity.isDestroyed && SystemClock.elapsedRealtime()<until) SystemClock.sleep(50)
            assertTrue("Activity destroyed",activity.isDestroyed)
        }
    }

    @Before fun setup() {
        check(context.packageName == "tr.com.soundconnect.app.warmtest") { "Isolated harness package only" }
        instrumentation.runOnMainSync {
            PushNotificationState.setResetRequired(context, false)
            val recipient = UUID.randomUUID().toString()
            PushNotificationState.bind(context, recipient)
            binding = PushNotificationState.capture(context, recipient)!!
        }
    }
    @After fun teardown() {
        scenario?.close()
        instrumentation.runOnMainSync {
            val key = AudioServicePlugin.getFlutterEngineId()
            FlutterEngineCache.getInstance().get(key)?.destroy()
            FlutterEngineCache.getInstance().remove(key)
            PushNotificationState.bind(context, null)
        }
    }
    private fun tap(type: String = "SOCIAL_LIKE", epoch: String = binding.epoch) = Intent(context, MainActivity::class.java).apply {
        action = PushOpenTarget.NOTIFICATION_ACTION
        putExtra("sc.push.notificationId", UUID.randomUUID().toString())
        putExtra("sc.push.recipientId", binding.recipient)
        putExtra("sc.push.type", type)
        putExtra(PushDeliveredPolicy.EPOCH_EXTRA, epoch)
    }
    private fun launch(intent: Intent = Intent(context, MainActivity::class.java)) {
        scenario = ActivityHandle(instrumentation.startActivitySync(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as MainActivity)
        scenario!!.onActivity { engine = it.provideFlutterEngine(it)!! }
        // The actual Dart peer may take time to register its channel.
        val until = SystemClock.elapsedRealtime() + 15000
        while (true) {
            try { dart("events"); return } catch (e: AssertionError) {
                if (SystemClock.elapsedRealtime() >= until) throw e
                SystemClock.sleep(100)
            }
        }
    }
    private fun dart(method: String): Any? {
        val latch = CountDownLatch(1); var value: Any? = null; var failure: String? = null
        instrumentation.runOnMainSync {
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
    private fun events(): List<*> = dart("events") as List<*>
    private fun expectEvent(intent: Intent) {
        // Query shares the platform messenger's ordered queue with opened.
        val values=events()
        assertEquals("exact opened delivery",1,values.size)
        assertEquals(intent.getStringExtra("sc.push.notificationId"), (values.single() as Map<*,*>)["notificationId"])
    }
    @Test fun coldWaitsForDartInitialHandshakeAndConsumesOnce() {
        val intent=tap(); val id=intent.getStringExtra("sc.push.notificationId")
        launch(intent); assertTrue(events().isEmpty())
        assertEquals(id,(dart("initial") as Map<*,*>)["notificationId"])
        assertNull(dart("initial")); assertTrue(events().isEmpty())
    }
    @Test fun normalWarmOnNewIntentReachesActualDart() {
        launch(); assertNull(dart("initial")); val intent=tap(); val copy=Intent(intent)
        scenario!!.onActivity { instrumentation.callActivityOnNewIntent(it, intent) }; expectEvent(copy)
    }
    @Test fun staleEpochDoesNotReachDart() {
        launch(); dart("initial")
        scenario!!.onActivity { instrumentation.callActivityOnNewIntent(it, tap(epoch=UUID.randomUUID().toString())) }
        assertTrue(events().isEmpty())
    }
    @Test fun sameLiveEngineRecreatedActivityWarmIntentReachesDart() {
        launch(); dart("initial"); var old: MainActivity?=null
        scenario!!.onActivity { old=it }; scenario!!.recreate()
        scenario!!.onActivity { assertNotSame(old,it); assertSame(engine,it.provideFlutterEngine(it)) }
        val intent=tap(); val copy=Intent(intent)
        scenario!!.onActivity { instrumentation.callActivityOnNewIntent(it, intent) }; expectEvent(copy)
    }
    @Test fun sameLiveEngineRecreatedActivityLaunchIntentReachesDart() {
        launch(); dart("initial"); val intent=tap(); val copy=Intent(intent)
        scenario!!.onActivity { it.intent=intent }; scenario!!.recreate()
        scenario!!.onActivity { assertSame(engine,it.provideFlutterEngine(it)) }; expectEvent(copy)
    }

    @Test fun delayedDartHandshakeSurvivesRecreationWithOnlyOnePending() {
        launch(); val first=tap(); val second=tap("SOCIAL_COMMENT")
        val id=second.getStringExtra("sc.push.notificationId")
        scenario!!.onActivity {
            instrumentation.callActivityOnNewIntent(it, first)
            instrumentation.callActivityOnNewIntent(it, second)
        }
        assertTrue(events().isEmpty()); scenario!!.recreate()
        assertEquals(id,(dart("initial") as Map<*,*>)["notificationId"])
        assertNull(dart("initial")); assertTrue(events().isEmpty())
    }

    @Test fun delayedTargetIsRejectedAfterLogoutAndSameRecipientNewEpoch() {
        launch()
        scenario!!.onActivity {
            instrumentation.callActivityOnNewIntent(it,tap())
            PushNotificationState.bind(context,null)
            PushNotificationState.bind(context,binding.recipient)
        }
        assertNull(dart("initial")); assertTrue(events().isEmpty())
    }

    @Test fun delayedTargetIsRejectedWhileResetLatchIsSet() {
        launch()
        scenario!!.onActivity {
            instrumentation.callActivityOnNewIntent(it,tap())
            PushNotificationState.setResetRequired(context,true)
        }
        assertNull(dart("initial")); assertTrue(events().isEmpty())
    }

    @Test fun consumedIntentCannotRepeatAndSecondDistinctTargetStillArrives() {
        launch();dart("initial");val first=tap();val second=tap("SOCIAL_COMMENT")
        val ids=listOf(first,second).map { it.getStringExtra("sc.push.notificationId") }
        scenario!!.onActivity {
            instrumentation.callActivityOnNewIntent(it,first)
            instrumentation.callActivityOnNewIntent(it,first)
            instrumentation.callActivityOnNewIntent(it,second)
        }
        assertEquals(ids,events().map { (it as Map<*,*>)["notificationId"] })
    }

    @Test fun retiredActivityCannotFeedReattachedEngine() {
        launch();dart("initial");var old: MainActivity?=null
        scenario!!.onActivity { old=it };scenario!!.recreate()
        instrumentation.runOnMainSync { instrumentation.callActivityOnNewIntent(old!!,tap()) }
        assertTrue(events().isEmpty())
        val intent=tap();val copy=Intent(intent)
        scenario!!.onActivity { instrumentation.callActivityOnNewIntent(it,intent) };expectEvent(copy)
    }
}
