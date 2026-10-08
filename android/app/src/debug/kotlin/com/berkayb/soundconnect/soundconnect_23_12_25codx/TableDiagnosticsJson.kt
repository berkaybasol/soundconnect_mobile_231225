package com.berkayb.soundconnect.soundconnect_23_12_25codx

internal enum class DiagnosticBuildMode { DEBUG, RELEASE, PROFILE }
internal enum class DiagnosticPackage { PRIMARY, PREVIEW, OTHER }
internal enum class DiagnosticApi { API24_25, API26_32, API33_PLUS }
internal data class DiagnosticBuild(
    val mode: DiagnosticBuildMode, val packageKind: DiagnosticPackage,
    val debuggable: Boolean, val preview: Boolean, val stamp: Long, val api: DiagnosticApi
) {
    fun allowed() = mode == DiagnosticBuildMode.DEBUG && packageKind == DiagnosticPackage.PRIMARY && debuggable && !preview
}
internal enum class DiagnosticState { DISABLED, ACTIVE, SEALED, AUTO_SEALED, INCOMPLETE }
internal enum class DiagnosticEnd { MANUAL, TIME_LIMIT, BUFFER_FULL, ALIAS_LIMIT, CONTEXT_LIMIT, SEQUENCE_LIMIT, RECORD_FAILURE, NONE }
internal data class DiagnosticJsonLimits(val event: Int = 1024, val header: Int = 8192, val total: Int = 1_100_000) {
    init { require(event in 1..1024 && header in 1..8192 && total in 1..1_100_000) }
}

internal class TableDiagnosticsJson(private val limits: DiagnosticJsonLimits = DiagnosticJsonLimits()) {
    fun event(e: TableDiagnosticEvent): String {
        require(TableDiagnosticsSchema.valid(e)) { "INVALID_DIAGNOSTIC_EVENT" }
        val s = StringBuilder(768)
        // All strings below are compile-time keys or closed ASCII enum names.
        fun number(key: String, value: Long?) { s.append('"').append(key).append("\":").append(value).append(',') }
        fun enum(key: String, value: Enum<*>) { s.append('"').append(key).append("\":\"").append(value.name).append("\",") }
        s.append('{')
        number("seq", e.seq.toLong()); number("parent", e.parent.toLong())
        number("callback", e.callback.toLong()); number("operation", e.operation.toLong()); number("notification", e.notification.toLong())
        number("monoMs", e.monoMs.toLong()); number("wallDeltaMs", e.wallDeltaMs.toLong())
        enum("stage", e.stage); enum("source", e.source); enum("family", e.family); enum("version", e.version)
        enum("type", e.type); enum("variant", e.variant)
        number("keyMask", e.keyMask.toLong()); number("unknownKeys", e.unknownKeys.toLong())
        number("evaluated", e.evaluated); number("truths", e.truths); number("errors", e.errors)
        number("sentDeltaMs", e.sentDeltaMs); number("expiryDeltaMs", e.expiryDeltaMs); number("lifetimeMs", e.lifetimeMs)
        number("timeFlags", e.timeFlags.toLong()); enum("result", e.result); enum("reason", e.reason)
        enum("exception", e.exception); enum("phase", e.phase); enum("target", e.target)
        enum("child", e.child); enum("summary", e.summary); number("count", e.count.toLong())
        number("attempt", e.attempt.toLong()); number("dueMs", e.dueMs); number("sampleMs", e.sampleMs)
        s.setCharAt(s.length - 1, '}')
        require(s.length <= limits.event) { "EVENT_SIZE" }
        return s.toString()
    }

    fun export(buffer: TableDiagnosticsBuffer, health: DiagnosticHealth, state: DiagnosticState, end: DiagnosticEnd,
               session: ByteArray, process: ByteArray, build: DiagnosticBuild, startWallSec: Long?): ByteArray {
        require(state == DiagnosticState.SEALED || state == DiagnosticState.AUTO_SEALED || state == DiagnosticState.INCOMPLETE)
        require(build.allowed() && session.size == 16 && process.size == 16)
        require(startWallSec == null || startWallSec in 0..4_102_444_800L)
        val header = StringBuilder(1024)
        header.append("{\"schema\":1,\"session\":\"").append(hex(session)).append("\",\"process\":\"").append(hex(process))
        header.append("\",\"build\":{\"mode\":\"DEBUG\",\"package\":\"PRIMARY\",\"stamp\":\"")
            .append(java.lang.Long.toUnsignedString(build.stamp, 16).uppercase().padStart(16, '0'))
            .append("\",\"api\":\"").append(build.api.name).append("\"},\"startWallSec\":").append(startWallSec)
        header.append(",\"durationMs\":600000,\"retentionMs\":300000,\"state\":\"").append(state.name)
            .append("\",\"endReason\":\"").append(end.name).append("\",\"health\":{")
        for (counter in DiagnosticHealthCounter.entries) {
            header.append('"').append(counter.name).append("\":").append(health.count(counter)).append(',')
        }
        header.append("\"saturated\":").append(health.saturated.get()).append("},\"gap\":")
        if (health.mask() == 0) header.append("null") else {
            // A single conservative union covers the entire possible window, including lost CAS updates.
            header.append("{\"firstSeq\":0,\"lastSeq\":1000000,\"firstMonoMs\":0,\"lastMonoMs\":900000,\"reasonMask\":")
                .append(health.mask()).append('}')
        }
        header.append(",\"events\":")
        require(header.length + 1 <= limits.header) { "HEADER_SIZE" } // includes final envelope brace
        val output = StringBuilder(minOf(limits.total, 8192))
        output.append(header).append('[')
        // Temporary bounded serializer index, never a live event queue. Sort only committed slots.
        val order = LongArray(TableDiagnosticsBuffer.SLOTS)
        var size = 0
        for (i in 0 until TableDiagnosticsBuffer.SLOTS) {
            val e = buffer.read(i) ?: continue
            order[size++] = (e.seq.toLong() shl 32) or i.toLong()
        }
        java.util.Arrays.sort(order, 0, size)
        var previous = 0
        for (i in 0 until size) {
            val e = buffer.read(order[i].toInt()) ?: error("UNFINISHED_SLOT")
            require(e.seq > previous) { "SEQUENCE_ORDER" }
            previous = e.seq
            validateLink(e, buffer, order, size)
            val encoded = event(e)
            require(output.length.toLong() + encoded.length + (if (i == 0) 0 else 1) + 2 <= limits.total) { "EXPORT_SIZE" }
            if (i > 0) output.append(',')
            output.append(encoded)
        }
        require(output.length + 2 <= limits.total) { "EXPORT_SIZE" }
        return output.append("]}").toString().toByteArray(Charsets.US_ASCII)
    }

    private fun validateLink(e: TableDiagnosticEvent, buffer: TableDiagnosticsBuffer, order: LongArray, size: Int) {
        if (e.stage != DiagnosticStage.PRESENCE && e.stage != DiagnosticStage.CHANNEL_OBSERVATION) return
        val skippedSlot = e.stage == DiagnosticStage.PRESENCE && e.result == DiagnosticResult.SKIP &&
            e.reason in arrayOf(DiagnosticReason.SAMPLE_DEADLINE, DiagnosticReason.SAMPLE_SKIPPED,
                DiagnosticReason.PLAN_UNKNOWN, DiagnosticReason.SCOPE_CHANGED,
                DiagnosticReason.PRESENCE_CLEARED, DiagnosticReason.PRESENCE_STOPPED)
        // Direct selection and unscheduled lifecycle/unknown records have no plan.
        // A known due or a positive parent must not silently bypass link validation.
        if (skippedSlot && e.parent == 0 && e.dueMs == null) return
        val needsParent = e.stage == DiagnosticStage.CHANNEL_OBSERVATION || e.reason in arrayOf(
            DiagnosticReason.POST_LOCK_RELEASE, DiagnosticReason.LATE_SELECTION, DiagnosticReason.MANUAL_REQUEST,
            DiagnosticReason.SAMPLE_PLAN, DiagnosticReason.SAMPLE_ON_TIME, DiagnosticReason.SAMPLE_DELAYED, DiagnosticReason.SAMPLE_ERROR
        ) || e.sampleMs != null || skippedSlot || e.reason == DiagnosticReason.PRESENCE_SELECTED && e.parent > 0
        if (!needsParent) return
        var p: TableDiagnosticEvent? = null
        for (i in 0 until size) if ((order[i] ushr 32).toInt() == e.parent) { p = buffer.read(order[i].toInt()); break }
        // An explicitly unknown missing reference remains unknown, without inventing a plan.
        if (p == null && skippedSlot && e.reason == DiagnosticReason.PLAN_UNKNOWN) return
        require(p != null && p.notification == e.notification) { "PRESENCE_PARENT" }
        // Manual reference belongs to a new operation; its parent is the original selection.
        if (e.reason != DiagnosticReason.MANUAL_REQUEST) {
            require(p.callback == e.callback && p.operation == e.operation) { "PRESENCE_OCCURRENCE" }
        } else require(e.callback == 0 && e.operation > 0)
        when {
            e.reason == DiagnosticReason.PRESENCE_SELECTED -> require(p.stage == DiagnosticStage.CAPTURE &&
                p.result == DiagnosticResult.ALLOW && e.monoMs >= p.monoMs) { "SELECTION_PARENT" }
            skippedSlot -> require(p.stage == DiagnosticStage.PRESENCE && p.reason == DiagnosticReason.SAMPLE_PLAN &&
                p.dueMs == e.dueMs && p.attempt == e.attempt && e.monoMs >= p.monoMs) { "SKIP_PARENT" }
            e.stage == DiagnosticStage.CHANNEL_OBSERVATION -> require(p.stage == DiagnosticStage.PRESENCE && p.sampleMs != null &&
                p.result in arrayOf(DiagnosticResult.RETURN, DiagnosticResult.EXCEPTION) && p.dueMs == e.dueMs &&
                p.sampleMs == e.sampleMs && p.attempt == e.attempt && p.count == e.count && e.monoMs >= p.monoMs) { "CHANNEL_PARENT" }
            e.reason == DiagnosticReason.POST_LOCK_RELEASE -> require(p.stage == DiagnosticStage.CHILD_NOTIFY && p.result == DiagnosticResult.RETURN && e.monoMs >= p.monoMs)
            e.reason == DiagnosticReason.LATE_SELECTION || e.reason == DiagnosticReason.MANUAL_REQUEST -> require(p.stage == DiagnosticStage.PRESENCE && p.reason == DiagnosticReason.PRESENCE_SELECTED && e.monoMs >= p.monoMs)
            e.reason == DiagnosticReason.SAMPLE_PLAN -> {
                require(p.stage == DiagnosticStage.PRESENCE && p.phase == DiagnosticPhase.PREPARE && e.monoMs >= p.monoMs)
                val offset = when (e.attempt) { 0 -> 0; 1 -> 250; 2 -> 2000; else -> 0 }
                require((e.attempt == 3) == (p.reason == DiagnosticReason.MANUAL_REQUEST) && e.dueMs == p.monoMs.toLong() + offset)
            }
            e.sampleMs != null -> require(p.stage == DiagnosticStage.PRESENCE && p.reason == DiagnosticReason.SAMPLE_PLAN &&
                p.dueMs == e.dueMs && p.attempt == e.attempt && e.sampleMs >= p.monoMs) { "SAMPLE_PARENT" }
        }
    }
    private fun hex(bytes: ByteArray): String {
        val digits = "0123456789abcdef"
        val out = CharArray(bytes.size * 2)
        for (i in bytes.indices) { val b = bytes[i].toInt() and 255; out[i * 2] = digits[b ushr 4]; out[i * 2 + 1] = digits[b and 15] }
        return String(out)
    }
}
