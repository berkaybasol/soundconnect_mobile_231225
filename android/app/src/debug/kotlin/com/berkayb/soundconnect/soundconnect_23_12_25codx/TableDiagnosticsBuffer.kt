package com.berkayb.soundconnect.soundconnect_23_12_25codx

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicIntegerArray

/** Fixed little-endian, unaligned layout. 82 bytes of v1 data, 46 zero reserved bytes. */
internal object TableDiagnosticsCodec {
    const val PACKED_BYTES = 82
    const val SLOT_BYTES = 128
    const val DUE_OFFSET = 74
    const val SAMPLE_OFFSET = 78
    fun encode(e: TableDiagnosticEvent, arena: ByteArray, offset: Int) {
        require(TableDiagnosticsSchema.valid(e)) { "INVALID_DIAGNOSTIC_EVENT" }
        require(offset >= 0 && offset <= arena.size - SLOT_BYTES)
        val b = ByteBuffer.wrap(arena, offset, SLOT_BYTES).order(ByteOrder.LITTLE_ENDIAN)
        fun u8(v: Int) { b.put(v.toByte()) }
        b.putInt(e.seq).putInt(e.parent)
        u8(e.callback); b.putShort(e.operation.toShort()); u8(e.notification)
        b.putInt(e.monoMs).putInt(e.wallDeltaMs)
        u8(e.stage.ordinal); u8(e.source.ordinal); u8(e.family.ordinal)
        u8(e.version.ordinal); u8(e.type.ordinal); u8(e.variant.ordinal)
        u8(e.keyMask); u8(e.unknownKeys)
        b.putInt(e.evaluated.toInt()).putInt(e.truths.toInt()).putInt(e.errors.toInt())
        b.putLong(e.sentDeltaMs ?: Long.MIN_VALUE).putLong(e.expiryDeltaMs ?: Long.MIN_VALUE)
            .putLong(e.lifetimeMs ?: Long.MIN_VALUE)
        u8(e.timeFlags); u8(e.result.ordinal); u8(e.reason.ordinal); u8(e.exception.ordinal)
        u8(e.phase.ordinal); u8(e.target.ordinal); u8(e.child.ordinal); u8(e.summary.ordinal)
        u8(e.count); u8(e.attempt)
        b.putInt(e.dueMs?.toInt() ?: -1).putInt(e.sampleMs?.toInt() ?: -1)
        check(b.position() == offset + PACKED_BYTES)
        arena.fill(0, offset + PACKED_BYTES, offset + SLOT_BYTES)
    }
    fun decode(arena: ByteArray, offset: Int): TableDiagnosticEvent {
        require(offset >= 0 && offset <= arena.size - SLOT_BYTES)
        require((offset + PACKED_BYTES until offset + SLOT_BYTES).all { arena[it] == 0.toByte() }) { "RESERVED_BYTES" }
        val b = ByteBuffer.wrap(arena, offset, SLOT_BYTES).order(ByteOrder.LITTLE_ENDIAN)
        fun u8() = b.get().toInt() and 255
        fun u32() = b.int.toLong() and 0xFFFFFFFFL
        fun nullable64() = b.long.let { if (it == Long.MIN_VALUE) null else it }
        fun nullable32() = u32().let { if (it == 0xFFFFFFFFL) null else it }
        return TableDiagnosticEvent(
            b.int, b.int, u8(), b.short.toInt() and 65535, u8(), b.int, b.int,
            DiagnosticStage.entries[u8()], DiagnosticSource.entries[u8()], DiagnosticFamily.entries[u8()],
            DiagnosticVersion.entries[u8()], DiagnosticType.entries[u8()], DiagnosticVariant.entries[u8()],
            u8(), u8(), u32(), u32(), u32(), nullable64(), nullable64(), nullable64(), u8(),
            DiagnosticResult.entries[u8()], DiagnosticReason.entries[u8()], DiagnosticException.entries[u8()],
            DiagnosticPhase.entries[u8()], DiagnosticTarget.entries[u8()], DiagnosticPresence.entries[u8()],
            DiagnosticPresence.entries[u8()], u8(), u8(), nullable32(), nullable32()
        )
    }
}

internal class TableDiagnosticsBuffer {
    companion object {
        const val DATA_SLOTS = 896
        const val CONTROL_SLOTS = 128
        const val SLOTS = DATA_SLOTS + CONTROL_SLOTS
        const val EVENT_BYTES = SLOTS * TableDiagnosticsCodec.SLOT_BYTES
        const val ALIASES = EVENT_BYTES
        const val SCOPES = ALIASES + 64 * 32
        const val CALLBACK_COUNTS = SCOPES + 16 * 32
        const val OPERATION_COUNTS = CALLBACK_COUNTS + 128
        // Includes unused bounded room for context/control, never a growing buffer.
        const val ARENA_BYTES = 147_456
        const val COMMITTED = 2
    }
    val arena = ByteArray(ARENA_BYTES)
    private val slots = AtomicIntegerArray(SLOTS)
    var dataCount = 0; private set
    var controlCount = 0; private set
    fun reserve(control: Boolean, closing: Boolean = false): Int {
        val slot = if (control) {
            if (controlCount >= if (closing) CONTROL_SLOTS else CONTROL_SLOTS - 2) return -1
            DATA_SLOTS + controlCount++
        } else {
            if (dataCount >= DATA_SLOTS) return -1
            dataCount++
        }
        slots.set(slot, 1)
        return slot
    }
    fun write(slot: Int, event: TableDiagnosticEvent) {
        check(slots.get(slot) == 1)
        TableDiagnosticsCodec.encode(event, arena, slot * TableDiagnosticsCodec.SLOT_BYTES)
    }
    fun commit(slot: Int): Boolean = slots.compareAndSet(slot, 1, COMMITTED)
    fun read(slot: Int): TableDiagnosticEvent? = if (slots.get(slot) == COMMITTED)
        TableDiagnosticsCodec.decode(arena, slot * TableDiagnosticsCodec.SLOT_BYTES) else null
    fun abandonUnfinished(): Int {
        var count = 0
        for (i in 0 until SLOTS) if (slots.compareAndSet(i, 1, 3)) count++
        return count
    }
    fun incrementBudget(callback: Int, operation: Int): Boolean {
        val c = if (callback == 0) -1 else CALLBACK_COUNTS + callback - 1
        val o = if (operation == 0) -1 else OPERATION_COUNTS + operation - 1
        if (c >= 0 && arena[c].toInt() >= 64 || o >= 0 && arena[o].toInt() >= 64) return false
        if (c >= 0) arena[c]++
        if (o >= 0) arena[o]++
        return true
    }
    fun clear() { arena.fill(0); for (i in 0 until SLOTS) slots.set(i, 0); dataCount = 0; controlCount = 0 }
}

internal enum class DiagnosticHealthCounter {
    attempted, stored, droppedContention, droppedCapacity, droppedCallback,
    droppedAlias, droppedContext, droppedBridge, unfinishedSlots
}
internal class DiagnosticHealth {
    private val counters = AtomicIntegerArray(DiagnosticHealthCounter.entries.size)
    val saturated = AtomicBoolean(false)
    private val gapBits = AtomicInteger(0)
    fun bump(counter: DiagnosticHealthCounter, amount: Int = 1) {
        val i = counter.ordinal
        val old = counters.get(i)
        val next = (old.toLong() + amount).coerceAtMost(65535).toInt()
        if (old + amount > 65535) saturated.set(true)
        // One CAS, never spin. A collided health update is conservatively unknown.
        if (!counters.compareAndSet(i, old, next)) { saturated.set(true); gapBits.set(255) }
    }
    fun gap(bit: Int) {
        val old = gapBits.get()
        if (!gapBits.compareAndSet(old, old or bit)) gapBits.set(255)
    }
    fun count(counter: DiagnosticHealthCounter) = counters.get(counter.ordinal)
    fun mask() = gapBits.get()
    fun clear() { for (i in 0 until counters.length()) counters.set(i, 0); saturated.set(false); gapBits.set(0) }
}
