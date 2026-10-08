package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.runners.model.MultipleFailureException
import java.util.IdentityHashMap

/** Test-only environment selection. Arguments express selection, never human consent.
 * Serial/user selection belongs to the host; Android checks its own Build values.
 */
internal object NativeBridgeEnvironment {
    data class Device(val manufacturer: String, val model: String, val fingerprint: String, val hardware: String)
    val argumentNames = listOf("bridgeMode", "bridgeRunId", "bridgeManufacturer", "bridgeModel", "bridgeFingerprint")

    fun requireSelected(device: Device, args: Map<String, String?>) {
        val emulator = device.fingerprint.contains("generic") || device.model.contains("sdk_gphone") ||
            device.hardware in setOf("ranchu", "goldfish")
        val mode = args["bridgeMode"]
        if (mode == null || mode == "emulator") {
            check(emulator) { "Physical device requires explicit isolated-vivo selection" }
            check(argumentNames.drop(1).all { args[it] == null }) { "Unexpected physical selection arguments" }
            return
        }
        check(mode == "isolated-vivo" && !emulator) { "Unexpected bridge environment" }
        check(args["bridgeRunId"]?.matches(Regex("[A-Za-z0-9][A-Za-z0-9._-]{0,79}")) == true) {
            "Explicit nonempty run identity required"
        }
        check(device.manufacturer.equals("vivo", ignoreCase = true)) { "Selected physical device must be Vivo" }
        for ((key, observed) in listOf("bridgeManufacturer" to device.manufacturer,
            "bridgeModel" to device.model, "bridgeFingerprint" to device.fingerprint)) {
            check(observed.isNotBlank() && observed != "unknown" && args[key] == observed) {
                "Missing or mismatched observed device identity: $key"
            }
        }
    }
}

/** Shared by the real Android fixture and its side-effect-free JUnit regressions.
 * This source directory is included ONLY in test and androidTest, never main.
 * All acquisition/state/cache operations are serialized by onMain.
 */
internal class NativeBridgeFixture<E : Any>(
    private val packageName: () -> String,
    private val onMain: (() -> Unit) -> Unit,
    private val cachedEngine: () -> E?,
    private val destroyEngine: (E) -> Unit,
    private val removeEngine: () -> Unit,
    private val clearState: () -> Unit,
) {
    companion object { const val PACKAGE = "tr.com.soundconnect.app.warmtest" }

    private var stateOwned = false
    private var engine: E? = null
    private var closed = false
    private val activities = IdentityHashMap<Any, () -> Unit>()
    private val observers = mutableListOf<() -> Unit>()

    fun checkPackage() = check(packageName() == PACKAGE) { "Isolated harness package only" }

    fun setup(preflight: () -> Unit, initializeState: () -> Unit) = onMain {
        checkPackage()
        check(!closed && !stateOwned) { "Fixture cannot be reused" }
        preflight()
        check(cachedEngine() == null) { "Preexisting engine is not owned by this test" }
        // setResetRequired can write/bind and THEN throw. Claim the verified
        // empty isolated state before entering the first mutating operation.
        stateOwned = true
        initializeState()
    }

    fun acquireEngine(create: () -> E, initialize: (E) -> Unit): E {
        var acquired: E? = null
        onMain {
            checkPackage()
            check(stateOwned && !closed && engine == null)
            check(cachedEngine() == null) { "Foreign engine appeared before acquisition" }
            val value = create()
            engine = value // before registration, Dart startup or cache publication
            acquired = value
            initialize(value)
            check(cachedEngine() === value) { "Acquired engine is not the cached engine" }
        }
        return checkNotNull(acquired)
    }

    /** Register before installing a monitor/callback, including partial failure. */
    fun ownObserver(remove: () -> Unit) {
        checkPackage()
        check(stateOwned && !closed)
        observers.add(remove)
    }

    /** Called on main at PRE_ON_CREATE, before Activity creation can fail. */
    fun ownActivity(activity: Any, close: () -> Unit) {
        checkPackage()
        check(stateOwned && !closed)
        activities.putIfAbsent(activity, close)
    }

    fun ownsActivity(activity: Any): Boolean = activities.containsKey(activity)

    /** Main-thread guard also used immediately before Activity.finish: audio_service
     * can dispose the cached engine indirectly while detaching an Activity. */
    fun checkEngineOwnership() {
        checkPackage()
        val current = cachedEngine()
        check(current == null || current === engine) { "Foreign replacement engine retained" }
    }

    fun cleanup() {
        // In particular, @After following a rejected @Before must do no work.
        checkPackage()
        if (closed) return
        val errors = mutableListOf<Throwable>()
        fun attempt(action: () -> Unit) {
            try { checkPackage(); action() } catch (error: Throwable) { errors.add(error) }
        }
        // Snapshot/unregister on main so callbacks cannot race ownership changes.
        var closes = emptyList<() -> Unit>()
        attempt {
            onMain {
                closes = activities.values.toList()
                activities.clear()
                observers.asReversed().forEach { remove -> attempt(remove) }
                observers.clear()
                closed = true
            }
        }
        closes.forEach { close ->
            attempt {
                onMain { checkEngineOwnership() }
                close()
            }
        }
        val owned = engine
        engine = null // no repeat destruction even after a partially failing destroy
        if (owned != null) {
            attempt {
                onMain {
                    // Keep both operations in the same main-loop turn: a queued
                    // audio_service onDestroy must not find our destroyed engine
                    // still cached and destroy its detached FlutterJNI again.
                    attempt {
                        val current = cachedEngine()
                        check(current == null || current === owned) { "Foreign replacement engine retained" }
                        destroyEngine(owned)
                    }
                    // Even a partial destroy failure must allow reference-checked
                    // removal, before another main-loop callback can run.
                    attempt {
                        val current = cachedEngine()
                        check(current == null || current === owned) { "Foreign replacement engine retained" }
                        if (current === owned) removeEngine()
                    }
                }
            }
        }
        if (stateOwned) {
            stateOwned = false
            attempt { onMain { clearState() } }
        }
        MultipleFailureException.assertEmpty(errors)
    }
}
