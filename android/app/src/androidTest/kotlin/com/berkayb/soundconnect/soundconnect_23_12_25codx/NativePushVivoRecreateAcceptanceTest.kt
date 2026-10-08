package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.Intent
import android.os.Build
import android.os.Process
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Explicit physical acceptance controller, in the test APK only. No fake tap,
 * target, login, API, notification, or product control channel is provided.
 */
@RunWith(AndroidJUnit4::class)
class NativePushVivoRecreateAcceptanceTest {
    @Test fun controlledRecreateThenWaitForRealUserTap() {
        check(InstrumentationRegistry.getArguments().getString("physicalRecreate") == "true")
        val instrumentation=InstrumentationRegistry.getInstrumentation()
        val context=instrumentation.targetContext
        check(context.packageName == "tr.com.soundconnect.app" && Build.MODEL == "V2206")
        val ready=File(context.cacheDir,"warm-vivo-ready.json")
        val trigger=File(context.cacheDir,"warm-vivo-recreate")
        val stop=File(context.cacheDir,"warm-vivo-stop")
        check(!ready.exists() && !trigger.exists() && !stop.exists())
        val activity=instrumentation.startActivitySync(Intent(context,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as MainActivity
        val engine=activity.provideFlutterEngine(activity)!!
        var isReady=false
        val until=SystemClock.elapsedRealtime()+30000
        while (!isReady && SystemClock.elapsedRealtime()<until) {
            instrumentation.runOnMainSync {
                val bridge=engine.plugins.get(NativePushDeliveryPlugin::class.java)!!
                val field=NativePushDeliveryPlugin::class.java.getDeclaredField("ready").apply { isAccessible=true }
                isReady=field.getBoolean(bridge)
            }
            SystemClock.sleep(100)
        }
        assertTrue("Real product Dart initial handshake",isReady)
        val record=JSONObject().put("pid",Process.myPid()).put("engine",System.identityHashCode(engine))
            .put("activityBefore",System.identityHashCode(activity)).put("stage","waiting-for-recreate")
        ready.writeText(record.toString())
        val deadline=SystemClock.elapsedRealtime()+300000
        while (!trigger.exists() && SystemClock.elapsedRealtime()<deadline) SystemClock.sleep(200)
        assertTrue("Explicit host recreate trigger",trigger.exists())
        val monitor=instrumentation.addMonitor(MainActivity::class.java.name,null,false)
        instrumentation.runOnMainSync { activity.recreate() }
        val next=monitor.waitForActivityWithTimeout(15000) as? MainActivity
        instrumentation.removeMonitor(monitor)
        assertNotNull(next);assertNotSame(activity,next)
        instrumentation.runOnMainSync { assertSame(engine,next!!.provideFlutterEngine(next)) }
        record.put("stage","recreated-awaiting-real-FCM-tap").put("activityAfter",System.identityHashCode(next))
            .put("sameEngine",true).put("sameProcess",true)
        ready.writeText(record.toString())
        while (!stop.exists() && SystemClock.elapsedRealtime()<deadline) SystemClock.sleep(200)
        assertTrue("Host completed real FCM observation",stop.exists())
        ready.delete();trigger.delete();stop.delete()
    }
}
