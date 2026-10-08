package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder

internal val syntheticBuild = DiagnosticBuild(DiagnosticBuildMode.DEBUG, DiagnosticPackage.PRIMARY, true, false, 0x1234, DiagnosticApi.API33_PLUS)
internal fun syntheticEvent() = TableDiagnosticEvent(stage = DiagnosticStage.CALLBACK_START)
internal fun syntheticPresence() = TableDiagnosticEvent(seq = 16, parent = 13, callback = 1, operation = 1, notification = 1,
    monoMs = 1306, wallDeltaMs = 1306, stage = DiagnosticStage.PRESENCE, source = DiagnosticSource.DIAGNOSTIC_CONTROL,
    family = DiagnosticFamily.TABLE_VALID, version = DiagnosticVersion.ANDROID_TABLE_V1, type = DiagnosticType.TABLE_EXPIRED,
    variant = DiagnosticVariant.DEFAULT, evaluated = 1L shl 22, truths = 1L shl 22,
    result = DiagnosticResult.RETURN, reason = DiagnosticReason.SAMPLE_DELAYED,
    child = DiagnosticPresence.PRESENT, summary = DiagnosticPresence.PRESENT,
    count = 2, attempt = 1, dueMs = 1250, sampleMs = 1300)
internal fun syntheticBuffer(vararg events: TableDiagnosticEvent): TableDiagnosticsBuffer {
    val b = TableDiagnosticsBuffer()
    for ((i, e) in events.withIndex()) { val slot = b.reserve(i >= 896, true); b.write(slot, e); assertTrue(b.commit(slot)) }
    return b
}
internal fun syntheticExport(b: TableDiagnosticsBuffer, json: TableDiagnosticsJson = TableDiagnosticsJson()) =
    json.export(b, DiagnosticHealth(), DiagnosticState.SEALED, DiagnosticEnd.MANUAL, ByteArray(16) { 1 }, ByteArray(16) { 2 }, syntheticBuild, 10)

class TableDiagnosticsSchemaTest {
    private fun invalid(body: () -> Unit) { assertThrows(IllegalArgumentException::class.java, body) }
    private fun roundTrip(e: TableDiagnosticEvent): TableDiagnosticEvent {
        val bytes = ByteArray(128)
        TableDiagnosticsCodec.encode(e, bytes, 0)
        val decoded = TableDiagnosticsCodec.decode(bytes, 0)
        assertEquals(e, decoded)
        return decoded
    }
    @Test fun all33FieldsRoundTripWithNumericAndEnumBoundaries() {
        roundTrip(syntheticPresence().copy(seq = 1_000_000, parent = 999_999, callback = 128, operation = 512,
            notification = 64, monoMs = 900000, wallDeltaMs = -604800000, keyMask = 127, unknownKeys = 8,
            evaluated = 0xFFFFFF, truths = 0x800000, errors = 0x400000,
            sentDeltaMs = -2419200000, expiryDeltaMs = 2419200000, lifetimeMs = 2419200000, timeFlags = 15,
            count = 4, attempt = 3, dueMs = 599998, sampleMs = 599999))
    }
    @Test fun littleEndianUnsignedAndNullSentinelsAreExact() {
        val bytes = ByteArray(128) { 99 }
        val e = syntheticEvent().copy(seq = 0x12345, callback = 128, operation = 512, evaluated = 0x800000)
        TableDiagnosticsCodec.encode(e, bytes, 0)
        assertEquals(0x45, bytes[0].toInt() and 255)
        assertEquals(128, bytes[8].toInt() and 255)
        assertEquals(0, bytes[9].toInt() and 255); assertEquals(2, bytes[10].toInt() and 255)
        val b = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(Long.MIN_VALUE, b.getLong(40)); assertEquals(-1, b.getInt(74)); assertEquals(-1, b.getInt(78))
        assertTrue(bytes.sliceArray(82..127).all { it == 0.toByte() })
        assertEquals(e, TableDiagnosticsCodec.decode(bytes, 0))
    }
    @Test fun everyEnumCodecOrdinalRoundTripsInAValidStage() {
        for (reason in listOf(DiagnosticReason.TYPE_MISSING, DiagnosticReason.LIFETIME_TOO_LONG, DiagnosticReason.PARSE_ACCEPTED)) {
            roundTrip(TableDiagnosticEvent(stage = DiagnosticStage.PARSE, reason = reason,
                result = if (reason == DiagnosticReason.PARSE_ACCEPTED) DiagnosticResult.ALLOW else DiagnosticResult.REJECT))
        }
        for (type in DiagnosticType.entries) for (variant in DiagnosticVariant.entries) roundTrip(syntheticEvent().copy(type = type, variant = variant))
        for (source in DiagnosticSource.entries) for (family in DiagnosticFamily.entries) roundTrip(syntheticEvent().copy(source = source, family = family))
        for (exception in DiagnosticException.entries) roundTrip(TableDiagnosticEvent(stage = DiagnosticStage.PREPARE,
            result = DiagnosticResult.EXCEPTION, reason = DiagnosticReason.PREPARATION_ERROR, exception = exception, phase = DiagnosticPhase.PREPARE))
    }
    @Test fun rejectsEveryNumericLimitPlusOne() {
        val e = syntheticEvent()
        val cases: List<() -> Unit> = listOf({ e.copy(seq = 0) }, { e.copy(seq = 1000001) }, { e.copy(parent = 1) }, { e.copy(parent = -1) },
            { e.copy(callback = 129) }, { e.copy(operation = 513) }, { e.copy(notification = 65) }, { e.copy(monoMs = 900001) },
            { e.copy(wallDeltaMs = -604800001) }, { e.copy(keyMask = 128) }, { e.copy(unknownKeys = 9) }, { e.copy(timeFlags = 16) },
            { e.copy(count = 101) }, { e.copy(attempt = 4) }, { e.copy(sentDeltaMs = -2419200001) },
            { e.copy(expiryDeltaMs = 2419200001) }, { e.copy(lifetimeMs = -1) }, { e.copy(lifetimeMs = 2419200001) })
        cases.forEach { invalid(it) }
    }
    @Test fun masksAreUnsignedButOnlyBits0Through23AreAllowed() {
        roundTrip(syntheticEvent().copy(evaluated = 0xFFFFFF, truths = 0x800000, errors = 0x400000))
        invalid { syntheticEvent().copy(evaluated = 0x80000000) }
        invalid { syntheticEvent().copy(evaluated = 0xFFFFFFFF) }
        invalid { syntheticEvent().copy(evaluated = -1) }
        invalid { syntheticEvent().copy(truths = 1) }
        invalid { syntheticEvent().copy(evaluated = 1, truths = 1, errors = 1) }
    }
    @Test fun malformedBinaryIsRejectedRatherThanNormalized() {
        val bytes = ByteArray(128); TableDiagnosticsCodec.encode(syntheticEvent(), bytes, 0)
        bytes[82] = 1; invalid { TableDiagnosticsCodec.decode(bytes, 0) }
        bytes[82] = 0; bytes[8] = 129.toByte(); invalid { TableDiagnosticsCodec.decode(bytes, 0) }
        bytes[8] = 0; ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).putInt(28, Int.MIN_VALUE)
        invalid { TableDiagnosticsCodec.decode(bytes, 0) }
    }
    @Test fun stageReasonPhaseAndExceptionMismatchesAreRejected() {
        invalid { syntheticEvent().copy(reason = DiagnosticReason.COMMIT_RETURN) }
        invalid { syntheticEvent().copy(phase = DiagnosticPhase.END_TX) }
        invalid { TableDiagnosticEvent(stage = DiagnosticStage.PARSE, reason = DiagnosticReason.CANCEL_RETURN) }
        invalid { TableDiagnosticEvent(stage = DiagnosticStage.RESERVE_TX, reason = DiagnosticReason.COMMIT_RETURN, phase = DiagnosticPhase.SET_SUCCESSFUL, result = DiagnosticResult.RETURN) }
        invalid { syntheticEvent().copy(exception = DiagnosticException.SECURITY) }
        invalid { TableDiagnosticEvent(stage = DiagnosticStage.CANCEL, reason = DiagnosticReason.CANCEL_RETURN, result = DiagnosticResult.ATTEMPT) }
        invalid { TableDiagnosticEvent(stage = DiagnosticStage.PARSE, reason = DiagnosticReason.PARSE_ACCEPTED, result = DiagnosticResult.REJECT) }
        roundTrip(TableDiagnosticEvent(stage = DiagnosticStage.RESERVE_TX, reason = DiagnosticReason.COMMIT_RETURN,
            phase = DiagnosticPhase.END_TX, result = DiagnosticResult.RETURN))
    }
    @Test fun dueAndSampleBoundsAndNonPresenceNullability() {
        val plan = syntheticPresence().copy(result = DiagnosticResult.ALLOW, reason = DiagnosticReason.SAMPLE_PLAN,
            phase = DiagnosticPhase.SCHEDULE, sampleMs = null, count = 0, dueMs = 601999,
            child = DiagnosticPresence.NOT_SAMPLED, summary = DiagnosticPresence.NOT_SAMPLED)
        roundTrip(plan)
        invalid { plan.copy(dueMs = 602000) }
        roundTrip(syntheticPresence().copy(monoMs = 599999, sampleMs = 599999))
        invalid { syntheticPresence().copy(sampleMs = 600000) }
        invalid { syntheticEvent().copy(dueMs = 0) }
        invalid { syntheticEvent().copy(sampleMs = 0) }
        invalid { syntheticPresence().copy(sampleMs = 1249) }
        invalid { syntheticPresence().copy(monoMs = 1299) }
        invalid { syntheticPresence().copy(count = 0) }
        invalid { syntheticPresence().copy(reason = DiagnosticReason.SAMPLE_ON_TIME) }
    }
    @Test fun planSkipAndSampleCannotMasqueradeAsEachOther() {
        invalid { syntheticPresence().copy(reason = DiagnosticReason.SAMPLE_PLAN, phase = DiagnosticPhase.SCHEDULE) }
        val skip = syntheticPresence().copy(result = DiagnosticResult.SKIP, reason = DiagnosticReason.SAMPLE_DEADLINE,
            dueMs = 601000, sampleMs = null, count = 0, child = DiagnosticPresence.NOT_SAMPLED, summary = DiagnosticPresence.NOT_SAMPLED)
        roundTrip(skip)
        invalid { skip.copy(child = DiagnosticPresence.ABSENT) }
        invalid { skip.copy(sampleMs = 5000) }
        roundTrip(syntheticPresence().copy(reason = DiagnosticReason.SCOPE_CHANGED, truths = 0,
            child = DiagnosticPresence.UNKNOWN, summary = DiagnosticPresence.UNKNOWN))
        invalid { syntheticPresence().copy(reason = DiagnosticReason.SCOPE_CHANGED) }
    }
    @Test fun documentedDelayedEventHasExactKeysAndMeasuredBytes() {
        val encoded = TableDiagnosticsJson().event(syntheticPresence())
        val keys = Regex("\"([^\"]+)\":").findAll(encoded).map { it.groupValues[1] }.toList()
        assertEquals(33, keys.size); assertEquals(33, keys.toSet().size)
        assertEquals(33, TableDiagnosticEvent::class.java.declaredFields.count { !java.lang.reflect.Modifier.isStatic(it.modifiers) })
        assertEquals(encoded.length, encoded.toByteArray(Charsets.UTF_8).size)
        // Exact independently supplied document fixture is compared, not only the number 574.
        assertEquals(574, encoded.toByteArray(Charsets.UTF_8).size)
        println("MEASURED_DELAYED_EVENT_BYTES=" + encoded.length)
    }
    @Test fun independentMaximumWidthCalculationUsesActualEnumSpellings() {
        val example = TableDiagnosticsJson().event(syntheticPresence())
        val widths = linkedMapOf<String, String>()
        Regex("\"([^\"]+)\":([^,}]+)").findAll(example).forEach { widths[it.groupValues[1]] = it.groupValues[2] }
        fun longest(key: String, values: List<Enum<*>>) { widths[key] = "\"" + values.maxBy { it.name.length }.name + "\"" }
        longest("stage", DiagnosticStage.entries); longest("source", DiagnosticSource.entries); longest("family", DiagnosticFamily.entries)
        longest("version", DiagnosticVersion.entries); longest("type", DiagnosticType.entries); longest("variant", DiagnosticVariant.entries)
        longest("result", DiagnosticResult.entries); longest("reason", DiagnosticReason.entries); longest("exception", DiagnosticException.entries)
        longest("phase", DiagnosticPhase.entries); longest("target", DiagnosticTarget.entries); longest("child", DiagnosticPresence.entries); longest("summary", DiagnosticPresence.entries)
        mapOf("seq" to "1000000", "parent" to "999999", "callback" to "128", "operation" to "512", "notification" to "64",
            "monoMs" to "900000", "wallDeltaMs" to "-604800000", "keyMask" to "127", "unknownKeys" to "8",
            "evaluated" to "4294967295", "truths" to "4294967295", "errors" to "4294967295", "sentDeltaMs" to "-2419200000",
            "expiryDeltaMs" to "-2419200000", "lifetimeMs" to "2419200000", "timeFlags" to "15", "count" to "100",
            "attempt" to "3", "dueMs" to "601999", "sampleMs" to "599999").forEach { (k,v) -> widths[k] = if (k in listOf("dueMs", "sampleMs", "sentDeltaMs", "expiryDeltaMs", "lifetimeMs") && v.length < 4) "null" else v }
        val width = widths.entries.joinToString(",", "{", "}") { "\"${it.key}\":${it.value}" }.toByteArray(Charsets.UTF_8).size
        assertTrue(width >= example.length); assertTrue(width <= 1024)
        println("MEASURED_INDEPENDENT_WIDTH_BYTES=$width; width candidate is not a semantically valid event")
    }
    @Test fun serializerRejectsEventHeaderAndTotalOverBudgets() {
        val e = syntheticEvent()
        val measured = TableDiagnosticsJson().event(e).length
        assertEquals(measured, TableDiagnosticsJson(DiagnosticJsonLimits(event = measured)).event(e).length)
        invalid { TableDiagnosticsJson(DiagnosticJsonLimits(event = measured - 1)).event(e) }
        invalid { syntheticExport(syntheticBuffer(e), TableDiagnosticsJson(DiagnosticJsonLimits(header = 1))) }
        val complete = syntheticExport(syntheticBuffer(e))
        assertArrayEquals(complete, syntheticExport(syntheticBuffer(e), TableDiagnosticsJson(DiagnosticJsonLimits(total = complete.size))))
        invalid { syntheticExport(syntheticBuffer(e), TableDiagnosticsJson(DiagnosticJsonLimits(total = complete.size - 1))) }
        invalid { DiagnosticJsonLimits(total = 1100001) }
    }
    @Test fun full1024SlotExportHasAnActualByteMeasurement() {
        val b = TableDiagnosticsBuffer()
        repeat(1024) { val s = b.reserve(it >= 896, true); b.write(s, syntheticEvent().copy(seq = it + 1)); assertTrue(b.commit(s)) }
        assertEquals(-1, b.reserve(false)); assertEquals(-1, b.reserve(true, true))
        val bytes = syntheticExport(b)
        assertTrue(bytes.size <= 1100000)
        assertEquals(1024, Regex("\"seq\":").findAll(String(bytes)).count())
        println("MEASURED_FULL_BUFFER_EXPORT_BYTES=${bytes.size}")
    }
    @Test fun unfinishedSlotsNeverBecomeEventsAndCorruptCommittedSlotsRejectExport() {
        val b = syntheticBuffer(syntheticEvent())
        val unfinished = b.reserve(false)
        b.write(unfinished, syntheticEvent().copy(seq = 2))
        assertEquals(1, b.abandonUnfinished()); assertFalse(b.commit(unfinished))
        assertEquals(1, Regex("\"seq\":").findAll(String(syntheticExport(b))).count())
        b.arena[82] = 1
        invalid { syntheticExport(b) }
    }
    @Test fun controlCapacityKeepsTwoClosureSlots() {
        val b = TableDiagnosticsBuffer()
        repeat(126) { assertTrue(b.reserve(true) >= 896) }
        assertEquals(-1, b.reserve(true))
        assertEquals(1022, b.reserve(true, true)); assertEquals(1023, b.reserve(true, true)); assertEquals(-1, b.reserve(true, true))
        assertEquals(0, b.dataCount)
    }
    @Test fun binaryBudgetAndFixedSlotCountAreConcrete() {
        assertEquals(82 + 46, TableDiagnosticsCodec.SLOT_BYTES)
        assertEquals(131072, TableDiagnosticsBuffer.EVENT_BYTES)
        assertTrue(TableDiagnosticsCore.BINARY_BYTES <= 196608)
        assertEquals(TableDiagnosticsBuffer.ARENA_BYTES, TableDiagnosticsBuffer().arena.size)
    }
    private fun anchor(seq: Int, parent: Int, mono: Int, reason: DiagnosticReason, operation: Int = 1, callback: Int = 1) =
        syntheticPresence().copy(seq = seq, parent = parent, monoMs = mono, wallDeltaMs = mono, callback = callback, operation = operation,
            reason = reason, phase = if (reason == DiagnosticReason.PRESENCE_SELECTED) DiagnosticPhase.NONE else DiagnosticPhase.PREPARE,
            result = DiagnosticResult.ALLOW, count = 0, attempt = if (reason == DiagnosticReason.MANUAL_REQUEST) 3 else 0,
            dueMs = null, sampleMs = null, child = DiagnosticPresence.NOT_SAMPLED, summary = DiagnosticPresence.NOT_SAMPLED)
    private fun plan(a: TableDiagnosticEvent, seq: Int, attempt: Int, due: Long, mono: Int = a.monoMs) =
        a.copy(seq = seq, parent = a.seq, phase = DiagnosticPhase.SCHEDULE, reason = DiagnosticReason.SAMPLE_PLAN,
            attempt = attempt, dueMs = due, monoMs = mono, wallDeltaMs = mono)
    private fun sample(p: TableDiagnosticEvent, seq: Int, input: Long, completion: Int, count: Int) =
        p.copy(seq = seq, parent = p.seq, phase = DiagnosticPhase.NONE, result = DiagnosticResult.RETURN,
            reason = if (input == p.dueMs) DiagnosticReason.SAMPLE_ON_TIME else DiagnosticReason.SAMPLE_DELAYED,
            sampleMs = input, monoMs = completion, wallDeltaMs = completion, count = count,
            child = DiagnosticPresence.PRESENT, summary = DiagnosticPresence.PRESENT)
    @Test fun pEarlyAndDDelayedPreserveCodecAndSerializerTimeAndParentMeaning() {
        val child = syntheticEvent().copy(seq = 10, parent = 8, callback = 1, operation = 1, notification = 1,
            monoMs = 950, stage = DiagnosticStage.CHILD_NOTIFY, result = DiagnosticResult.RETURN, reason = DiagnosticReason.CHILD_NOTIFY_RETURN)
        val a = anchor(11, 10, 1000, DiagnosticReason.POST_LOCK_RELEASE)
        val plans = arrayOf(plan(a, 12, 0, 1000), plan(a, 13, 1, 1250), plan(a, 14, 2, 3000))
        val samples = plans.mapIndexed { i, p -> sample(p, 15 + i, p.dueMs!!, p.dueMs.toInt() + 4, i + 1) }
        val events = arrayOf(child, a, *plans, *samples.toTypedArray())
        events.forEach(::roundTrip)
        val pText = String(syntheticExport(syntheticBuffer(*events)))
        assertTrue(pText.contains("\"dueMs\":1250,\"sampleMs\":1250"))
        val delayed = sample(plans[1], 16, 1300, 1306, 2)
        roundTrip(delayed)
        assertEquals(50, delayed.sampleMs!! - delayed.dueMs!!); assertEquals(6, delayed.monoMs - delayed.sampleMs)
        val dEvents = events.map { if (it.seq == 16) delayed else it }.toTypedArray()
        assertTrue(String(syntheticExport(syntheticBuffer(*dEvents))).contains("SAMPLE_DELAYED"))
    }
    @Test fun lLateAndMManualUseSeparateAnchorsAndManualOperation() {
        val selected = anchor(20, 0, 5000, DiagnosticReason.PRESENCE_SELECTED, 2, 0)
        val late = anchor(21, 20, 5001, DiagnosticReason.LATE_SELECTION, 2, 0)
        val plans = arrayOf(plan(late, 22, 0, 5001), plan(late, 23, 1, 5251), plan(late, 24, 2, 7001))
        val samples = plans.mapIndexed { i, p -> sample(p, 25 + i, p.dueMs!! + 4, p.dueMs.toInt() + 9, i + 1) }
        val manual = anchor(30, 20, 8000, DiagnosticReason.MANUAL_REQUEST, 3, 0)
        val manualPlan = plan(manual, 31, 3, 8000, 8001)
        val manualSample = sample(manualPlan, 32, 8010, 8015, 4)
        val events = arrayOf(selected, late, *plans, *samples.toTypedArray(), manual, manualPlan, manualSample)
        events.forEach(::roundTrip)
        val text = String(syntheticExport(syntheticBuffer(*events)))
        assertTrue(text.contains("\"dueMs\":5001")); assertTrue(text.contains("\"dueMs\":8000,\"sampleMs\":8010"))
        assertEquals(3, manualSample.attempt); assertEquals(4, manualSample.count); assertEquals(31, manualSample.parent)
    }
    @Test fun channelCarriesItsActualPresenceSampleAndRejectsForeignParentOrTiming() {
        val selected = anchor(20, 0, 5000, DiagnosticReason.PRESENCE_SELECTED, 2, 0)
        val late = anchor(21, 20, 5001, DiagnosticReason.LATE_SELECTION, 2, 0)
        val p = plan(late, 22, 0, 5001)
        val s = sample(p, 23, 5005, 5010, 1)
        val channel = s.copy(seq = 24, parent = 23, stage = DiagnosticStage.CHANNEL_OBSERVATION, reason = DiagnosticReason.NONE,
            monoMs = 5012, evaluated = 192, truths = 192, child = DiagnosticPresence.NOT_SAMPLED, summary = DiagnosticPresence.NOT_SAMPLED)
        roundTrip(channel)
        assertTrue(String(syntheticExport(syntheticBuffer(selected, late, p, s, channel))).contains("CHANNEL_OBSERVATION"))
        invalid { syntheticExport(syntheticBuffer(selected, late, p, s, channel.copy(sampleMs = 5006))) }
        invalid { syntheticExport(syntheticBuffer(selected, late, p, s, channel.copy(parent = 22))) }
        invalid { syntheticExport(syntheticBuffer(selected, late, p, s, channel.copy(operation = 3))) }
        invalid { syntheticExport(syntheticBuffer(selected, late, p.copy(dueMs = 5002), s, channel)) }
    }
    private fun review36Plan(): Array<TableDiagnosticEvent> {
        val child = syntheticEvent().copy(seq = 1, callback = 1, operation = 1, notification = 1,
            monoMs = 950, stage = DiagnosticStage.CHILD_NOTIFY, result = DiagnosticResult.RETURN,
            reason = DiagnosticReason.CHILD_NOTIFY_RETURN)
        val a = anchor(2, 1, 1000, DiagnosticReason.POST_LOCK_RELEASE)
        return arrayOf(child, a, plan(a, 3, 1, 1250))
    }
    private fun skippedSlot(p: TableDiagnosticEvent, reason: DiagnosticReason = DiagnosticReason.SAMPLE_SKIPPED) =
        p.copy(seq = p.seq + 1, parent = p.seq, monoMs = 1300, phase = DiagnosticPhase.NONE,
            result = DiagnosticResult.SKIP, reason = reason, sampleMs = null, count = 0)
    @Test fun skippedSampleMustPreserveKnownPlanDueAndAttempt() {
        val events = review36Plan(); val skip = skippedSlot(events.last())
        // The controller's exact due=9000/attempt=2 counterexample, then each independent mismatch.
        for (bad in listOf(skip.copy(dueMs = 9000, attempt = 2), skip.copy(dueMs = 9000), skip.copy(attempt = 2), skip.copy(dueMs = null))) {
            roundTrip(bad) // Local fields valid; only the whole export can check the reference.
            invalid { syntheticExport(syntheticBuffer(*events, bad)) }
        }
    }
    @Test fun skippedSampleMustPreserveKnownPlanOccurrence() {
        val events = review36Plan(); val skip = skippedSlot(events.last())
        for (bad in listOf(skip.copy(callback = 2), skip.copy(operation = 2), skip.copy(notification = 2))) {
            roundTrip(bad)
            invalid { syntheticExport(syntheticBuffer(*events, bad)) }
        }
    }
    @Test fun allClosedSkipReasonsValidatePlanAndKeepValidUnsampledRecords() {
        val events = review36Plan()
        val reasons = listOf(DiagnosticReason.SAMPLE_DEADLINE, DiagnosticReason.SAMPLE_SKIPPED,
            DiagnosticReason.SCOPE_CHANGED, DiagnosticReason.PRESENCE_CLEARED,
            DiagnosticReason.PRESENCE_STOPPED, DiagnosticReason.PLAN_UNKNOWN)
        for (reason in reasons) {
            val skip = skippedSlot(events.last(), reason)
            roundTrip(skip)
            val text = String(syntheticExport(syntheticBuffer(*events, skip)))
            assertTrue(text.contains("\"reason\":\"${reason.name}\""))
            assertTrue(text.contains("\"dueMs\":1250,\"sampleMs\":null"))
            invalid { syntheticExport(syntheticBuffer(*events, skip.copy(parent = 1))) }
            invalid { syntheticExport(syntheticBuffer(*events, skip.copy(parent = 2))) }
            invalid { syntheticExport(syntheticBuffer(*events, skip.copy(callback = 2))) }
            invalid { syntheticExport(syntheticBuffer(*events, skip.copy(operation = 2))) }
            invalid { syntheticExport(syntheticBuffer(*events, skip.copy(notification = 2))) }
            invalid { syntheticExport(syntheticBuffer(*events, skip.copy(attempt = 2))) }
            invalid { syntheticExport(syntheticBuffer(*events, skip.copy(dueMs = 9000))) }
            invalid { syntheticExport(syntheticBuffer(*events, skip.copy(dueMs = null))) }
            if (reason != DiagnosticReason.PLAN_UNKNOWN) {
                invalid { syntheticExport(syntheticBuffer(skip)) } // Positive but missing parent.
                invalid { syntheticExport(syntheticBuffer(skip.copy(parent = 0))) } // Known due without plan.
            }
        }
    }
    @Test fun selectedWithParentMustReferToCaptureAllow() {
        val callback = syntheticEvent().copy(seq = 1, callback = 1, operation = 1, notification = 1)
        val selected = anchor(2, 1, 1000, DiagnosticReason.PRESENCE_SELECTED)
        roundTrip(selected)
        invalid { syntheticExport(syntheticBuffer(callback, selected)) }
        invalid { syntheticExport(syntheticBuffer(callback.copy(stage = DiagnosticStage.CAPTURE, result = DiagnosticResult.REJECT), selected)) }
        invalid { syntheticExport(syntheticBuffer(selected)) }
    }
    @Test fun selectionLinksSameCaptureOccurrenceAndDirectSelectionRemainsValid() {
        val capture = captureEvent().copy(seq = 1, callback = 1, operation = 1, notification = 1, monoMs = 900)
        val selected = anchor(2, 1, 901, DiagnosticReason.PRESENCE_SELECTED)
        roundTrip(capture); roundTrip(selected)
        assertTrue(String(syntheticExport(syntheticBuffer(capture, selected))).contains("PRESENCE_SELECTED"))
        for (bad in listOf(selected.copy(callback = 2), selected.copy(operation = 2), selected.copy(notification = 2), selected.copy(monoMs = 899))) {
            invalid { syntheticExport(syntheticBuffer(capture, bad)) }
        }
        val direct = selected.copy(parent = 0, callback = 0, operation = 2)
        assertTrue(String(syntheticExport(syntheticBuffer(roundTrip(direct)))).contains("PRESENCE_SELECTED"))
    }
    @Test fun planUnknownMissingReferencesRemainUnsampledWithoutFabricatingSuccess() {
        val known = review36Plan().last()
        val unknown = skippedSlot(known, DiagnosticReason.PLAN_UNKNOWN)
        for (e in listOf(unknown, unknown.copy(parent = 0, dueMs = null), unknown.copy(dueMs = null))) {
            val text = String(syntheticExport(syntheticBuffer(roundTrip(e))))
            assertTrue(text.contains("\"result\":\"SKIP\""))
            assertTrue(text.contains("\"child\":\"NOT_SAMPLED\""))
            assertTrue(text.contains("\"count\":0")); assertTrue(text.contains("\"sampleMs\":null"))
        }
        // Unscheduled arm/clear/stop observations do not need an invented plan.
        for (reason in listOf(DiagnosticReason.SCOPE_CHANGED, DiagnosticReason.PRESENCE_CLEARED, DiagnosticReason.PRESENCE_STOPPED)) {
            syntheticExport(syntheticBuffer(roundTrip(unknown.copy(parent = 0, dueMs = null, reason = reason))))
        }
        invalid { unknown.copy(child = DiagnosticPresence.PRESENT) }
        invalid { unknown.copy(result = DiagnosticResult.RETURN) }
        invalid { unknown.copy(sampleMs = 1300, count = 1) }
        invalid { syntheticExport(syntheticBuffer(sample(known, 4, 1250, 1300, 1))) }
    }
    private val removalReasons = listOf(DiagnosticReason.TAP_DISMISS, DiagnosticReason.DELETE_CHILD,
        DiagnosticReason.DELETE_GROUP, DiagnosticReason.CHILD_EXPIRED, DiagnosticReason.BIND_ROTATED,
        DiagnosticReason.BIND_NULL, DiagnosticReason.RESET_SET, DiagnosticReason.BUILD_DISABLED_LAUNCH,
        DiagnosticReason.TOKEN_DELETE_CLEAR, DiagnosticReason.DELIVERY_STATE)
    @Test fun cancellationRemovalReasonCannotClaimReturn() {
        invalid { TableDiagnosticsJson().event(TableDiagnosticEvent(stage = DiagnosticStage.CANCEL,
            phase = DiagnosticPhase.CANCEL, reason = DiagnosticReason.TAP_DISMISS, result = DiagnosticResult.RETURN)) }
    }
    @Test fun cancellationReasonsHaveExactResultsAcrossConstructorCodecAndExport() {
        val pairs = removalReasons.map { it to DiagnosticResult.ATTEMPT } +
            listOf(DiagnosticReason.CANCEL_RETURN to DiagnosticResult.RETURN, DiagnosticReason.CANCEL_ERROR to DiagnosticResult.EXCEPTION)
        for ((reason, expected) in pairs) {
            val e = TableDiagnosticEvent(stage = DiagnosticStage.CANCEL, phase = DiagnosticPhase.CANCEL,
                target = DiagnosticTarget.CHILD, reason = reason, result = expected)
            roundTrip(e)
            assertTrue(String(syntheticExport(syntheticBuffer(e))).contains("\"result\":\"${expected.name}\""))
            for (wrong in DiagnosticResult.entries.filter { it != expected }) {
                invalid { e.copy(result = wrong) }
                // A corrupted packed result cannot bypass the constructor at decode/export.
                val bytes = ByteArray(128); TableDiagnosticsCodec.encode(e, bytes, 0)
                bytes[65] = wrong.ordinal.toByte()
                invalid { TableDiagnosticsCodec.decode(bytes, 0) }
                val b = syntheticBuffer(e); b.arena[65] = wrong.ordinal.toByte()
                invalid { syntheticExport(b) }
            }
        }
    }
}
