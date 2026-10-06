package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.JUnitCore
import org.junit.runners.BlockJUnit4ClassRunner
import org.junit.runners.model.MultipleFailureException

/** No Android/OS/storage calls. Exercises the exact fixture used by the real suite. */
class NativeBridgeFixtureTest {
    private class Spy {
        var pkg = NativeBridgeFixture.PACKAGE
        var cache: Any? = null
        val effects = mutableListOf<String>()
        val destroyed = mutableListOf<Any>()
        var inMain = false
        var afters = 0
        var bodies = 0
        var preflight: () -> Unit = {}
        var afterFirstWrite: () -> Unit = {}
        var body: () -> Unit = {}
        var closeError: Throwable? = null
        var destroyError: Throwable? = null
        var clearError: Throwable? = null
        var onDestroy: () -> Unit = {}
        var afterMain: () -> Unit = {}
        var state = false
        val fixture = NativeBridgeFixture<Any>(
            packageName = { pkg },
            onMain = { action ->
                check(!inMain)
                inMain = true
                try { action() } finally { inMain = false; afterMain() }
            },
            cachedEngine = { check(inMain); cache },
            destroyEngine = {
                check(inMain); effects.add("destroy"); destroyed.add(it)
                onDestroy(); destroyError?.let { error -> throw error }
            },
            removeEngine = { check(inMain); effects.add("cache-remove"); cache = null },
            clearState = {
                check(inMain); effects.addAll(listOf("clear-bind", "clear-reset", "clear-cards"))
                state = false
                clearError?.let { throw it }
            },
        )
        fun setup() = fixture.setup(preflight) {
            check(inMain)
            effects.addAll(listOf("reset", "bind", "cards"))
            state = true
            afterFirstWrite()
        }
        fun acquire(initialize: (Any) -> Unit = { cache = it; effects.add("cache-put") }): Any =
            fixture.acquireEngine(create = { effects.add("create"); Any() }, initialize = initialize)
        fun activity() {
            fixture.ownActivity(this) {
                check(!inMain) // wait/close adapter must not block the Android main thread
                effects.add("close")
                closeError?.let { throw it }
            }
        }
    }

    // A real JUnit4 runner drives @Before/@Test/@After, including failed setup.
    // ThreadLocal avoids a mutable global shared by independent runners.
    abstract class LifecycleProbe {
        private val spy = checkNotNull(current.get())
        @Before fun before() = spy.setup()
        @Test fun body() { spy.bodies++; spy.body() }
        @After fun after() { spy.afters++; spy.fixture.cleanup() }
    }
    companion object { private val current = ThreadLocal<Spy>() }

    private fun run(spy: Spy): org.junit.runner.Result {
        current.set(spy)
        try {
            // Abstract probe is not a standalone discoverable failing test. The
            // actual JUnit runner still supplies all before/test/after semantics.
            return JUnitCore().run(object : BlockJUnit4ClassRunner(LifecycleProbe::class.java) {
                override fun createTest(): Any = object : LifecycleProbe() {}
            })
        }
        finally { current.remove() }
    }
    private fun failures(action: () -> Unit): List<Throwable> {
        try { action() } catch (error: MultipleFailureException) { return error.failures }
        catch (error: Throwable) { return listOf(error) }
        fail("Expected a visible failure")
        return emptyList()
    }

    private val vivo = NativeBridgeEnvironment.Device("vivo", "fixture-model", "vivo/fixture/device:13/build:user/release-keys", "fixture-hardware")
    private fun selection() = mapOf("bridgeMode" to "isolated-vivo", "bridgeRunId" to "regression-03",
        "bridgeManufacturer" to vivo.manufacturer, "bridgeModel" to vivo.model, "bridgeFingerprint" to vivo.fingerprint)
    private fun rejectedEnvironment(device: NativeBridgeEnvironment.Device, args: Map<String, String?>) {
        val spy = Spy().apply { preflight = { NativeBridgeEnvironment.requireSelected(device, args) } }
        val result = run(spy)
        assertEquals(1, result.runCount)
        assertEquals(1, result.failureCount)
        assertEquals(0, result.ignoreCount)
        assertEquals(1, spy.afters)
        assertEquals(0, spy.bodies)
        assertTrue("Rejected preflight and JUnit After must not mutate state/engine/cards", spy.effects.isEmpty())
        assertFalse(spy.state)
        assertNull(spy.cache)
    }

    @Test fun physicalEnvironmentIsRejectedByDefault() {
        rejectedEnvironment(vivo, emptyMap())
        rejectedEnvironment(vivo, mapOf("allowPhysical" to "true"))
        rejectedEnvironment(vivo, selection() + ("bridgeMode" to "emulator"))
    }
    @Test fun physicalSelectionRequiresEveryIdentityAndRunArgument() {
        for (key in NativeBridgeEnvironment.argumentNames) {
            for (value in listOf(null, "", " ")) rejectedEnvironment(vivo, selection() + (key to value))
        }
        rejectedEnvironment(vivo, selection() + ("bridgeRunId" to "run; shell"))
    }
    @Test fun physicalIdentitiesAreExactWithoutCaseOrSuffixNormalization() {
        for (key in listOf("bridgeManufacturer", "bridgeModel", "bridgeFingerprint", "bridgeMode")) {
            val value = selection().getValue(key)
            for (wrong in listOf(value.uppercase(), "$value.extra", " $value", "wrong")) {
                rejectedEnvironment(vivo, selection() + (key to wrong))
            }
        }
        rejectedEnvironment(vivo.copy(model = "unknown"), selection() + ("bridgeModel" to "unknown"))
        rejectedEnvironment(vivo.copy(manufacturer = "other"), selection() + ("bridgeManufacturer" to "other"))
    }
    @Test fun explicitMatchingVivoSelectionUsesNormalFixtureLifecycle() {
        val spy = Spy().apply { preflight = { NativeBridgeEnvironment.requireSelected(vivo, selection()) } }
        assertTrue(run(spy).wasSuccessful())
        assertEquals(1, spy.bodies)
        assertEquals(1, spy.afters)
        assertEquals(listOf("reset", "bind", "cards", "clear-bind", "clear-reset", "clear-cards"), spy.effects)
    }
    @Test fun emulatorDefaultSelectionRemainsAvailable() {
        for (device in listOf(vivo.copy(fingerprint = "generic/test"), vivo.copy(model = "sdk_gphone_test"),
            vivo.copy(hardware = "ranchu"), vivo.copy(hardware = "goldfish"))) {
            NativeBridgeEnvironment.requireSelected(device, emptyMap())
            NativeBridgeEnvironment.requireSelected(device, mapOf("bridgeMode" to "emulator"))
        }
    }
    @Test fun emulatorCannotBeFallbackForPhysicalSelection() {
        val device = vivo.copy(hardware = "ranchu")
        rejectedEnvironment(device, selection())
        rejectedEnvironment(device, mapOf("bridgeRunId" to "accidental-selection"))
        rejectedEnvironment(device, mapOf("bridgeMode" to "unknown"))
    }

    @Test fun rejectedPackagesHaveZeroEffectsEvenWhenJUnitRunsAfter() {
        for (pkg in listOf("tr.com.soundconnect.app", "tr.com.soundconnect.app.preview",
            NativeBridgeFixture.PACKAGE + ".test", NativeBridgeFixture.PACKAGE + ".extra",
            "other.warmtest", "", NativeBridgeFixture.PACKAGE.uppercase())) {
            val spy = Spy().apply { this.pkg = pkg; cache = Any() }
            val foreign = spy.cache
            val result = run(spy)
            assertEquals(pkg, 1, result.runCount)
            assertEquals(pkg, 0, result.ignoreCount)
            assertTrue(pkg, result.failureCount > 0)
            assertEquals(pkg, 1, spy.afters)
            assertEquals(pkg, 0, spy.bodies)
            assertTrue(pkg, spy.effects.isEmpty())
            assertSame(foreign, spy.cache)
        }
    }

    @Test fun preflightFailureHasNoOwnedResources() {
        val spy = Spy().apply { preflight = { error("preflight") } }
        val result = run(spy)
        assertEquals(1, result.failureCount)
        assertEquals(1, spy.afters)
        assertEquals(0, spy.bodies)
        assertTrue(spy.effects.isEmpty())
    }

    @Test fun firstMutationThenSetupFailureStillCleansState() {
        val spy = Spy().apply { afterFirstWrite = { error("partial setup") } }
        val result = run(spy)
        assertEquals(1, result.failureCount)
        assertEquals("partial setup", result.failures.single().exception.message)
        assertEquals(0, spy.bodies)
        assertFalse(spy.state)
        assertEquals(listOf("reset", "bind", "cards", "clear-bind", "clear-reset", "clear-cards"), spy.effects)
    }

    @Test fun preexistingEngineIsRejectedWithoutStateOrEngineMutation() {
        val spy = Spy().apply { cache = Any() }
        val foreign = spy.cache
        assertEquals(1, run(spy).failureCount)
        assertSame(foreign, spy.cache)
        assertTrue(spy.effects.isEmpty())
    }

    @Test fun foreignEngineBeforeAcquisitionIsNeverAdopted() {
        val spy = Spy(); spy.setup()
        val foreign = Any(); spy.cache = foreign
        failures { spy.acquire() }
        spy.fixture.cleanup()
        assertSame(foreign, spy.cache)
        assertTrue(spy.destroyed.isEmpty())
        assertFalse(spy.effects.contains("create"))
        assertFalse(spy.state)
    }

    @Test fun engineInitializationFailureBeforePublicationDestroysOnlyOwnedEngine() {
        val spy = Spy(); spy.setup()
        var owned: Any? = null
        failures { spy.acquire { owned = it; error("Dart startup") } }
        spy.fixture.cleanup()
        assertSame(owned, spy.destroyed.single())
        assertNull(spy.cache)
        assertFalse(spy.effects.contains("cache-remove"))
    }

    @Test fun constructorFailureDoesNotAdoptAnEngine() {
        val spy = Spy(); spy.setup()
        failures { spy.fixture.acquireEngine(create = { error("constructor") }, initialize = {}) }
        spy.fixture.cleanup()
        assertTrue(spy.destroyed.isEmpty())
        assertFalse(spy.effects.contains("cache-remove"))
        assertFalse(spy.state)
    }

    @Test fun engineInitializationFailureAfterPublicationStillCleans() {
        val spy = Spy(); spy.setup()
        failures { spy.acquire { spy.cache = it; error("after publication") } }
        spy.fixture.cleanup()
        assertEquals(1, spy.destroyed.size)
        assertNull(spy.cache)
        assertFalse(spy.state)
    }

    @Test fun activityAcquiredBeforeSetupFailureIsClosedByJUnitAfter() {
        val spy = Spy()
        spy.afterFirstWrite = { spy.activity(); error("after Activity acquisition") }
        assertEquals(1, run(spy).failureCount)
        assertEquals(1, spy.effects.count { it == "close" })
        assertFalse(spy.state)
    }

    @Test fun testFailureAfterEngineAndActivityKeepsRootErrorAndCleans() {
        val spy = Spy()
        spy.body = { spy.acquire(); spy.activity(); error("test root") }
        val result = run(spy)
        assertEquals("test root", result.failures.single().exception.message)
        assertEquals(1, spy.destroyed.size)
        assertTrue(spy.effects.contains("close"))
        assertNull(spy.cache)
        assertFalse(spy.state)
    }

    @Test fun replacementCacheEntryIsRetainedAndReported() {
        val spy = Spy(); spy.setup(); spy.acquire(); spy.activity()
        val foreign = Any(); spy.cache = foreign
        assertTrue(failures { spy.fixture.cleanup() }.all { it.message == "Foreign replacement engine retained" })
        assertSame(foreign, spy.cache)
        assertTrue(spy.destroyed.isEmpty())
        assertFalse(spy.effects.contains("close"))
        assertFalse(spy.state)
    }

    @Test fun replacementDuringDestroyCannotBeRemoved() {
        val spy = Spy(); spy.setup()
        val owned = spy.acquire(); val foreign = Any()
        spy.onDestroy = { spy.cache = foreign }
        failures { spy.fixture.cleanup() }
        assertSame(owned, spy.destroyed.single())
        assertSame(foreign, spy.cache)
        assertFalse(spy.effects.contains("cache-remove"))
    }

    @Test fun closeFailureDoesNotPreventOtherActivityEngineCacheAndStateCleanup() {
        val spy = Spy(); spy.setup(); spy.acquire(); spy.activity()
        spy.closeError = IllegalStateException("close failed")
        var secondClosed = false
        spy.fixture.ownActivity(Any()) { secondClosed = true }
        assertEquals("close failed", failures { spy.fixture.cleanup() }.single().message)
        assertTrue(secondClosed)
        assertEquals(1, spy.destroyed.size)
        assertNull(spy.cache)
        assertFalse(spy.state)
    }

    @Test fun monitorRemovalFailureDoesNotPreventRemainingCleanup() {
        val spy = Spy(); spy.setup(); spy.acquire(); spy.activity()
        var removed = false
        spy.fixture.ownObserver { removed = true }
        spy.fixture.ownObserver { error("monitor removal") }
        assertEquals("monitor removal", failures { spy.fixture.cleanup() }.single().message)
        assertTrue(removed)
        assertTrue(spy.effects.contains("close"))
        assertNull(spy.cache)
        assertFalse(spy.state)
    }

    @Test fun rootAndAllIndependentCleanupErrorsReachJUnitReport() {
        val spy = Spy()
        spy.body = { spy.acquire(); spy.activity(); error("test root") }
        spy.closeError = IllegalStateException("close failed")
        spy.destroyError = IllegalStateException("destroy failed")
        spy.clearError = IllegalStateException("clear failed")
        val result = run(spy)
        assertEquals(setOf("test root", "close failed", "destroy failed", "clear failed"),
            result.failures.map { it.exception.message }.toSet())
        assertEquals(0, result.ignoreCount)
        assertNull(spy.cache)
    }

    @Test fun normalAndRepeatedCleanupAreIdempotentAndDeduplicateActivities() {
        val spy = Spy(); spy.setup(); spy.acquire(); spy.activity(); spy.activity()
        assertTrue(spy.fixture.ownsActivity(spy))
        assertFalse(spy.fixture.ownsActivity(Any()))
        spy.fixture.cleanup()
        assertFalse(spy.fixture.ownsActivity(spy))
        val effects = spy.effects.toList()
        spy.fixture.cleanup()
        assertEquals(effects, spy.effects)
        assertEquals(1, effects.count { it == "close" })
        assertEquals(1, spy.destroyed.size)
        assertNull(spy.cache)
        assertFalse(spy.state)
    }

    @Test fun repeatedCleanupAfterFailureDoesNotRepeatDestruction() {
        val spy = Spy(); spy.setup(); spy.acquire()
        spy.destroyError = IllegalStateException("partial destroy")
        failures { spy.fixture.cleanup() }
        val effects = spy.effects.toList()
        spy.fixture.cleanup()
        assertEquals(effects, spy.effects)
        assertNull(spy.cache)
        assertFalse(spy.state)
    }

    @Test fun queuedServiceDisposalCannotSeeDestroyedCachedEngine() {
        // Model a service onDestroy queued behind the fixture's main callback.
        // It must not find an engine already destroyed by the fixture, even if
        // that destroy failed after releasing some of its native resources.
        for (destroyFails in listOf(false, true)) {
            val spy = Spy(); spy.setup(); spy.acquire()
            var exposedDestroyedEngine = false
            spy.afterMain = {
                if (spy.destroyed.any { it === spy.cache }) exposedDestroyedEngine = true
            }
            if (destroyFails) {
                spy.destroyError = IllegalStateException("partial destroy")
                assertEquals("partial destroy", failures { spy.fixture.cleanup() }.single().message)
            } else {
                spy.fixture.cleanup()
            }
            assertFalse("Queued service can destroy the same cached engine twice", exposedDestroyedEngine)
            assertEquals(1, spy.destroyed.size)
            assertNull(spy.cache)
            assertFalse(spy.state)
        }
    }

    @Test fun cleanupRechecksPackageBeforeAnyMutation() {
        val spy = Spy(); spy.setup(); spy.acquire(); spy.activity()
        val effects = spy.effects.toList()
        val owned = spy.cache
        spy.pkg = "tr.com.soundconnect.app"
        failures { spy.fixture.cleanup() }
        assertEquals(effects, spy.effects)
        assertSame(owned, spy.cache)
    }

    @Test fun packageChangeDuringCleanupBlocksRemainingMutations() {
        val spy = Spy(); spy.setup(); spy.acquire()
        spy.onDestroy = { spy.pkg = "tr.com.soundconnect.app" }
        failures { spy.fixture.cleanup() }
        assertFalse(spy.effects.contains("cache-remove"))
        assertFalse(spy.effects.contains("clear-bind"))
        assertEquals(1, spy.destroyed.size)
    }
}
