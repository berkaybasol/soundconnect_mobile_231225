package com.berkayb.soundconnect.soundconnect_23_12_25codx

import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

/** Diagnostic clocks only. No Android scheduler, product callback or platform dependency. */
internal interface DiagnosticClock { fun monotonicMs(): Long; fun wallMs(): Long }
internal enum class DiagnosticStatus { STARTED, DISABLED, BUSY, NOT_ACTIVE, SEALED, DISCARDED, STORED, DROPPED, UNKNOWN, STALE, NOT_SEALED, EXPORTED, EXPORT_FAILED }
internal enum class DiagnosticContextKind { CALLBACK, OPERATION }
internal open class DiagnosticHandle internal constructor(
    internal val generation: Long, internal val slot: Int,
    val callback: Int, val operation: Int
) {
    internal val closed = AtomicBoolean(false)
    internal val depth = AtomicInteger(1)
    // Atomic read kept overridable only for deterministic testDebug admission interleavings.
    // The core creates plain handles; no test latch or waiting is present here.
    internal open fun isClosed(): Boolean = closed.get()
}
internal data class DiagnosticRecord(val status: DiagnosticStatus, val seq: Int = 0, val notification: Int = 0, val scope: Int = 0)
internal data class DiagnosticExport(val status: DiagnosticStatus, val bytes: ByteArray? = null)

/**
 * Unconnected debug core. Internal methods require an explicit caller; construction is inert.
 * One CAS per writer admission, no waiting/spinning on writer paths. Only export may wait <=50 ms.
 * Each call captures one Session; all effects, including pre-admission losses, stay in it.
 * CAS ownership protects that session's arena. Retired sessions cannot touch a new session.
 */
internal class TableDiagnosticsCore(
    private val clock: DiagnosticClock,
    private val entropy: DiagnosticEntropy = SecureDiagnosticEntropy(),
    private val crypto: DiagnosticCryptoFactory = JvmDiagnosticCrypto(),
    private val json: TableDiagnosticsJson = TableDiagnosticsJson()
) {
    companion object {
        const val DURATION_MS = 600_000L
        const val RETENTION_MS = 300_000L
        // Binary arena + slot markers + HMAC scratch + key/session/process + conservative
        // scalar/context/atomic backing allowance. Provider/object headers are not this budget.
        const val BINARY_BYTES = TableDiagnosticsBuffer.ARENA_BYTES + 1024 * 4 + 8 * 64 + 64 + 4096
    }
    private val starting = AtomicBoolean(false)
    private val nextGeneration = AtomicLong(0)
    private val current = AtomicReference<Session?>(null)
    private var process: ByteArray? = null
    val state: DiagnosticState get() = current.get()?.state ?: DiagnosticState.DISABLED
    val active: Boolean get() = current.get()?.active ?: false

    fun start(input: DiagnosticBuild): DiagnosticStatus {
        if (!input.allowed()) return DiagnosticStatus.DISABLED
        if (!starting.compareAndSet(false, true)) return DiagnosticStatus.BUSY
        try {
            if (current.get() != null) return DiagnosticStatus.BUSY
            val session = Session(nextGeneration.incrementAndGet())
            if (!current.compareAndSet(null, session)) return DiagnosticStatus.BUSY
            return session.start(input)
        } finally { starting.set(false) }
    }

    // The receiver is read once, before any session-dependent check or mutation.
    // Even a call paused before writer admission retains only its original Session.
    fun acquire(kind: DiagnosticContextKind, parent: DiagnosticHandle? = null): DiagnosticHandle? =
        current.get()?.acquire(kind, parent)
    fun enter(handle: DiagnosticHandle): Boolean = current.get()?.enter(handle) ?: false
    fun release(handle: DiagnosticHandle) { current.get()?.release(handle) }
    fun record(handle: DiagnosticHandle, event: TableDiagnosticEvent): DiagnosticRecord =
        current.get()?.record(handle, event) ?: DiagnosticRecord(DiagnosticStatus.NOT_ACTIVE)
    fun recordNormalized(handle: DiagnosticHandle, event: TableDiagnosticEvent,
                         recipient: ByteArray, notification: ByteArray, epoch: ByteArray? = null): DiagnosticRecord =
        current.get()?.recordNormalized(handle, event, recipient, notification, epoch)
            ?: DiagnosticRecord(DiagnosticStatus.NOT_ACTIVE)
    fun tick(): DiagnosticStatus = current.get()?.tick() ?: DiagnosticStatus.NOT_ACTIVE
    fun stopAndSeal(): DiagnosticStatus = current.get()?.stopAndSeal() ?: DiagnosticStatus.NOT_ACTIVE
    fun discard(): DiagnosticStatus = current.get()?.discard() ?: DiagnosticStatus.NOT_ACTIVE
    fun exportSafeJson(): DiagnosticExport = current.get()?.exportSafeJson() ?: DiagnosticExport(DiagnosticStatus.NOT_ACTIVE)

    private inner class Session(initialGeneration: Long) {
        private val busy = AtomicBoolean(false)
        private val gate = AtomicBoolean(false)
        private val generation = AtomicLong(initialGeneration)
        private val pendingClear = AtomicBoolean(false)
        private val pendingEnd = AtomicReference(DiagnosticEnd.NONE)
        private val exporter = AtomicBoolean(false)
        private val exportFailures = AtomicInteger(0)
        private val sequence = AtomicInteger(0)
        private val health = DiagnosticHealth()
        private var buffer: TableDiagnosticsBuffer? = null
        private var aliases: TableDiagnosticsAliases? = null
        private var key: ByteArray? = null
        private var session: ByteArray? = null
        private var build: DiagnosticBuild? = null
        private val contexts = arrayOfNulls<DiagnosticHandle>(8)
        private var callbacks = 0
        private var operations = 0
        private var startMono = 0L
        private var startWall = 0L
        private var startWallSec: Long? = null
        private var lastMono = 0L
        private var lastClockOffset = 0L
        private var mono = 0
        private var wall = 0
        private var clockFlags = 0
        private var lastTick = 0L
        private var lastHeartbeat = 0L
        private var heartbeatCount = 0
        private var retentionDeadline = 0L
        @Volatile var state = DiagnosticState.DISABLED; private set
        val active: Boolean get() = gate.get()

        fun start(input: DiagnosticBuild): DiagnosticStatus {
            if (!input.allowed()) return DiagnosticStatus.DISABLED
            if (!busy.compareAndSet(false, true)) return DiagnosticStatus.BUSY
            try {
                if (state != DiagnosticState.DISABLED || pendingClear.get()) return DiagnosticStatus.BUSY
                health.clear(); sequence.set(0); pendingEnd.set(DiagnosticEnd.NONE); exportFailures.set(0)
                build = input
                buffer = TableDiagnosticsBuffer()
                key = ByteArray(32).also(entropy::fill)
                session = ByteArray(16).also(entropy::fill)
                if (process == null) process = ByteArray(16).also(entropy::fill)
                aliases = TableDiagnosticsAliases(buffer!!.arena, crypto, key!!)
                startMono = clock.monotonicMs()
                require(startMono >= 0 && startMono <= Long.MAX_VALUE - DURATION_MS - RETENTION_MS)
                startWall = clock.wallMs()
                startWallSec = if (startWall in 0..4_102_444_800_999L) startWall / 1000 else null
                clockFlags = if (startWallSec == null) 8 else 0
                if (clockFlags != 0) health.gap(128)
                lastMono = startMono; mono = 0; wall = 0; lastClockOffset = 0
                lastTick = startMono; lastHeartbeat = startMono; heartbeatCount = 0
                callbacks = 0; operations = 0
                state = DiagnosticState.ACTIVE; gate.set(true)
                control(DiagnosticStage.GATE_OPEN)
                control(DiagnosticStage.PROCESS_SCOPE_START)
                return DiagnosticStatus.STARTED
            } catch (_: Exception) {
                clearLocked()
                return DiagnosticStatus.UNKNOWN
            } finally { leave() }
        }

        fun acquire(kind: DiagnosticContextKind, parent: DiagnosticHandle? = null): DiagnosticHandle? {
            if (!gate.get()) return null
            if (!busy.compareAndSet(false, true)) { lost(DiagnosticHealthCounter.droppedContention, 1); return null }
            try {
                if (!gate.get() || !observeTime()) return null
                if (parent != null && !valid(parent)) return null
                var slot = -1
                for (i in contexts.indices) if (contexts[i] == null || contexts[i]!!.closed.get()) { slot = i; break }
                if (slot == -1) { lost(DiagnosticHealthCounter.droppedContext, 16); requestSeal(DiagnosticEnd.CONTEXT_LIMIT); return null }
                if (kind == DiagnosticContextKind.CALLBACK && callbacks == 128 || kind == DiagnosticContextKind.OPERATION && operations == 512) {
                    lost(DiagnosticHealthCounter.droppedCallback, 4); requestSeal(DiagnosticEnd.SEQUENCE_LIMIT); return null
                }
                val callback = if (kind == DiagnosticContextKind.CALLBACK) ++callbacks else parent?.callback ?: 0
                val operation = if (kind == DiagnosticContextKind.OPERATION) ++operations else 0
                return DiagnosticHandle(generation.get(), slot, callback, operation).also { contexts[slot] = it }
            } catch (_: Exception) { failure(); return null } finally { leave() }
        }

        fun enter(handle: DiagnosticHandle): Boolean {
            if (!gate.get() || handle.generation != generation.get() || handle.isClosed()) return false
            val depth = handle.depth.get()
            if (depth >= 4) {
                lost(DiagnosticHealthCounter.droppedContext, 16); requestSeal(DiagnosticEnd.CONTEXT_LIMIT)
                return false
            }
            if (!handle.depth.compareAndSet(depth, depth + 1)) { lost(DiagnosticHealthCounter.droppedContention, 1); return false }
            return true
        }
        fun release(handle: DiagnosticHandle) {
            // Logical release is wait-free and cannot free a replacement context with the same slot.
            if (handle.generation != generation.get() || handle.isClosed()) return
            val depth = handle.depth.get()
            if (depth > 1) {
                if (!handle.depth.compareAndSet(depth, depth - 1)) { lost(DiagnosticHealthCounter.droppedContention, 1); handle.closed.set(true) }
            } else handle.closed.set(true)
        }

        fun record(handle: DiagnosticHandle, event: TableDiagnosticEvent): DiagnosticRecord = recordInternal(handle, event, null, null, null)

        /** Only already-normalized synthetic identities are accepted. No parser, UUID or string surface. */
        fun recordNormalized(handle: DiagnosticHandle, event: TableDiagnosticEvent,
                             recipient: ByteArray, notification: ByteArray, epoch: ByteArray? = null): DiagnosticRecord =
            recordInternal(handle, event, recipient, notification, epoch)

        private fun recordInternal(handle: DiagnosticHandle, event: TableDiagnosticEvent,
                                   recipient: ByteArray?, identity: ByteArray?, epoch: ByteArray?): DiagnosticRecord {
            if (!gate.get()) return DiagnosticRecord(DiagnosticStatus.NOT_ACTIVE)
            if (handle.generation != generation.get() || handle.isClosed()) return DiagnosticRecord(DiagnosticStatus.STALE)
            health.bump(DiagnosticHealthCounter.attempted)
            if (!busy.compareAndSet(false, true)) {
                nextSequence(); lost(DiagnosticHealthCounter.droppedContention, 1)
                return DiagnosticRecord(DiagnosticStatus.DROPPED)
            }
            try {
                if (!valid(handle)) return DiagnosticRecord(DiagnosticStatus.STALE)
                if (!gate.get() || !observeTime()) return DiagnosticRecord(DiagnosticStatus.NOT_ACTIVE)
                val seq = nextSequence()
                if (seq == 0) return DiagnosticRecord(DiagnosticStatus.DROPPED)
                val b = buffer!!
                val a = aliases!!
                if (event.notification > a.notifications || event.parent >= seq || isControl(event.stage)) {
                    failure(); return DiagnosticRecord(DiagnosticStatus.UNKNOWN)
                }
                if (recipient != null && (recipient.size != 16 || identity?.size != 16 || epoch != null && epoch.size != 16 ||
                        event.family != DiagnosticFamily.TABLE_VALID || event.result != DiagnosticResult.ALLOW ||
                        !(event.stage == DiagnosticStage.PARSE && event.reason == DiagnosticReason.PARSE_ACCEPTED || event.stage == DiagnosticStage.CAPTURE))) {
                    lost(DiagnosticHealthCounter.droppedAlias, 8); return DiagnosticRecord(DiagnosticStatus.UNKNOWN)
                }
                if (!b.incrementBudget(handle.callback, handle.operation)) {
                    lost(DiagnosticHealthCounter.droppedCallback, 4); return DiagnosticRecord(DiagnosticStatus.DROPPED)
                }
                val slot = b.reserve(false)
                if (slot < 0) { lost(DiagnosticHealthCounter.droppedCapacity, 2); requestSeal(DiagnosticEnd.BUFFER_FULL); return DiagnosticRecord(DiagnosticStatus.DROPPED) }
                val capturedGeneration = generation.get()
                val candidate = if (recipient == null) null else a.prepare(handle.slot, recipient, identity!!, epoch)
                if (recipient != null && candidate == null) {
                    unfinished(b); lost(DiagnosticHealthCounter.droppedAlias, 8); requestSeal(DiagnosticEnd.ALIAS_LIMIT)
                    return DiagnosticRecord(DiagnosticStatus.UNKNOWN)
                }
                if (generation.get() != capturedGeneration || !gate.get()) { unfinished(b); return DiagnosticRecord(DiagnosticStatus.STALE) }
                val recorded = event.copy(seq = seq, callback = handle.callback, operation = handle.operation,
                    notification = candidate?.notification ?: event.notification, monoMs = mono, wallDeltaMs = wall,
                    timeFlags = event.timeFlags or clockFlags)
                b.write(slot, recorded)
                if (!b.commit(slot)) { health.gap(64); return DiagnosticRecord(DiagnosticStatus.DROPPED) }
                if (candidate != null) a.commit(handle.slot, candidate)
                health.bump(DiagnosticHealthCounter.stored)
                if (b.dataCount == TableDiagnosticsBuffer.DATA_SLOTS) requestSeal(DiagnosticEnd.BUFFER_FULL)
                return DiagnosticRecord(DiagnosticStatus.STORED, seq, recorded.notification, candidate?.scope ?: 0)
            } catch (_: Exception) {
                buffer?.let(::unfinished); lost(DiagnosticHealthCounter.droppedAlias, 8); failure()
                return DiagnosticRecord(DiagnosticStatus.UNKNOWN)
            } finally { aliases?.forgetScratch(handle.slot); leave() }
        }

        fun tick(): DiagnosticStatus {
            if (state == DiagnosticState.DISABLED) return DiagnosticStatus.NOT_ACTIVE
            if (!busy.compareAndSet(false, true)) { lost(DiagnosticHealthCounter.droppedContention, 1); return DiagnosticStatus.BUSY }
            try {
                val now = clock.monotonicMs()
                if (state != DiagnosticState.ACTIVE) {
                    if (now >= retentionDeadline) { pendingClear.set(true); return DiagnosticStatus.DISCARDED }
                    return DiagnosticStatus.SEALED
                }
                if (now - lastTick < 1000 && now < startMono + DURATION_MS) return DiagnosticStatus.STARTED
                lastTick = now
                if (!observeTime(now)) return DiagnosticStatus.SEALED
                if (now - lastHeartbeat >= 10_000 && heartbeatCount < 60) {
                    lastHeartbeat = now; heartbeatCount++; control(DiagnosticStage.HEARTBEAT)
                }
                return DiagnosticStatus.STARTED
            } catch (_: Exception) { failure(); return DiagnosticStatus.UNKNOWN } finally { leave() }
        }

        fun stopAndSeal(): DiagnosticStatus {
            if (state == DiagnosticState.DISABLED) return DiagnosticStatus.NOT_ACTIVE
            if (state != DiagnosticState.ACTIVE) return DiagnosticStatus.SEALED
            requestSeal(DiagnosticEnd.MANUAL)
            return if (state == DiagnosticState.ACTIVE) DiagnosticStatus.BUSY else DiagnosticStatus.SEALED
        }
        fun discard(): DiagnosticStatus {
            if (state == DiagnosticState.DISABLED) return DiagnosticStatus.NOT_ACTIVE
            gate.set(false); generation.set(-1); pendingClear.set(true)
            finishPending()
            return DiagnosticStatus.DISCARDED
        }

        fun exportSafeJson(): DiagnosticExport {
            if (state == DiagnosticState.DISABLED) return DiagnosticExport(DiagnosticStatus.NOT_ACTIVE)
            if (gate.get() || state == DiagnosticState.ACTIVE && pendingEnd.get() == DiagnosticEnd.NONE) return DiagnosticExport(DiagnosticStatus.NOT_SEALED)
            if (!exporter.compareAndSet(false, true)) return DiagnosticExport(DiagnosticStatus.BUSY)
            var owned = false
            try {
                val until = System.nanoTime() + 50_000_000L
                do {
                    owned = busy.compareAndSet(false, true)
                    if (owned) break
                    Thread.yield() // Export thread only; no waits or scheduler in recording paths.
                } while (System.nanoTime() < until)
                if (!owned) {
                    buffer?.let(::unfinished)
                    health.gap(64)
                    return exportFailed()
                }
                if (pendingClear.get() || state == DiagnosticState.DISABLED) return DiagnosticExport(DiagnosticStatus.NOT_ACTIVE)
                if (state == DiagnosticState.ACTIVE) sealLocked()
                val exportGeneration = generation.get()
                if (clock.monotonicMs() >= retentionDeadline) { pendingClear.set(true); return DiagnosticExport(DiagnosticStatus.NOT_ACTIVE) }
                val bytes = json.export(buffer!!, health, state, pendingEnd.get(), session!!, process!!, build!!, startWallSec)
                if (pendingClear.get() || generation.get() != exportGeneration) {
                    bytes.fill(0)
                    return DiagnosticExport(DiagnosticStatus.DISCARDED)
                }
                gate.set(false); generation.set(-1); pendingClear.set(true)
                return DiagnosticExport(DiagnosticStatus.EXPORTED, bytes)
            } catch (_: Exception) { return exportFailed() }
            finally {
                if (owned) leave()
                else if (pendingClear.get()) finishPending()
                exporter.set(false)
            }
        }
        private fun exportFailed(): DiagnosticExport {
            if (exportFailures.incrementAndGet() >= 2) {
                gate.set(false); generation.set(-1); pendingClear.set(true)
            }
            return DiagnosticExport(DiagnosticStatus.EXPORT_FAILED)
        }

        private fun valid(h: DiagnosticHandle) = h.generation == generation.get() && !h.isClosed() && contexts[h.slot] === h
        private fun lost(counter: DiagnosticHealthCounter, bit: Int) { health.bump(counter); health.gap(bit) }
        private fun failure() { health.gap(64); requestSeal(DiagnosticEnd.RECORD_FAILURE) }
        private fun unfinished(b: TableDiagnosticsBuffer) { val n = b.abandonUnfinished(); if (n > 0) { health.bump(DiagnosticHealthCounter.unfinishedSlots, n); health.gap(64) } }
        private fun nextSequence(): Int {
            val value = sequence.getAndIncrement()
            if (value >= 1_000_000) { health.gap(2); requestSeal(DiagnosticEnd.SEQUENCE_LIMIT); return 0 }
            return value + 1
        }
        private fun requestSeal(reason: DiagnosticEnd) {
            pendingEnd.compareAndSet(DiagnosticEnd.NONE, reason); gate.set(false)
            // A delayed contention/depth request can arrive after the previous owner left.
            // Request side and owner side both attempt the same bounded handoff.
            finishPending()
        }
        private fun finishPending() { if (busy.compareAndSet(false, true)) leave() }
        private fun leave() {
            // Release before rechecking: a requester either acquires the idle owner itself,
            // or this owner sees the request. There is no check-then-unlock lost wakeup.
            // At most two terminal transitions exist: ACTIVE -> sealed -> DISABLED.
            // Thus the initial pass plus at most two handoffs is bounded, never a CAS spin.
            repeat(3) { pass ->
                try {
                    if (state != DiagnosticState.DISABLED && pendingClear.get()) clearLocked()
                    else if (state == DiagnosticState.ACTIVE && !gate.get()) sealLocked()
                } finally { busy.set(false) }
                val pending = state != DiagnosticState.DISABLED &&
                    (pendingClear.get() || state == DiagnosticState.ACTIVE && !gate.get())
                if (!pending || pass == 2 || !busy.compareAndSet(false, true)) return
            }
        }
        private fun sealLocked() {
            try {
                val now = clock.monotonicMs().coerceAtLeast(lastMono)
                lastMono = now
                mono = subtract(now, startMono).coerceIn(0, 900_000).toInt()
                retentionDeadline = if (now <= Long.MAX_VALUE - RETENTION_MS) now + RETENTION_MS else Long.MAX_VALUE
                val close = control(DiagnosticStage.GATE_CLOSE, closing = true)
                val end = control(DiagnosticStage.PROCESS_SCOPE_END, closing = true)
                state = if (!close || !end || health.count(DiagnosticHealthCounter.unfinishedSlots) > 0) DiagnosticState.INCOMPLETE
                    else if (pendingEnd.get() == DiagnosticEnd.MANUAL) DiagnosticState.SEALED else DiagnosticState.AUTO_SEALED
            } catch (_: Exception) {
                health.gap(64); state = DiagnosticState.INCOMPLETE
                retentionDeadline = lastMono + RETENTION_MS
            }
        }
        private fun control(stage: DiagnosticStage, reason: DiagnosticReason = DiagnosticReason.NONE, closing: Boolean = false): Boolean {
            val b = buffer ?: return false
            health.bump(DiagnosticHealthCounter.attempted)
            val seq = nextSequence()
            if (seq == 0) return false
            val slot = b.reserve(true, closing)
            if (slot < 0) { lost(DiagnosticHealthCounter.droppedCapacity, 2); if (!closing) requestSeal(DiagnosticEnd.BUFFER_FULL); return false }
            val r = if (closing) DiagnosticReason.valueOf(pendingEnd.get().name) else reason
            b.write(slot, TableDiagnosticEvent(seq = seq, stage = stage, source = DiagnosticSource.DIAGNOSTIC_CONTROL,
                monoMs = mono, wallDeltaMs = wall, timeFlags = clockFlags, reason = r))
            if (!b.commit(slot)) { unfinished(b); return false }
            health.bump(DiagnosticHealthCounter.stored)
            if (!closing && b.controlCount == 126) requestSeal(DiagnosticEnd.BUFFER_FULL)
            return true
        }
        private fun observeTime(now: Long = clock.monotonicMs()): Boolean {
            if (now >= startMono + DURATION_MS) { lastMono = now; requestSeal(DiagnosticEnd.TIME_LIMIT); return false }
            val elapsed = subtract(now, startMono)
            val wallDelta = subtract(clock.wallMs(), startWall)
            val offset = subtract(wallDelta, elapsed)
            clockFlags = if (startWallSec == null || elapsed !in 0..900_000 || wallDelta !in -604_800_000..604_800_000 || now < lastMono) 8 else 0
            mono = elapsed.coerceIn(0, 900_000).toInt(); wall = wallDelta.coerceIn(-604_800_000, 604_800_000).toInt()
            if (subtract(offset, lastClockOffset) !in -2000..2000 || clockFlags != 0) {
                health.gap(128); control(DiagnosticStage.CLOCK_CHANGE, DiagnosticReason.CLOCK_DISCONTINUITY)
            }
            lastClockOffset = offset; lastMono = maxOf(lastMono, now)
            return gate.get()
        }
        private fun clearLocked() {
            gate.set(false); generation.set(-1); pendingClear.set(true)
            aliases?.clear(); aliases = null
            buffer?.clear(); buffer = null
            key?.fill(0); key = null; session?.fill(0); session = null
            // Only the random 16-byte process label survives session cleanup in this instance.
            // Notification/scope digests, session label, key, scratch and events are cleared.
            for (i in contexts.indices) { contexts[i]?.closed?.set(true); contexts[i] = null }
            build = null; health.clear(); sequence.set(0); callbacks = 0; operations = 0
            startMono = 0; startWall = 0; startWallSec = null; lastMono = 0; lastClockOffset = 0
            mono = 0; wall = 0; clockFlags = 0; lastTick = 0; lastHeartbeat = 0; heartbeatCount = 0; retentionDeadline = 0
            state = DiagnosticState.DISABLED; pendingEnd.set(DiagnosticEnd.NONE)
            // Terminal session: never reuse its atomics, contexts or arena for another start.
            current.compareAndSet(this, null)
        }
        private fun isControl(s: DiagnosticStage) = s in arrayOf(DiagnosticStage.GATE_OPEN, DiagnosticStage.PROCESS_SCOPE_START,
            DiagnosticStage.HEARTBEAT, DiagnosticStage.CLOCK_CHANGE, DiagnosticStage.GAP, DiagnosticStage.GATE_CLOSE, DiagnosticStage.PROCESS_SCOPE_END)
        private fun subtract(a: Long, b: Long): Long = try { Math.subtractExact(a, b) } catch (_: ArithmeticException) { if (a < b) Long.MIN_VALUE else Long.MAX_VALUE }
    }
}
