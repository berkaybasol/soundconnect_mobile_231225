package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/** All barriers/latches are test-only. No product action or State lock is involved. */
class TableDiagnosticsConcurrencyTest {
    private fun await(latch: CountDownLatch) { assertTrue("synthetic latch timed out", latch.await(3, TimeUnit.SECONDS)) }
    private fun join(thread: Thread) { thread.join(4000); assertFalse("synthetic worker stuck", thread.isAlive) }
    private class PausingHandle(original: DiagnosticHandle) : DiagnosticHandle(
        original.generation, original.slot, original.callback, original.operation
    ) {
        val entered = CountDownLatch(1)
        val proceed = CountDownLatch(1)
        val armed = java.util.concurrent.atomic.AtomicBoolean(false)
        override fun isClosed(): Boolean {
            // Return the real atomic read taken BEFORE the pause. This puts the pause
            // after the precheck's observations, not before a newly effective recheck.
            val observed = super.isClosed()
            if (armed.compareAndSet(true, false)) {
                entered.countDown()
                check(proceed.await(3, TimeUnit.SECONDS))
            }
            return observed
        }
    }
    private fun pausingHandle(c: TableDiagnosticsCore): PausingHandle {
        val original = c.acquire(DiagnosticContextKind.CALLBACK)!!
        val h = PausingHandle(original)
        privateField<Array<DiagnosticHandle?>>(c, "contexts")[original.slot] = h
        original.closed.set(true)
        return h
    }
    private fun sessionOwner(c: TableDiagnosticsCore): Any {
        val f = c.javaClass.declaredFields.firstOrNull { it.name == "current" } ?: return c
        f.isAccessible = true
        return (f.get(c) as AtomicReference<*>).get()!!
    }
    private fun assertCleared(owner: Any, arena: ByteArray, key: ByteArray, session: ByteArray,
                              aliases: TableDiagnosticsAliases, contexts: Array<DiagnosticHandle?>) {
        // No core API is called to trigger deferred cleanup before these observations.
        assertEquals(DiagnosticState.DISABLED, privateField<DiagnosticState>(owner, "state"))
        assertNull(privateField<Any?>(owner, "key")); assertNull(privateField<Any?>(owner, "buffer"))
        assertNull(privateField<Any?>(owner, "aliases")); assertNull(privateField<Any?>(owner, "session"))
        assertTrue(arena.all { it == 0.toByte() }); assertTrue(key.all { it == 0.toByte() })
        assertTrue(session.all { it == 0.toByte() }); assertTrue(contexts.all { it == null })
        assertEquals(0, aliases.notifications); assertEquals(0, aliases.scopes)
        assertTrue(privateField<Array<ByteArray>>(aliases, "scratch").all { a -> a.all { it == 0.toByte() } })
        assertTrue(privateField<Array<DiagnosticHmac?>>(aliases, "workers").all { it == null })
    }
    @Test fun oldEnterPausedAfterChecksCannotSealReplacementSession() {
        val c = startedCore(); val h = pausingHandle(c)
        h.depth.set(4); h.armed.set(true)
        val result = AtomicReference<Boolean?>(); val error = AtomicReference<Throwable?>()
        val actor = Thread { try { result.set(c.enter(h)) } catch (t: Throwable) { error.set(t) } }
        try {
            actor.start(); await(h.entered)
            assertEquals(DiagnosticStatus.DISCARDED, c.discard())
            assertEquals(DiagnosticStatus.STARTED, c.start(syntheticBuild))
            val health = privateField<DiagnosticHealth>(c, "health")
            val buffer = privateField<TableDiagnosticsBuffer>(c, "buffer")
            val before = buffer.arena.copyOf()
            h.proceed.countDown(); join(actor); error.get()?.let { throw it }
            assertFalse(result.get()!!)
            assertTrue("old enter must not close the new gate", c.active)
            assertEquals(DiagnosticState.ACTIVE, c.state)
            assertEquals(DiagnosticEnd.NONE, privateField<AtomicReference<DiagnosticEnd>>(c, "pendingEnd").get())
            assertEquals(2, health.count(DiagnosticHealthCounter.attempted))
            assertEquals(0, health.count(DiagnosticHealthCounter.droppedContext)); assertEquals(0, health.mask())
            assertEquals(2, privateField<java.util.concurrent.atomic.AtomicInteger>(c, "sequence").get())
            assertArrayEquals(before, buffer.arena)
        } finally { h.proceed.countDown(); join(actor) }
    }
    @Test fun oldRecordPausedAfterChecksCannotIncrementReplacementHealth() {
        val c = startedCore(); val h = pausingHandle(c); h.armed.set(true)
        val result = AtomicReference<DiagnosticRecord?>(); val error = AtomicReference<Throwable?>()
        val actor = Thread { try { result.set(c.record(h, syntheticEvent())) } catch (t: Throwable) { error.set(t) } }
        try {
            actor.start(); await(h.entered); c.discard()
            assertEquals(DiagnosticStatus.STARTED, c.start(syntheticBuild))
            h.proceed.countDown(); join(actor); error.get()?.let { throw it }
            assertEquals(DiagnosticStatus.STALE, result.get()!!.status)
            val health = privateField<DiagnosticHealth>(c, "health")
            assertEquals("old record must not count as a new session attempt", 2, health.count(DiagnosticHealthCounter.attempted))
            assertEquals(0, health.mask()); assertTrue(c.active)
            assertEquals(2, privateField<java.util.concurrent.atomic.AtomicInteger>(c, "sequence").get())
            assertEquals(0, privateField<TableDiagnosticsBuffer>(c, "buffer").dataCount)
        } finally { h.proceed.countDown(); join(actor) }
    }
    @Test fun oldRecordCannotContendWithReplacementWriterOrConsumeItsSequence() {
        val crypto = BlockingCrypto(); val c = startedCore(crypto = crypto)
        val h = pausingHandle(c); h.armed.set(true)
        val error = AtomicReference<Throwable?>()
        val old = Thread { try { c.record(h, syntheticEvent()) } catch (t: Throwable) { error.set(t) } }
        var writer: Thread? = null
        try {
            old.start(); await(h.entered); c.discard()
            assertEquals(DiagnosticStatus.STARTED, c.start(syntheticBuild))
            val fresh = c.acquire(DiagnosticContextKind.CALLBACK)!!
            writer = Thread { try { c.recordNormalized(fresh, captureEvent(), id(1), id(2)) } catch (t: Throwable) { error.set(t) } }
            writer.start(); await(crypto.entered)
            val health = privateField<DiagnosticHealth>(c, "health")
            val sequence = privateField<java.util.concurrent.atomic.AtomicInteger>(c, "sequence")
            val arena = privateField<TableDiagnosticsBuffer>(c, "buffer").arena
            val bytes = arena.copyOf(); val beforeSequence = sequence.get()
            val attempts = health.count(DiagnosticHealthCounter.attempted)
            h.proceed.countDown(); join(old); error.get()?.let { throw it }
            assertEquals(attempts, health.count(DiagnosticHealthCounter.attempted))
            assertEquals(0, health.count(DiagnosticHealthCounter.droppedContention)); assertEquals(0, health.mask())
            assertEquals(beforeSequence, sequence.get()); assertArrayEquals(bytes, arena); assertTrue(c.active)
        } finally { h.proceed.countDown(); crypto.proceed.countDown(); join(old); writer?.let(::join) }
        error.get()?.let { throw it }
    }
    @Test fun oldReleasePausedAfterChecksCannotCloseReplacementContext() {
        val c = startedCore(); val h = pausingHandle(c); h.armed.set(true)
        val error = AtomicReference<Throwable?>()
        val actor = Thread { try { c.release(h) } catch (t: Throwable) { error.set(t) } }
        try {
            actor.start(); await(h.entered); c.discard(); c.start(syntheticBuild)
            val fresh = c.acquire(DiagnosticContextKind.CALLBACK)!!
            h.proceed.countDown(); join(actor); error.get()?.let { throw it }
            assertFalse(fresh.isClosed()); assertEquals(1, fresh.depth.get())
            assertEquals(0, privateField<DiagnosticHealth>(c, "health").mask())
            assertEquals(DiagnosticStatus.STORED, c.record(fresh, syntheticEvent()).status)
        } finally { h.proceed.countDown(); join(actor) }
    }
    @Test fun discardDuringSealDrainsBeforeAnyNextCoreCall() {
        val entered = CountDownLatch(1); val proceed = CountDownLatch(1)
        val clock = object : DiagnosticClock {
            override fun wallMs() = 1000L
            override fun monotonicMs(): Long {
                if (Thread.currentThread().name == "r36-seal-owner") {
                    entered.countDown(); check(proceed.await(3, TimeUnit.SECONDS))
                }
                return 100L
            }
        }
        val c = TableDiagnosticsCore(clock, SyntheticEntropy()); c.start(syntheticBuild)
        val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        c.recordNormalized(h, captureEvent(), id(1), id(2), id(3))
        val owner = sessionOwner(c); val arena = privateField<TableDiagnosticsBuffer>(c, "buffer").arena
        val key = privateField<ByteArray>(c, "key"); val session = privateField<ByteArray>(c, "session")
        val aliases = privateField<TableDiagnosticsAliases>(c, "aliases")
        val contexts = privateField<Array<DiagnosticHandle?>>(c, "contexts")
        val error = AtomicReference<Throwable?>()
        val actor = Thread({ try { c.stopAndSeal() } catch (t: Throwable) { error.set(t) } }, "r36-seal-owner")
        try {
            actor.start(); await(entered)
            assertEquals(DiagnosticStatus.DISCARDED, c.discard())
            assertTrue("owner still uses its memory", key.any { it != 0.toByte() })
        } finally { proceed.countDown(); join(actor) }
        error.get()?.let { throw it }
        assertCleared(owner, arena, key, session, aliases, contexts)
        assertEquals(DiagnosticStatus.STARTED, c.start(syntheticBuild))
    }
    @Test fun sealAndRepeatedDiscardDuringClearCannotResurrectSessionOrLoseCleanup() {
        val entered = CountDownLatch(1); val proceed = CountDownLatch(1)
        val blockOnce = java.util.concurrent.atomic.AtomicBoolean(true)
        val crypto = object : DiagnosticCryptoFactory {
            override fun prepare(key: ByteArray): DiagnosticHmac {
                val real = JvmDiagnosticCrypto().prepare(key)
                return object : DiagnosticHmac by real {
                    override fun clear() {
                        if (blockOnce.compareAndSet(true, false)) { entered.countDown(); check(proceed.await(3, TimeUnit.SECONDS)) }
                        real.clear()
                    }
                }
            }
        }
        val c = startedCore(crypto = crypto); val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        c.recordNormalized(h, captureEvent(), id(1), id(2), id(3))
        val owner = sessionOwner(c); val arena = privateField<TableDiagnosticsBuffer>(c, "buffer").arena
        val key = privateField<ByteArray>(c, "key"); val session = privateField<ByteArray>(c, "session")
        val aliases = privateField<TableDiagnosticsAliases>(c, "aliases")
        val contexts = privateField<Array<DiagnosticHandle?>>(c, "contexts")
        val error = AtomicReference<Throwable?>()
        val actor = Thread { try { c.discard() } catch (t: Throwable) { error.set(t) } }
        try {
            actor.start(); await(entered)
            c.stopAndSeal(); assertEquals(DiagnosticStatus.DISCARDED, c.discard())
            assertEquals(DiagnosticStatus.BUSY, c.start(syntheticBuild))
            assertTrue(key.any { it != 0.toByte() })
        } finally { proceed.countDown(); join(actor) }
        error.get()?.let { throw it }
        assertCleared(owner, arena, key, session, aliases, contexts)
        assertEquals(DiagnosticStatus.STARTED, c.start(syntheticBuild))
        assertTrue(c.active)
    }
    @Test fun sealRequestAfterPreviousOwnerLeftIsDrainedWithoutAnotherApiCall() {
        val c = startedCore(); val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        c.record(h, syntheticEvent()) // The previous writer has fully released ownership.
        val owner = sessionOwner(c)
        // Exact internal boundary reached by a delayed contention/sequence-limit request.
        // Reflective invocation is test-only; no product scheduler or waiting seam is added.
        val request = owner.javaClass.getDeclaredMethod("requestSeal", DiagnosticEnd::class.java)
        request.isAccessible = true
        request.invoke(owner, DiagnosticEnd.SEQUENCE_LIMIT)
        assertEquals(DiagnosticState.AUTO_SEALED, privateField<DiagnosticState>(owner, "state"))
        val buffer = privateField<TableDiagnosticsBuffer>(owner, "buffer")
        assertEquals(4, buffer.controlCount)
        assertEquals(DiagnosticStage.PROCESS_SCOPE_END, buffer.read(899)!!.stage)
    }
    private class BlockingCrypto : DiagnosticCryptoFactory {
        val entered = CountDownLatch(1); val proceed = CountDownLatch(1)
        override fun prepare(key: ByteArray): DiagnosticHmac {
            val real = JvmDiagnosticCrypto().prepare(key)
            return object : DiagnosticHmac {
                override fun digest(domain: Byte, recipient: ByteArray, identity: ByteArray, destination: ByteArray, offset: Int) {
                    entered.countDown()
                    check(proceed.await(3, TimeUnit.SECONDS)) { "SYNTHETIC_TIMEOUT" }
                    real.digest(domain, recipient, identity, destination, offset)
                }
                override fun clear() { real.clear() }
            }
        }
    }
    @Test fun exactlyEightAdmittedContextsAreHeldBeforeTheNinthEntry() {
        val c = startedCore(); val release = CountDownLatch(1)
        val admitted = Array(8) { CountDownLatch(1) }
        val handles = arrayOfNulls<DiagnosticHandle>(8)
        val errors = AtomicReference<Throwable?>()
        val threads = Array(8) { i ->
            Thread {
                try {
                    handles[i] = c.acquire(DiagnosticContextKind.CALLBACK)
                    assertNotNull(handles[i]); admitted[i].countDown()
                    assertTrue(release.await(3, TimeUnit.SECONDS))
                    c.release(handles[i]!!)
                } catch (t: Throwable) { errors.compareAndSet(null, t); admitted[i].countDown() }
            }
        }
        try {
            // Serialize admission, not the held lifetime: all eight remain live together.
            threads.forEachIndexed { i, t -> t.start(); await(admitted[i]); errors.get()?.let { throw it } }
            assertEquals(8, handles.count { it != null })
            val ninth = AtomicReference<DiagnosticHandle?>()
            val ninthDone = CountDownLatch(1)
            val thread9 = Thread { ninth.set(c.acquire(DiagnosticContextKind.CALLBACK)); ninthDone.countDown() }
            thread9.start(); await(ninthDone); join(thread9)
            assertNull(ninth.get()); assertFalse(c.active)
            val text = sealedText(c)
            assertTrue(text.contains("\"droppedContext\":1")); assertTrue(text.contains("\"endReason\":\"CONTEXT_LIMIT\""))
            assertTrue(text.contains("\"reasonMask\":16"))
        } finally { release.countDown(); threads.filter { it.state != Thread.State.NEW }.forEach(::join) }
        errors.get()?.let { throw it }
    }
    @Test fun contentionBelowEightIsOneCasDropWithoutContextLimit() {
        val crypto = BlockingCrypto(); val c = startedCore(crypto = crypto)
        val one = c.acquire(DiagnosticContextKind.CALLBACK)!!; val two = c.acquire(DiagnosticContextKind.CALLBACK)!!
        val result = AtomicReference<DiagnosticRecord?>()
        val writer = Thread { result.set(c.recordNormalized(one, captureEvent(), id(1), id(2))) }
        try {
            writer.start(); await(crypto.entered)
            val start = System.nanoTime()
            assertEquals(DiagnosticStatus.DROPPED, c.record(two, syntheticEvent()).status)
            assertTrue(TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - start) < 500)
            assertTrue(c.active)
        } finally { crypto.proceed.countDown(); join(writer) }
        assertEquals(DiagnosticStatus.STORED, result.get()!!.status)
        val text = sealedText(c)
        assertTrue(text.contains("\"droppedContention\":1")); assertTrue(text.contains("\"droppedContext\":0"))
        assertTrue(text.contains("\"reasonMask\":1")); assertFalse(text.contains("CONTEXT_LIMIT"))
    }
    @Test fun exportWaitIsBoundedAndOneRetryOmitsUnfinishedRecord() {
        val crypto = BlockingCrypto(); val c = startedCore(crypto = crypto)
        val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        val writer = Thread { c.recordNormalized(h, captureEvent(), id(1), id(2)) }
        try {
            writer.start(); await(crypto.entered); c.stopAndSeal()
            val start = System.nanoTime()
            assertEquals(DiagnosticStatus.EXPORT_FAILED, c.exportSafeJson().status)
            val elapsed = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - start)
            // Algorithm deadline is 50 ms; CI scheduling/VM suspension is not a hard real-time guarantee.
            assertTrue("export elapsed=$elapsed", elapsed < 500)
        } finally { crypto.proceed.countDown(); join(writer) }
        val result = c.exportSafeJson()
        assertEquals(DiagnosticStatus.EXPORTED, result.status)
        val text = String(result.bytes!!)
        assertTrue(text.contains("\"unfinishedSlots\":1")); assertTrue(text.contains("\"state\":\"INCOMPLETE\""))
        assertFalse(text.contains("\"stage\":\"CAPTURE\"")); assertTrue(text.contains("GATE_CLOSE"))
        assertEquals(DiagnosticStatus.NOT_ACTIVE, c.exportSafeJson().status)
    }
    @Test fun discardFencesBlockedWriterAndDefersZeroingUntilWriterLeaves() {
        val crypto = BlockingCrypto(); val c = startedCore(crypto = crypto)
        val old = c.acquire(DiagnosticContextKind.CALLBACK)!!
        val arena = privateField<TableDiagnosticsBuffer>(c, "buffer").arena
        val key = privateField<ByteArray>(c, "key")
        val result = AtomicReference<DiagnosticRecord?>()
        val writer = Thread { result.set(c.recordNormalized(old, captureEvent(), id(1), id(2))) }
        try {
            writer.start(); await(crypto.entered)
            assertEquals(DiagnosticStatus.DISCARDED, c.discard())
            assertFalse(c.active); assertEquals(DiagnosticStatus.BUSY, c.start(syntheticBuild))
        } finally { crypto.proceed.countDown(); join(writer) }
        assertEquals(DiagnosticStatus.STALE, result.get()!!.status)
        assertTrue(arena.all { it == 0.toByte() }); assertTrue(key.all { it == 0.toByte() })
        assertEquals(DiagnosticStatus.STARTED, c.start(syntheticBuild))
        assertEquals(DiagnosticStatus.STALE, c.record(old, syntheticEvent()).status)
        assertEquals(0, privateField<TableDiagnosticsBuffer>(c, "buffer").dataCount)
    }
    @Test fun twoExporterTimeoutsRequestDiscardWithoutOverwritingActiveWriterMemory() {
        val crypto = BlockingCrypto(); val c = startedCore(crypto = crypto)
        val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        val arena = privateField<TableDiagnosticsBuffer>(c, "buffer").arena
        val writer = Thread { c.recordNormalized(h, captureEvent(), id(1), id(2)) }
        try {
            writer.start(); await(crypto.entered); c.stopAndSeal()
            assertEquals(DiagnosticStatus.EXPORT_FAILED, c.exportSafeJson().status)
            assertEquals(DiagnosticStatus.EXPORT_FAILED, c.exportSafeJson().status)
            assertFalse(c.active); assertEquals(DiagnosticStatus.BUSY, c.start(syntheticBuild))
        } finally { crypto.proceed.countDown(); join(writer) }
        assertEquals(DiagnosticState.DISABLED, c.state)
        assertTrue(arena.all { it == 0.toByte() }); assertEquals(DiagnosticStatus.NOT_ACTIVE, c.exportSafeJson().status)
    }
    @Test fun discardDuringExportFencesTheReturnValueAndCleansMemory() {
        val entered = CountDownLatch(1); val proceed = CountDownLatch(1)
        val block = java.util.concurrent.atomic.AtomicBoolean(false)
        val clock = object : DiagnosticClock {
            override fun monotonicMs(): Long {
                if (block.compareAndSet(true, false)) { entered.countDown(); check(proceed.await(3, TimeUnit.SECONDS)) }
                return 1000
            }
            override fun wallMs() = 1000000L
        }
        val c = TableDiagnosticsCore(clock, SyntheticEntropy()); c.start(syntheticBuild); c.stopAndSeal()
        val arena = privateField<TableDiagnosticsBuffer>(c, "buffer").arena
        val result = AtomicReference<DiagnosticExport?>()
        block.set(true)
        val exportThread = Thread { result.set(c.exportSafeJson()) }
        try {
            exportThread.start(); await(entered)
            assertEquals(DiagnosticStatus.DISCARDED, c.discard())
        } finally { proceed.countDown(); join(exportThread) }
        assertEquals(DiagnosticStatus.DISCARDED, result.get()!!.status); assertNull(result.get()!!.bytes)
        assertEquals(DiagnosticState.DISABLED, c.state); assertTrue(arena.all { it == 0.toByte() })
    }
}
