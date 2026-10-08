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

/** Existing synthetic lifecycle/epoch regressions, using the shared owned fixture. */
@RunWith(AndroidJUnit4::class)
class NativePushBridgeLifecycleTest : NativePushBridgeTestFixture() {
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
        onMain { instrumentation.callActivityOnNewIntent(old!!,tap()) }
        assertTrue(events().isEmpty())
        val intent=tap();val copy=Intent(intent)
        scenario!!.onActivity { instrumentation.callActivityOnNewIntent(it,intent) };expectEvent(copy)
    }

    @Test fun everySupportedTypeRequiresItsCurrentIntentEpoch() {
        for (type in NativePushOpenCases.types) {
            val valid = tap(type)
            val expected = PushOpenTarget.parse(valid.action,
                PushOpenTarget.fields.associateWith { valid.getStringExtra("sc.push.$it") })
            assertNotNull("Valid parser fixture: $type", expected)
            for (epoch in listOf(null, "", " ", "malformed", "1-1-1-1-1", UUID.randomUUID().toString())) {
                assertNull("Reject $type epoch=$epoch", NativePushOpen.target(context, tap(type, epoch)))
            }
            assertEquals(type, expected, NativePushOpen.target(context, valid))
            assertEquals(binding, PushNotificationState.currentBinding(context))
        }
    }

    private fun rebindSameRecipient() {
        val old = binding
        PushNotificationState.bind(context, null)
        PushNotificationState.bind(context, recipient)
        binding = PushNotificationState.capture(context, recipient)!!
        assertNotEquals(old.epoch, binding.epoch)
    }

    @Test fun oldDmFirstAcceptedAfterReloginNeverReachesColdInitial() {
        val old = tap("DM_NEW_MESSAGE")
        rebindSameRecipient()
        launch(old)
        assertNull(dart("initial")); assertTrue(events().isEmpty())
        scenario!!.onActivity { assertEquals(Intent.ACTION_MAIN, it.intent.action) }
    }

    @Test fun oldEventFirstAcceptedAfterReloginNeverReachesWarmOpened() {
        val old = tap("EVENT_PERFORMER_APPROVAL_REQUESTED")
        rebindSameRecipient()
        launch(); dart("initial")
        scenario!!.onActivity { instrumentation.callActivityOnNewIntent(it, old) }
        assertEquals(Intent.ACTION_MAIN, old.action)
        assertTrue(events().isEmpty()); assertNull(dart("initial"))
    }

    @Test fun missingAndMalformedPreviouslyUnfencedEpochsNeverReachDart() {
        launch(); dart("initial")
        for (type in listOf("DM_NEW_MESSAGE", "EVENT_PERFORMER_APPROVED", "STUDIO_RESERVATION_CREATED")) {
            for (epoch in listOf(null, "", "invalid")) {
                scenario!!.onActivity { instrumentation.callActivityOnNewIntent(it, tap(type, epoch)) }
            }
        }
        assertTrue(events().isEmpty())
    }

    @Test fun currentDmColdTargetPreservesConversationAndConsumesOnce() {
        val intent = tap("DM_NEW_MESSAGE")
        val expected = PushOpenTarget.parse(intent.action,
            PushOpenTarget.fields.associateWith { intent.getStringExtra("sc.push.$it") })
        launch(intent)
        assertEquals(expected, dart("initial")); assertNull(dart("initial")); assertTrue(events().isEmpty())
    }

    @Test fun currentEventWarmTargetPreservesExactMetadataAfterRecreation() {
        launch(); dart("initial"); scenario!!.recreate()
        val intent = tap("EVENT_PERFORMER_APPROVAL_REQUESTED"); val copy = Intent(intent)
        scenario!!.onActivity { instrumentation.callActivityOnNewIntent(it, intent) }
        expectEvent(copy)
        assertEquals(setOf("notificationId", "recipientId", "type"), (events().single() as Map<*,*>).keys)
    }

    private fun shortcut(conversation: String) = tap("DM_NEW_MESSAGE", null).apply {
        action = PushOpenTarget.CONVERSATION_ACTION
        putExtra("sc.push.conversationId", conversation)
        putExtra("sc.push.senderName", "Untrusted cached identity")
    }

    @Test fun repeatableShortcutHasDistinctNavigationIdsAndNoCachedIdentity() {
        launch(); dart("initial")
        val conversation = UUID.randomUUID().toString()
        val first = shortcut(conversation); val second = Intent(first)
        val cachedId = first.getStringExtra("sc.push.notificationId")
        scenario!!.onActivity {
            instrumentation.callActivityOnNewIntent(it, first)
            instrumentation.callActivityOnNewIntent(it, second)
        }
        val values = events().map { it as Map<*,*> }
        assertEquals(2, values.size)
        assertNotEquals(values[0]["notificationId"], values[1]["notificationId"])
        values.forEach {
            assertNotEquals(cachedId, it["notificationId"])
            assertEquals(conversation, it["conversationId"])
            assertEquals(setOf("notificationId", "recipientId", "conversationId", "type"), it.keys)
        }
    }

    @Test fun pendingShortcutDoesNotSurviveSameRecipientRebind() {
        launch(shortcut(UUID.randomUUID().toString()))
        rebindSameRecipient()
        assertNull(dart("initial")); assertTrue(events().isEmpty())
    }

    @Test fun pendingShortcutDoesNotSurviveReset() {
        launch(shortcut(UUID.randomUUID().toString()))
        PushNotificationState.setResetRequired(context, true)
        assertNull(dart("initial")); assertTrue(events().isEmpty())
    }

    @Test fun pendingShortcutDoesNotSurviveAccountSwitch() {
        launch(shortcut(UUID.randomUUID().toString()))
        try {
            PushNotificationState.bind(context, UUID.randomUUID().toString())
            assertNull(dart("initial")); assertTrue(events().isEmpty())
        } finally { PushNotificationState.bind(context, recipient) }
    }

    @Test fun pendingTargetDoesNotSurviveAccountSwitch() {
        launch(tap("DM_NEW_MESSAGE"))
        try {
            PushNotificationState.bind(context, UUID.randomUUID().toString())
            assertNull(dart("initial")); assertTrue(events().isEmpty())
        } finally { PushNotificationState.bind(context, recipient) }
    }

    @Test fun rejectedIntentPreservesValidPendingTargetAndBinding() {
        val valid = tap("EVENT_PERFORMER_APPROVED"); val id = valid.getStringExtra("sc.push.notificationId")
        launch(valid)
        scenario!!.onActivity { instrumentation.callActivityOnNewIntent(it, tap("DM_NEW_MESSAGE", null)) }
        assertEquals(id, (dart("initial") as Map<*,*>)["notificationId"])
        assertNull(dart("initial")); assertTrue(events().isEmpty())
        assertEquals(binding, PushNotificationState.currentBinding(context))
    }

    @Test fun rejectedEpochPreservesSiblingReservationsLedgerAndOsSnapshot() {
        val now = System.currentTimeMillis()
        val values = List(2) { VenuePushPayload(UUID.randomUUID().toString(), recipient,
            "EVENT_PERFORMER_APPROVAL_REQUESTED", "PLAN_CONSENT", now, now + 300_000) }
        // This isolated package may have notifications denied. Reserve through
        // the real durable ledger without changing the user's permission; actual
        // visible sibling cards are verified separately in normal-product acceptance.
        values.forEach { assertTrue(PushNotificationState.postInitial(context, binding,
            it.notificationId, it.expiresAt) { true }) }
        val ledgerFiles = context.noBackupFilesDir.listFiles()!!.filter { it.name.contains("push") }
        val before = ledgerFiles.associate { it.name to it.readBytes().toList() }
        val cards = context.getSystemService(NotificationManager::class.java).activeNotifications.map { it.key }.toSet()
        val invalid = tap(values[0].type, UUID.randomUUID().toString()).apply {
            putExtra("sc.push.notificationId", values[0].notificationId)
        }
        assertNull(NativePushOpen.target(context, invalid))
        assertEquals(before, ledgerFiles.associate { it.name to it.readBytes().toList() })
        assertEquals(cards, context.getSystemService(NotificationManager::class.java).activeNotifications.map { it.key }.toSet())
        assertEquals(binding, PushNotificationState.currentBinding(context))
    }

    @Test fun unboundMismatchResetAndDisabledGateRejectBeforeDismissal() {
        val intent = tap("DM_NEW_MESSAGE")
        val wrong = Intent(intent).putExtra("sc.push.recipientId", UUID.randomUUID().toString())
        assertNull(NativePushOpen.target(context, wrong))
        val disabled = object : android.content.ContextWrapper(context) {
            override fun getResources(): android.content.res.Resources {
                val original = super.getResources()
                @Suppress("DEPRECATION")
                return object : android.content.res.Resources(original.assets, original.displayMetrics, original.configuration) {
                    override fun getBoolean(id: Int): Boolean = if (id == R.bool.soundconnect_push_enabled) false else super.getBoolean(id)
                }
            }
        }
        assertNull(NativePushOpen.target(disabled, intent))
        assertEquals(binding, PushNotificationState.currentBinding(context))
        PushNotificationState.setResetRequired(context, true)
        assertNull(NativePushOpen.target(context, intent))
        PushNotificationState.setResetRequired(context, false)
        assertNull(NativePushOpen.target(context, intent))
    }
}
