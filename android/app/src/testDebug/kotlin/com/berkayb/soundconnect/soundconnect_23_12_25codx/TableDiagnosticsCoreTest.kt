package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.atomic.AtomicInteger

internal class SyntheticClock : DiagnosticClock {
    var mono = 1000L; var wall = 1_000_000L; var calls = 0
    override fun monotonicMs(): Long { calls++; return mono }
    override fun wallMs(): Long { calls++; return wall }
    fun advance(ms: Long) { mono += ms; wall += ms }
}
internal class SyntheticEntropy : DiagnosticEntropy {
    var calls = 0
    override fun fill(destination: ByteArray) { calls++; destination.indices.forEach { destination[it] = (it + 40 + calls).toByte() } }
}
internal fun startedCore(clock: SyntheticClock = SyntheticClock(), crypto: DiagnosticCryptoFactory = JvmDiagnosticCrypto()): TableDiagnosticsCore =
    TableDiagnosticsCore(clock, SyntheticEntropy(), crypto).also { assertEquals(DiagnosticStatus.STARTED, it.start(syntheticBuild)) }
internal fun captureEvent() = TableDiagnosticEvent(stage = DiagnosticStage.CAPTURE, family = DiagnosticFamily.TABLE_VALID,
    version = DiagnosticVersion.ANDROID_TABLE_V1, type = DiagnosticType.TABLE_EXPIRED, variant = DiagnosticVariant.DEFAULT, result = DiagnosticResult.ALLOW)
internal fun id(value: Int) = ByteArray(16).also { it[0] = value.toByte(); it[1] = (value ushr 8).toByte() }
internal fun sealedText(core: TableDiagnosticsCore): String {
    core.stopAndSeal()
    val result = core.exportSafeJson()
    assertEquals(DiagnosticStatus.EXPORTED, result.status)
    return String(result.bytes!!, Charsets.US_ASCII)
}
internal fun <T> privateField(instance: Any, name: String): T {
    // Inspect either layout so the identical regressions also run against the Review36 baseline.
    val f = instance.javaClass.declaredFields.firstOrNull { it.name == name }
    if (f != null) {
        f.isAccessible = true
        @Suppress("UNCHECKED_CAST") return f.get(instance) as T
    }
    val current = instance.javaClass.getDeclaredField("current").also { it.isAccessible = true }
        .get(instance) as java.util.concurrent.atomic.AtomicReference<*>
    val session = current.get()
    @Suppress("UNCHECKED_CAST") return if (session == null) null as T else privateField(session, name)
}

class TableDiagnosticsCoreTest {
    @Test fun defaultOffCallsNoClockEntropyCryptoOrSlotAllocator() {
        val clock = SyntheticClock(); val random = SyntheticEntropy(); var cryptoCalls = 0
        val factory = object : DiagnosticCryptoFactory { override fun prepare(key: ByteArray): DiagnosticHmac { cryptoCalls++; error("synthetic") } }
        val c = TableDiagnosticsCore(clock, random, factory)
        val h = DiagnosticHandle(0, 0, 1, 0)
        assertFalse(c.active); assertNull(c.acquire(DiagnosticContextKind.CALLBACK))
        assertEquals(DiagnosticStatus.NOT_ACTIVE, c.record(h, syntheticEvent()).status)
        assertEquals(DiagnosticStatus.NOT_ACTIVE, c.recordNormalized(h, captureEvent(), id(1), id(2)).status)
        assertFalse(c.enter(h)); c.release(h); c.tick(); c.stopAndSeal(); c.discard(); c.exportSafeJson()
        assertEquals(0, clock.calls); assertEquals(0, random.calls); assertEquals(0, cryptoCalls)
        assertNull(privateField<Any?>(c, "buffer"))
    }
    @Test fun allNonDebugAndPreviewAndWrongPackageGatesStayInert() {
        val clock = SyntheticClock(); val random = SyntheticEntropy(); val c = TableDiagnosticsCore(clock, random)
        val rejected = listOf(syntheticBuild.copy(mode = DiagnosticBuildMode.RELEASE), syntheticBuild.copy(mode = DiagnosticBuildMode.PROFILE),
            syntheticBuild.copy(debuggable = false), syntheticBuild.copy(preview = true), syntheticBuild.copy(packageKind = DiagnosticPackage.PREVIEW),
            syntheticBuild.copy(packageKind = DiagnosticPackage.OTHER))
        rejected.forEach { assertEquals(DiagnosticStatus.DISABLED, c.start(it)) }
        assertEquals(0, clock.calls); assertEquals(0, random.calls)
    }
    @Test fun activeExportRejectedAndSingleSessionCannotBeReplaced() {
        val c = startedCore()
        assertEquals(DiagnosticStatus.BUSY, c.start(syntheticBuild))
        assertEquals(DiagnosticStatus.NOT_SEALED, c.exportSafeJson().status)
        assertEquals(DiagnosticStatus.SEALED, c.stopAndSeal())
        assertEquals(DiagnosticStatus.BUSY, c.start(syntheticBuild))
        assertEquals(DiagnosticStatus.EXPORTED, c.exportSafeJson().status)
        assertEquals(DiagnosticStatus.NOT_ACTIVE, c.exportSafeJson().status)
        assertEquals(DiagnosticState.DISABLED, c.state)
        assertEquals(DiagnosticStatus.STARTED, c.start(syntheticBuild))
    }
    @Test fun exportAndDiscardZeroBufferAliasScratchAndSessionKey() {
        for (export in listOf(true, false)) {
            val c = startedCore(); val b = privateField<TableDiagnosticsBuffer>(c, "buffer")
            val key = privateField<ByteArray>(c, "key"); val session = privateField<ByteArray>(c, "session")
            val a = privateField<TableDiagnosticsAliases>(c, "aliases")
            val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
            assertEquals(1, c.recordNormalized(h, captureEvent(), id(1), id(2), id(3)).notification)
            if (export) sealedText(c) else c.discard()
            assertTrue(b.arena.all { it == 0.toByte() }); assertTrue(key.all { it == 0.toByte() }); assertTrue(session.all { it == 0.toByte() })
            assertEquals(0, a.notifications); assertEquals(0, a.scopes)
            assertNull(privateField<Any?>(c, "aliases")); assertNull(privateField<Any?>(c, "buffer"))
        }
    }
    @Test fun restartCreatesAnInertInstanceAndOldGenerationNeverWritesNewSession() {
        val clock = SyntheticClock(); val c = startedCore(clock); val old = c.acquire(DiagnosticContextKind.CALLBACK)!!
        val oldSession = privateField<ByteArray>(c, "session").copyOf()
        c.discard(); assertEquals(DiagnosticStatus.STARTED, c.start(syntheticBuild))
        assertEquals(DiagnosticStatus.STALE, c.record(old, syntheticEvent()).status)
        assertFalse(oldSession.contentEquals(privateField<ByteArray>(c, "session")))
        val fresh = TableDiagnosticsCore(clock, SyntheticEntropy())
        assertFalse(fresh.active); assertEquals(DiagnosticState.DISABLED, fresh.state)
        assertNull(privateField<Any?>(fresh, "process"))
    }
    @Test fun deadlineIsEnforcedOnRecordAt600000WithoutTick() {
        val clock = SyntheticClock(); val c = startedCore(clock); val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        clock.advance(599999)
        assertEquals(DiagnosticStatus.STORED, c.record(h, syntheticEvent()).status)
        clock.advance(1)
        assertEquals(DiagnosticStatus.NOT_ACTIVE, c.record(h, syntheticEvent()).status)
        assertEquals(DiagnosticState.AUTO_SEALED, c.state)
        assertTrue(sealedText(c).contains("\"endReason\":\"TIME_LIMIT\""))
    }
    @Test fun watchdogHeartbeatUsesExplicitTickAndDoesNotBackfill() {
        val clock = SyntheticClock(); val c = startedCore(clock)
        clock.advance(999); c.tick()
        assertEquals(2, privateField<TableDiagnosticsBuffer>(c, "buffer").controlCount)
        clock.advance(1); c.tick()
        repeat(599) { clock.advance(1000); c.tick() }
        val text = sealedText(c)
        val count = Regex("\"stage\":\"HEARTBEAT\"").findAll(text).count()
        assertEquals(59, count); assertTrue(count <= 60)
        assertTrue(text.contains("TIME_LIMIT"))
    }
    @Test fun skippedTicksProduceOneObservedHeartbeatRatherThanInventedHistory() {
        val clock = SyntheticClock(); val c = startedCore(clock)
        clock.advance(200000); c.tick()
        assertEquals(1, Regex("\"stage\":\"HEARTBEAT\"").findAll(sealedText(c)).count())
    }
    @Test fun wallChangesDoNotExtendCollectionOrRetentionAndClampsAreVisible() {
        val clock = SyntheticClock(); val c = startedCore(clock); val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        clock.wall += 2000; c.record(h, syntheticEvent())
        assertEquals(2, privateField<TableDiagnosticsBuffer>(c, "buffer").controlCount)
        clock.wall += 2001; c.record(h, syntheticEvent())
        clock.wall = Long.MAX_VALUE; c.record(h, syntheticEvent())
        clock.mono += 600000; c.record(h, syntheticEvent())
        val text = sealedText(c)
        assertTrue(text.contains("CLOCK_DISCONTINUITY")); assertTrue(text.contains("\"timeFlags\":8"))
        assertTrue(text.contains("\"wallDeltaMs\":604800000")); assertTrue(text.contains("TIME_LIMIT"))
    }
    @Test fun sealedRetentionHasExact300000MonotonicBoundary() {
        val clock = SyntheticClock(); val c = startedCore(clock); c.stopAndSeal()
        clock.advance(299999); clock.wall = 0
        assertEquals(DiagnosticStatus.SEALED, c.tick())
        clock.advance(1)
        assertEquals(DiagnosticStatus.DISCARDED, c.tick())
        assertEquals(DiagnosticStatus.NOT_ACTIVE, c.exportSafeJson().status)
        assertNull(privateField<Any?>(c, "buffer"))
    }
    @Test fun exportAlsoEnforcesRetentionWithoutTick() {
        val clock = SyntheticClock(); val c = startedCore(clock); c.stopAndSeal(); clock.advance(300000)
        assertEquals(DiagnosticStatus.NOT_ACTIVE, c.exportSafeJson().status)
        assertEquals(DiagnosticState.DISABLED, c.state)
    }
    @Test fun failedStartIsDisabledAndHasNoAutomaticRetry() {
        var attempts = 0
        val factory = object : DiagnosticCryptoFactory { override fun prepare(key: ByteArray): DiagnosticHmac { attempts++; throw IllegalStateException("SYNTHETIC_EXCEPTION_TOKEN_BODY") } }
        val c = TableDiagnosticsCore(SyntheticClock(), SyntheticEntropy(), factory)
        assertEquals(DiagnosticStatus.UNKNOWN, c.start(syntheticBuild)); assertFalse(c.active)
        repeat(4) { c.tick(); c.exportSafeJson() }
        assertEquals(1, attempts); assertNull(privateField<Any?>(c, "key")); assertNull(privateField<Any?>(c, "buffer"))
    }
    @Test fun twoFailedExportsDiscardButFirstKeepsSealedBufferForOneRetry() {
        val c = TableDiagnosticsCore(SyntheticClock(), SyntheticEntropy(), json = TableDiagnosticsJson(DiagnosticJsonLimits(header = 1)))
        c.start(syntheticBuild); c.stopAndSeal()
        assertEquals(DiagnosticStatus.EXPORT_FAILED, c.exportSafeJson().status)
        assertEquals(DiagnosticState.SEALED, c.state)
        assertEquals(DiagnosticStatus.EXPORT_FAILED, c.exportSafeJson().status)
        assertEquals(DiagnosticState.DISABLED, c.state)
        assertEquals(DiagnosticStatus.NOT_ACTIVE, c.exportSafeJson().status)
    }
    @Test fun callback128AndOperation512AreAdmittedButPlusOneSeals() {
        for ((kind, max) in listOf(DiagnosticContextKind.CALLBACK to 128, DiagnosticContextKind.OPERATION to 512)) {
            val c = startedCore()
            repeat(max) { val h = c.acquire(kind); assertNotNull(h); assertEquals(it + 1, if (kind == DiagnosticContextKind.CALLBACK) h!!.callback else h!!.operation); c.release(h!!) }
            assertTrue(c.active); assertNull(c.acquire(kind)); assertFalse(c.active)
            assertTrue(sealedText(c).contains("\"endReason\":\"SEQUENCE_LIMIT\""))
        }
    }
    @Test fun eachCallbackAndOperationHasExactly64EventBudget() {
        for (kind in DiagnosticContextKind.entries) {
            val c = startedCore(); val h = c.acquire(kind)!!
            repeat(64) { assertEquals(DiagnosticStatus.STORED, c.record(h, syntheticEvent()).status) }
            assertEquals(DiagnosticStatus.DROPPED, c.record(h, syntheticEvent()).status)
            assertTrue(c.active)
            val text = sealedText(c)
            assertTrue(text.contains("\"droppedCallback\":1")); assertTrue(text.contains("\"reasonMask\":4"))
        }
    }
    @Test fun data896SealsWithoutOverwriteAndKeepsTwoClosingRecords() {
        val c = startedCore()
        repeat(14) {
            val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
            repeat(64) { assertEquals(DiagnosticStatus.STORED, c.record(h, syntheticEvent()).status) }
            c.release(h)
        }
        assertFalse(c.active)
        val b = privateField<TableDiagnosticsBuffer>(c, "buffer")
        assertEquals(896, b.dataCount); assertEquals(4, b.controlCount)
        val text = sealedText(c)
        assertEquals(900, Regex("\"seq\":").findAll(text).count())
        assertTrue(text.contains("GATE_CLOSE")); assertTrue(text.contains("PROCESS_SCOPE_END")); assertTrue(text.contains("BUFFER_FULL"))
    }
    @Test fun control126SealsWithTheTwoReservedClosingSlots() {
        val clock = SyntheticClock(); val c = startedCore(clock)
        repeat(124) { clock.advance(1000); clock.wall += 3000; c.tick() }
        assertFalse(c.active)
        assertEquals(128, privateField<TableDiagnosticsBuffer>(c, "buffer").controlCount)
        val text = sealedText(c)
        assertTrue(text.contains("GATE_CLOSE")); assertTrue(text.contains("BUFFER_FULL"))
    }
    @Test fun notificationAliases64And65WithoutEviction() {
        val c = startedCore()
        repeat(64) {
            val h = c.acquire(DiagnosticContextKind.OPERATION)!!
            assertEquals(it + 1, c.recordNormalized(h, captureEvent(), id(1), id(it + 10)).notification); c.release(h)
        }
        val h = c.acquire(DiagnosticContextKind.OPERATION)!!
        assertEquals(1, c.recordNormalized(h, captureEvent(), id(1), id(10)).notification)
        assertEquals(DiagnosticStatus.UNKNOWN, c.recordNormalized(h, captureEvent(), id(1), id(1000)).status)
        val text = sealedText(c)
        assertTrue(text.contains("ALIAS_LIMIT")); assertTrue(text.contains("\"droppedAlias\":1"))
    }
    @Test fun scope16And17DoNotChangeNotificationAlias() {
        val c = startedCore(); val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        repeat(16) {
            val result = c.recordNormalized(h, captureEvent(), id(1), id(2), id(it + 3))
            assertEquals(1, result.notification); assertEquals(it + 1, result.scope)
        }
        assertEquals(1, c.recordNormalized(h, captureEvent(), id(1), id(2), id(3)).scope)
        assertEquals(DiagnosticStatus.UNKNOWN, c.recordNormalized(h, captureEvent(), id(1), id(2), id(100)).status)
        assertTrue(sealedText(c).contains("ALIAS_LIMIT"))
    }
    @Test fun aliasPairIncludesRecipientAndRequiresSuccessfulTypedInput() {
        val c = startedCore(); val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        assertEquals(DiagnosticStatus.UNKNOWN, c.recordNormalized(h, syntheticEvent(), id(1), id(2)).status)
        assertEquals(DiagnosticStatus.UNKNOWN, c.recordNormalized(h, captureEvent(), ByteArray(15), id(2)).status)
        assertEquals(0, privateField<TableDiagnosticsAliases>(c, "aliases").notifications)
        assertEquals(1, c.recordNormalized(h, captureEvent(), id(1), id(2)).notification)
        assertEquals(1, c.recordNormalized(h, captureEvent(), id(1), id(2)).notification)
        assertEquals(2, c.recordNormalized(h, captureEvent(), id(3), id(2)).notification)
    }
    @Test fun hmacFailureIsTypedUnknownAndNeverExportsExceptionOrIdentity() {
        val factory = object : DiagnosticCryptoFactory {
            override fun prepare(key: ByteArray) = object : DiagnosticHmac {
                override fun digest(domain: Byte, recipient: ByteArray, identity: ByteArray, destination: ByteArray, offset: Int) { throw IllegalArgumentException("SYNTHETIC_TOKEN_BODY_STACK") }
                override fun clear() {}
            }
        }
        val c = startedCore(crypto = factory); val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        assertEquals(DiagnosticStatus.UNKNOWN, c.recordNormalized(h, captureEvent(), id(1), id(2)).status)
        val text = sealedText(c)
        assertTrue(text.contains("RECORD_FAILURE")); assertTrue(text.contains("\"unfinishedSlots\":1"))
        assertFalse(text.contains("SYNTHETIC_TOKEN_BODY_STACK")); assertFalse(text.contains("IllegalArgumentException"))
    }
    @Test fun domainSeparatedHmacUsesKnownJcaOracleAndNoDigestIsExported() {
        val arena = ByteArray(TableDiagnosticsBuffer.ARENA_BYTES); val key = ByteArray(32) { (it + 10).toByte() }
        val aliases = TableDiagnosticsAliases(arena, JvmDiagnosticCrypto(), key)
        val c = aliases.prepare(0, id(1), id(2), id(2))!!; aliases.commit(0, c)
        val mac = javax.crypto.Mac.getInstance("HmacSHA256"); mac.init(javax.crypto.spec.SecretKeySpec(key, "HmacSHA256"))
        mac.update(1.toByte()); mac.update(id(1)); val expected = mac.doFinal(id(2))
        assertArrayEquals(expected, arena.copyOfRange(TableDiagnosticsBuffer.ALIASES, TableDiagnosticsBuffer.ALIASES + 32))
        assertFalse(expected.contentEquals(arena.copyOfRange(TableDiagnosticsBuffer.SCOPES, TableDiagnosticsBuffer.SCOPES + 32)))
        aliases.clear(); assertTrue(arena.all { it == 0.toByte() })
    }
    @Test fun privacyCanariesAreAbsentAndSurfaceHasNoAdHocObjectOrStringFields() {
        val c = startedCore(); val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        val recipient = "SYNTH_RECIPIENT!".toByteArray(); val notification = "SYNTH_NOTIFY_ID!".toByteArray()
        val key = privateField<ByteArray>(c, "key").copyOf()
        assertEquals(16, recipient.size); assertEquals(16, notification.size)
        c.recordNormalized(h, captureEvent(), recipient, notification, id(1))
        val digest = privateField<TableDiagnosticsBuffer>(c, "buffer").arena.copyOfRange(TableDiagnosticsBuffer.ALIASES, TableDiagnosticsBuffer.ALIASES + 32)
        val text = sealedText(c)
        for (canary in listOf(String(recipient), String(notification), "11111111-2222-3333-4444-555555555555", "SYNTHETIC_TOKEN", "exceptionBody", "stackTrace",
            key.joinToString("") { "%02x".format(it) }, digest.joinToString("") { "%02x".format(it) })) assertFalse(text.contains(canary))
        val fields = TableDiagnosticEvent::class.java.declaredFields.filter { !java.lang.reflect.Modifier.isStatic(it.modifiers) }
        assertTrue(fields.all { it.type.isPrimitive || it.type.isEnum || it.type == java.lang.Long::class.java })
        assertFalse(TableDiagnosticsCore::class.java.declaredMethods.any { it.name == "matchExact" })
        assertFalse(TableDiagnosticsCore::class.java.declaredMethods.any { method -> method.parameterTypes.any { it.name.startsWith("kotlin.jvm.functions") } })
        println("SYNTHETIC_JSON=$text")
    }
    @Test fun nestedDepth4AcceptedAnd5DropsAndSeals() {
        val c = startedCore(); val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        repeat(3) { assertTrue(c.enter(h)) }
        assertFalse(c.enter(h)); assertFalse(c.active)
        val text = sealedText(c)
        assertTrue(text.contains("CONTEXT_LIMIT")); assertTrue(text.contains("\"droppedContext\":1"))
    }
    @Test fun sequenceCeilingDoesNotInventClosingRecords() {
        val c = startedCore(); val h = c.acquire(DiagnosticContextKind.CALLBACK)!!
        privateField<AtomicInteger>(c, "sequence").set(999999) // synthetic boundary, not an exposed core API
        assertEquals(1000000, c.record(h, syntheticEvent()).seq)
        assertEquals(DiagnosticStatus.DROPPED, c.record(h, syntheticEvent()).status)
        val text = sealedText(c)
        assertTrue(text.contains("\"state\":\"INCOMPLETE\"")); assertTrue(text.contains("SEQUENCE_LIMIT"))
        assertFalse(text.contains("\"stage\":\"GATE_CLOSE\""))
    }
    @Test fun health65535SaturatesOnPlusOneAndGapUnionIsVisible() {
        val h = DiagnosticHealth()
        repeat(65535) { h.bump(DiagnosticHealthCounter.attempted) }
        assertEquals(65535, h.count(DiagnosticHealthCounter.attempted)); assertFalse(h.saturated.get())
        h.bump(DiagnosticHealthCounter.attempted); assertEquals(65535, h.count(DiagnosticHealthCounter.attempted)); assertTrue(h.saturated.get())
        h.gap(1); h.gap(128); assertEquals(129, h.mask())
    }
    @Test fun sessionLabelsRotateButProcessLabelIsStableWithinTheCoreInstance() {
        val c = startedCore()
        val process = privateField<ByteArray>(c, "process").copyOf()
        val session = privateField<ByteArray>(c, "session").copyOf()
        sealedText(c)
        assertEquals(DiagnosticStatus.STARTED, c.start(syntheticBuild))
        assertArrayEquals(process, privateField<ByteArray>(c, "process"))
        assertFalse(session.contentEquals(privateField<ByteArray>(c, "session")))
    }
}
