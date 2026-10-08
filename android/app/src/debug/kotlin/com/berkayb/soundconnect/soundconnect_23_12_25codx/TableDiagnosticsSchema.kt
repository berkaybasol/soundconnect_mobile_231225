package com.berkayb.soundconnect.soundconnect_23_12_25codx

// Debug-only, closed v1 vocabulary. Ordinals are the binary codec's unsigned bytes.
internal enum class DiagnosticStage {
    GATE_OPEN, PROCESS_SCOPE_START, HEARTBEAT, CALLBACK_START, BUILD_GUARD,
    FOREGROUND_GUARD, APP_GUARD, RUNTIME_GUARD, PREPARE, DISPATCH, PARSE,
    CAPTURE, CURRENT, SEEN, PREPOST_GUARD, RESERVE_POLICY, RESERVE_TX,
    RESERVE_RETURN, FINAL_GUARD, CHILD_NOTIFY, SUMMARY_RECONCILE, SUMMARY_NOTIFY,
    SUMMARY_CANCEL, REPAIR_SCHEDULE, EXPIRY_SCHEDULE, CALLBACK_END, TAP, DELETE,
    EXPIRY, GROUP_ELIGIBILITY, BIND, RESET, CLEAR, SNAPSHOT, DELIVERY_SELECTION,
    TOMBSTONE, CANCEL, BRIDGE_HANDOFF, CHANNEL_OBSERVATION, PRESENCE,
    CLOCK_CHANGE, GAP, GATE_CLOSE, PROCESS_SCOPE_END
}
internal enum class DiagnosticSource { NONE, NATIVE_FCM, NATIVE_IDENTITY, DELETE_INTENT, EXPIRY_WORK, GROUP_REPAIR, BIND_BRIDGE, DELIVERY_BRIDGE, DIAGNOSTIC_CONTROL }
internal enum class DiagnosticFamily { TABLE_CANDIDATE, TABLE_VALID, UNKNOWN, NONE }
internal enum class DiagnosticVersion { ANDROID_TABLE_V1, UNKNOWN, NOT_EVALUATED }
internal enum class DiagnosticType { TABLE_EXPIRED, TABLE_JOIN_REQUEST_RECEIVED, TABLE_JOIN_REQUEST_APPROVED, TABLE_JOIN_REQUEST_REJECTED, TABLE_PARTICIPANT_LEFT, TABLE_REMOVED, TABLE_CANCELLED, UNKNOWN, NOT_EVALUATED }
internal enum class DiagnosticVariant { DEFAULT, OWNER_CANCELLED, OWNER_JOINED_ANOTHER_TABLE, UNKNOWN, NOT_EVALUATED }
internal enum class DiagnosticResult { NOT_EVALUATED, ALLOW, REJECT, TRUE, FALSE, ATTEMPT, RETURN, EXCEPTION, SKIP, UNKNOWN }
internal enum class DiagnosticException { NONE, CORRUPTION, STORAGE_FULL, STORAGE_IO, STORAGE_OTHER, SECURITY, PLATFORM, ARGUMENT, OTHER }
internal enum class DiagnosticPhase { NONE, OPEN, BEGIN_TX, POLICY, PRUNE, CONTAINS, COUNT, INSERT, SET_SUCCESSFUL, END_TX, CLOSE, PREPARE, CHILD, SUMMARY, SCHEDULE, CANCEL, BRIDGE }
internal enum class DiagnosticTarget { NONE, CHILD, SHARED_VENUE_SUMMARY }
internal enum class DiagnosticPresence { NOT_SAMPLED, PRESENT, ABSENT, UNKNOWN, LIMIT, ERROR }
internal enum class DiagnosticReason {
    NONE, TYPE_MISSING, NEGATIVE_NOW, KEYSET_MISMATCH, VERSION_MISMATCH,
    TYPE_OR_VARIANT_UNSUPPORTED, NOTIFICATION_UUID_INVALID, RECIPIENT_UUID_INVALID,
    EXPIRY_NOT_LONG, EXPIRED, TTL_TOO_LONG, SENT_NOT_LONG, SENT_NEGATIVE,
    SENT_NOT_BEFORE_EXPIRY, NONCANONICAL_SENT, NONCANONICAL_EXPIRY,
    SENT_NOT_POSITIVE, SENT_TOO_FUTURE, LIFETIME_TOO_LONG, PARSE_ACCEPTED,
    BUILD_DISABLED, FOREGROUND, APP_DISABLED, RUNTIME_DENIED, BODY_UNSUPPORTED,
    RECIPIENT_MISMATCH, EPOCH_MISSING, EPOCH_INVALID, EPOCH_MISMATCH, RESET_BLOCKED,
    BINDING_STORAGE_ERROR, RESET_STORAGE_ERROR, CURRENT_FALSE, FOUND, NOT_FOUND,
    DUPLICATE, CAPACITY, INSERT_RETURN, COMMIT_RETURN, COMMIT_UNKNOWN, CLOSE_ERROR,
    STORAGE_ERROR, PREPARATION_ERROR, ACTION_FALSE, CHILD_NOTIFY_RETURN,
    CHILD_NOTIFY_ERROR, SUMMARY_UNCHANGED, SUMMARY_EMPTY, SUMMARY_ERROR,
    SCHEDULE_RETURN, SCHEDULE_ERROR, SCHEDULE_DISABLED_FOR_TEST, TAP_DISMISS,
    DELETE_CHILD, DELETE_GROUP, INVALID_ARGUMENTS, WORK_NOT_DUE, WORK_RETRY,
    WORK_RETRY_LIMIT, WORK_STOPPED, SAVED_EXPIRY_MISMATCH, PRUNED_OWNED_MATCH,
    ACTIVE_EXPIRY_MISMATCH, LEDGER_INELIGIBLE_UNSPECIFIED, CHILD_EXPIRED,
    BIND_SAME, BIND_ROTATED, BIND_NULL, RESET_SET, RESET_CLEAR, BUILD_DISABLED_LAUNCH,
    RESTORE_FAILED, STARTUP_NOT_RETAINED, STARTUP_RETAINED, SESSION_CONTEXT_CHANGED,
    SESSION_CHANGED, CANNOT_REGISTER, RESET_NEEDED, PERMISSION_DENIED, REGISTERED,
    TOKEN_DELETE_CLEAR, DELIVERY_STATE, SNAPSHOT_INVALID, SNAPSHOT_EMPTY,
    RESPONSE_ERROR, STALE_SESSION, STALE_EPOCH, NOT_SELECTED, SELECTED,
    CANCEL_RETURN, CANCEL_ERROR, QUEUED, STALE_PENDING, HANDOFF, UNKNOWN_OS_LOSS,
    NOT_EVALUATED, UNSCOPED, CONTENTION, CALLBACK_LIMIT, BUFFER_FULL, ALIAS_LIMIT,
    CONTEXT_LIMIT, SEQUENCE_LIMIT, TIME_LIMIT, MANUAL, RECORD_FAILURE, BRIDGE_LIMIT,
    SAMPLE_LIMIT, CLOCK_DISCONTINUITY, PRESENCE_ARMED, PRESENCE_SELECTED,
    POST_LOCK_RELEASE, LATE_SELECTION, MANUAL_REQUEST, SAMPLE_PLAN, SAMPLE_ERROR,
    SAMPLE_ON_TIME, SAMPLE_DELAYED, SAMPLE_DEADLINE, SAMPLE_SKIPPED, PLAN_UNKNOWN,
    SCOPE_CHANGED, PRESENCE_CLEARED, PRESENCE_STOPPED, NO_POST
}

/** Transient typed value, never retained per slot. No arbitrary object/string/map field. */
internal data class TableDiagnosticEvent(
    val seq: Int = 1, val parent: Int = 0, val callback: Int = 0,
    val operation: Int = 0, val notification: Int = 0,
    val monoMs: Int = 0, val wallDeltaMs: Int = 0,
    val stage: DiagnosticStage, val source: DiagnosticSource = DiagnosticSource.NONE,
    val family: DiagnosticFamily = DiagnosticFamily.NONE,
    val version: DiagnosticVersion = DiagnosticVersion.NOT_EVALUATED,
    val type: DiagnosticType = DiagnosticType.NOT_EVALUATED,
    val variant: DiagnosticVariant = DiagnosticVariant.NOT_EVALUATED,
    val keyMask: Int = 0, val unknownKeys: Int = 0,
    val evaluated: Long = 0, val truths: Long = 0, val errors: Long = 0,
    val sentDeltaMs: Long? = null, val expiryDeltaMs: Long? = null,
    val lifetimeMs: Long? = null, val timeFlags: Int = 0,
    val result: DiagnosticResult = DiagnosticResult.NOT_EVALUATED,
    val reason: DiagnosticReason = DiagnosticReason.NONE,
    val exception: DiagnosticException = DiagnosticException.NONE,
    val phase: DiagnosticPhase = DiagnosticPhase.NONE,
    val target: DiagnosticTarget = DiagnosticTarget.NONE,
    val child: DiagnosticPresence = DiagnosticPresence.NOT_SAMPLED,
    val summary: DiagnosticPresence = DiagnosticPresence.NOT_SAMPLED,
    val count: Int = 0, val attempt: Int = 0,
    val dueMs: Long? = null, val sampleMs: Long? = null
) {
    init { require(TableDiagnosticsSchema.valid(this)) { "INVALID_DIAGNOSTIC_EVENT" } }
}

internal object TableDiagnosticsSchema {
    const val BOOLEAN_MASK = 0xFFFFFFL
    const val SESSION_CURRENT = 1L shl 22
    const val MAX_DELTA = 2_419_200_000L
    private fun DiagnosticReason.oneOf(vararg values: DiagnosticReason) = values.any { this == it }

    fun valid(e: TableDiagnosticEvent): Boolean = with(e) {
        if (seq !in 1..1_000_000 || parent !in 0 until seq || callback !in 0..128 ||
            operation !in 0..512 || notification !in 0..64 || monoMs !in 0..900_000 ||
            wallDeltaMs !in -604_800_000..604_800_000 || keyMask !in 0..127 ||
            unknownKeys !in 0..8 || timeFlags !in 0..15 || count !in 0..100 || attempt !in 0..3) return false
        if (evaluated !in 0..BOOLEAN_MASK || truths !in 0..BOOLEAN_MASK || errors !in 0..BOOLEAN_MASK ||
            (truths or errors) and evaluated.inv() != 0L || truths and errors != 0L) return false
        if (sentDeltaMs != null && sentDeltaMs !in -MAX_DELTA..MAX_DELTA ||
            expiryDeltaMs != null && expiryDeltaMs !in -MAX_DELTA..MAX_DELTA ||
            lifetimeMs != null && lifetimeMs !in 0..MAX_DELTA ||
            dueMs != null && dueMs !in 0..601_999L || sampleMs != null && sampleMs !in 0..599_999L) return false
        if (stage != DiagnosticStage.PRESENCE && stage != DiagnosticStage.CHANNEL_OBSERVATION &&
            (dueMs != null || sampleMs != null || child != DiagnosticPresence.NOT_SAMPLED || summary != DiagnosticPresence.NOT_SAMPLED)) return false
        if (exception != DiagnosticException.NONE && result != DiagnosticResult.EXCEPTION) return false
        if (!reasonAllowed(stage, reason) || !phaseAllowed(stage, phase)) return false
        if (stage == DiagnosticStage.PARSE && reason != DiagnosticReason.NONE &&
            result != if (reason == DiagnosticReason.PARSE_ACCEPTED) DiagnosticResult.ALLOW else DiagnosticResult.REJECT) return false
        if (reason in arrayOf(DiagnosticReason.CANCEL_RETURN, DiagnosticReason.CHILD_NOTIFY_RETURN, DiagnosticReason.SCHEDULE_RETURN) &&
            result != DiagnosticResult.RETURN) return false
        if (reason in arrayOf(DiagnosticReason.CANCEL_ERROR, DiagnosticReason.CHILD_NOTIFY_ERROR, DiagnosticReason.SCHEDULE_ERROR) &&
            result != DiagnosticResult.EXCEPTION) return false
        if (stage == DiagnosticStage.CANCEL && reason.oneOf(
                DiagnosticReason.TAP_DISMISS, DiagnosticReason.DELETE_CHILD, DiagnosticReason.DELETE_GROUP,
                DiagnosticReason.CHILD_EXPIRED, DiagnosticReason.BIND_ROTATED, DiagnosticReason.BIND_NULL,
                DiagnosticReason.RESET_SET, DiagnosticReason.BUILD_DISABLED_LAUNCH,
                DiagnosticReason.TOKEN_DELETE_CLEAR, DiagnosticReason.DELIVERY_STATE) &&
            result != DiagnosticResult.ATTEMPT) return false
        if (reason == DiagnosticReason.COMMIT_RETURN && (phase != DiagnosticPhase.END_TX || result != DiagnosticResult.RETURN)) return false
        if (reason == DiagnosticReason.COMMIT_UNKNOWN && (phase != DiagnosticPhase.END_TX || result != DiagnosticResult.EXCEPTION)) return false
        if (reason == DiagnosticReason.CLOSE_ERROR && (phase != DiagnosticPhase.CLOSE || result != DiagnosticResult.EXCEPTION)) return false
        if (stage == DiagnosticStage.PRESENCE || stage == DiagnosticStage.CHANNEL_OBSERVATION) return presenceValid(e)
        true
    }

    private fun presenceValid(e: TableDiagnosticEvent): Boolean = with(e) {
        if (source != DiagnosticSource.DIAGNOSTIC_CONTROL || target != DiagnosticTarget.NONE) return false
        if (stage == DiagnosticStage.CHANNEL_OBSERVATION) return reason == DiagnosticReason.NONE &&
            phase == DiagnosticPhase.NONE && result in arrayOf(DiagnosticResult.RETURN, DiagnosticResult.EXCEPTION) &&
            parent > 0 && dueMs != null && sampleMs != null && sampleMs >= dueMs && monoMs >= sampleMs &&
            count in 1..4 && child == DiagnosticPresence.NOT_SAMPLED && summary == DiagnosticPresence.NOT_SAMPLED &&
            (evaluated and ((1L shl 6) or (1L shl 7)).inv()) == 0L
        val unsampled = child == DiagnosticPresence.NOT_SAMPLED && summary == DiagnosticPresence.NOT_SAMPLED
        when (reason) {
            DiagnosticReason.PRESENCE_ARMED -> phase == DiagnosticPhase.NONE && result == DiagnosticResult.ALLOW &&
                parent == 0 && notification == 0 && attempt == 0 && count == 0 && dueMs == null && sampleMs == null && unsampled
            DiagnosticReason.PRESENCE_SELECTED -> phase == DiagnosticPhase.NONE && result == DiagnosticResult.ALLOW &&
                notification > 0 && attempt == 0 && count == 0 && dueMs == null && sampleMs == null && unsampled
            DiagnosticReason.POST_LOCK_RELEASE, DiagnosticReason.LATE_SELECTION, DiagnosticReason.MANUAL_REQUEST ->
                phase == DiagnosticPhase.PREPARE && result == DiagnosticResult.ALLOW && parent > 0 && notification > 0 &&
                    count == 0 && dueMs == null && sampleMs == null && unsampled &&
                    attempt == if (reason == DiagnosticReason.MANUAL_REQUEST) 3 else 0
            DiagnosticReason.SAMPLE_PLAN -> phase == DiagnosticPhase.SCHEDULE && result == DiagnosticResult.ALLOW &&
                parent > 0 && notification > 0 && count == 0 && dueMs != null && sampleMs == null && unsampled
            DiagnosticReason.SAMPLE_ON_TIME, DiagnosticReason.SAMPLE_DELAYED, DiagnosticReason.SAMPLE_ERROR -> {
                if (phase != DiagnosticPhase.NONE || parent == 0 || notification == 0 || count !in 1..4 ||
                    dueMs == null || sampleMs == null || sampleMs < dueMs || monoMs < sampleMs) false
                else when (reason) {
                    DiagnosticReason.SAMPLE_ERROR -> result == DiagnosticResult.EXCEPTION &&
                        exception in arrayOf(DiagnosticException.SECURITY, DiagnosticException.PLATFORM, DiagnosticException.OTHER) &&
                        child == DiagnosticPresence.ERROR && summary == DiagnosticPresence.ERROR
                    else -> result == DiagnosticResult.RETURN && exception == DiagnosticException.NONE &&
                        child != DiagnosticPresence.NOT_SAMPLED && summary != DiagnosticPresence.NOT_SAMPLED &&
                        ((reason == DiagnosticReason.SAMPLE_ON_TIME) == (sampleMs == dueMs))
                }
            }
            DiagnosticReason.SCOPE_CHANGED -> if (sampleMs != null) {
                result == DiagnosticResult.RETURN && phase == DiagnosticPhase.NONE && parent > 0 && dueMs != null &&
                    sampleMs >= dueMs && monoMs >= sampleMs && count in 1..4 &&
                    child == DiagnosticPresence.UNKNOWN && summary == DiagnosticPresence.UNKNOWN &&
                    evaluated and SESSION_CURRENT != 0L && (truths or errors) and SESSION_CURRENT == 0L
            } else skipped(e)
            DiagnosticReason.SAMPLE_DEADLINE, DiagnosticReason.SAMPLE_SKIPPED, DiagnosticReason.PLAN_UNKNOWN,
            DiagnosticReason.PRESENCE_CLEARED, DiagnosticReason.PRESENCE_STOPPED, DiagnosticReason.NO_POST -> skipped(e)
            else -> false
        }
    }
    private fun skipped(e: TableDiagnosticEvent) = e.phase == DiagnosticPhase.NONE && e.result == DiagnosticResult.SKIP &&
        e.count == 0 && e.sampleMs == null && e.child == DiagnosticPresence.NOT_SAMPLED && e.summary == DiagnosticPresence.NOT_SAMPLED

    private fun reasonAllowed(s: DiagnosticStage, r: DiagnosticReason): Boolean {
        if (r == DiagnosticReason.NONE) return s != DiagnosticStage.PRESENCE
        return when (s) {
            DiagnosticStage.PARSE -> r.ordinal in DiagnosticReason.TYPE_MISSING.ordinal..DiagnosticReason.PARSE_ACCEPTED.ordinal
            DiagnosticStage.BUILD_GUARD -> r == DiagnosticReason.BUILD_DISABLED
            DiagnosticStage.FOREGROUND_GUARD -> r == DiagnosticReason.FOREGROUND
            DiagnosticStage.APP_GUARD -> r == DiagnosticReason.APP_DISABLED
            DiagnosticStage.RUNTIME_GUARD -> r == DiagnosticReason.RUNTIME_DENIED
            DiagnosticStage.PREPARE -> r == DiagnosticReason.PREPARATION_ERROR
            DiagnosticStage.CAPTURE, DiagnosticStage.CURRENT -> r.oneOf(DiagnosticReason.RECIPIENT_MISMATCH, DiagnosticReason.EPOCH_MISSING, DiagnosticReason.EPOCH_INVALID, DiagnosticReason.EPOCH_MISMATCH, DiagnosticReason.RESET_BLOCKED, DiagnosticReason.BINDING_STORAGE_ERROR, DiagnosticReason.RESET_STORAGE_ERROR, DiagnosticReason.CURRENT_FALSE)
            DiagnosticStage.SEEN -> r.oneOf(DiagnosticReason.CURRENT_FALSE, DiagnosticReason.FOUND, DiagnosticReason.NOT_FOUND, DiagnosticReason.STORAGE_ERROR)
            DiagnosticStage.PREPOST_GUARD, DiagnosticStage.FINAL_GUARD -> r.oneOf(DiagnosticReason.BUILD_DISABLED, DiagnosticReason.FOREGROUND, DiagnosticReason.RECIPIENT_MISMATCH, DiagnosticReason.EXPIRED, DiagnosticReason.BODY_UNSUPPORTED, DiagnosticReason.APP_DISABLED, DiagnosticReason.RUNTIME_DENIED)
            DiagnosticStage.RESERVE_POLICY -> r.oneOf(DiagnosticReason.NEGATIVE_NOW, DiagnosticReason.EXPIRED, DiagnosticReason.TTL_TOO_LONG, DiagnosticReason.DUPLICATE, DiagnosticReason.CAPACITY, DiagnosticReason.INSERT_RETURN, DiagnosticReason.STORAGE_ERROR)
            DiagnosticStage.RESERVE_TX -> r.oneOf(DiagnosticReason.COMMIT_RETURN, DiagnosticReason.COMMIT_UNKNOWN, DiagnosticReason.CLOSE_ERROR, DiagnosticReason.STORAGE_ERROR)
            DiagnosticStage.RESERVE_RETURN -> r.oneOf(DiagnosticReason.CURRENT_FALSE, DiagnosticReason.INVALID_ARGUMENTS, DiagnosticReason.STORAGE_ERROR, DiagnosticReason.ACTION_FALSE)
            DiagnosticStage.CHILD_NOTIFY -> r.oneOf(DiagnosticReason.CHILD_NOTIFY_RETURN, DiagnosticReason.CHILD_NOTIFY_ERROR)
            DiagnosticStage.SUMMARY_RECONCILE, DiagnosticStage.SUMMARY_NOTIFY, DiagnosticStage.SUMMARY_CANCEL -> r.oneOf(DiagnosticReason.SUMMARY_UNCHANGED, DiagnosticReason.SUMMARY_EMPTY, DiagnosticReason.SUMMARY_ERROR, DiagnosticReason.CANCEL_RETURN, DiagnosticReason.CANCEL_ERROR)
            DiagnosticStage.REPAIR_SCHEDULE, DiagnosticStage.EXPIRY_SCHEDULE -> r.oneOf(DiagnosticReason.SCHEDULE_RETURN, DiagnosticReason.SCHEDULE_ERROR, DiagnosticReason.SCHEDULE_DISABLED_FOR_TEST, DiagnosticReason.WORK_RETRY, DiagnosticReason.WORK_RETRY_LIMIT, DiagnosticReason.WORK_STOPPED)
            DiagnosticStage.CALLBACK_END -> r.oneOf(DiagnosticReason.ACTION_FALSE, DiagnosticReason.UNSCOPED)
            DiagnosticStage.TAP -> r.oneOf(DiagnosticReason.TAP_DISMISS, DiagnosticReason.INVALID_ARGUMENTS, DiagnosticReason.STALE_EPOCH)
            DiagnosticStage.DELETE -> r.oneOf(DiagnosticReason.DELETE_CHILD, DiagnosticReason.DELETE_GROUP, DiagnosticReason.INVALID_ARGUMENTS, DiagnosticReason.CURRENT_FALSE)
            DiagnosticStage.EXPIRY -> r.oneOf(DiagnosticReason.WORK_NOT_DUE, DiagnosticReason.WORK_RETRY, DiagnosticReason.WORK_RETRY_LIMIT, DiagnosticReason.WORK_STOPPED, DiagnosticReason.SAVED_EXPIRY_MISMATCH, DiagnosticReason.PRUNED_OWNED_MATCH, DiagnosticReason.ACTIVE_EXPIRY_MISMATCH, DiagnosticReason.CHILD_EXPIRED, DiagnosticReason.CURRENT_FALSE)
            DiagnosticStage.GROUP_ELIGIBILITY -> r.oneOf(DiagnosticReason.LEDGER_INELIGIBLE_UNSPECIFIED, DiagnosticReason.CHILD_EXPIRED, DiagnosticReason.CURRENT_FALSE)
            DiagnosticStage.BIND -> r.oneOf(DiagnosticReason.BIND_SAME, DiagnosticReason.BIND_ROTATED, DiagnosticReason.BIND_NULL, DiagnosticReason.BINDING_STORAGE_ERROR, DiagnosticReason.RESTORE_FAILED, DiagnosticReason.STARTUP_NOT_RETAINED, DiagnosticReason.STARTUP_RETAINED, DiagnosticReason.SESSION_CONTEXT_CHANGED, DiagnosticReason.SESSION_CHANGED, DiagnosticReason.CANNOT_REGISTER, DiagnosticReason.RESET_NEEDED, DiagnosticReason.PERMISSION_DENIED, DiagnosticReason.REGISTERED, DiagnosticReason.UNSCOPED)
            DiagnosticStage.RESET -> r.oneOf(DiagnosticReason.RESET_SET, DiagnosticReason.RESET_CLEAR, DiagnosticReason.RESET_STORAGE_ERROR)
            DiagnosticStage.CLEAR, DiagnosticStage.TOMBSTONE, DiagnosticStage.CANCEL -> r.oneOf(DiagnosticReason.TAP_DISMISS, DiagnosticReason.DELETE_CHILD, DiagnosticReason.DELETE_GROUP, DiagnosticReason.CHILD_EXPIRED, DiagnosticReason.BIND_ROTATED, DiagnosticReason.BIND_NULL, DiagnosticReason.RESET_SET, DiagnosticReason.BUILD_DISABLED_LAUNCH, DiagnosticReason.TOKEN_DELETE_CLEAR, DiagnosticReason.DELIVERY_STATE, DiagnosticReason.CANCEL_RETURN, DiagnosticReason.CANCEL_ERROR, DiagnosticReason.STORAGE_ERROR, DiagnosticReason.UNSCOPED)
            DiagnosticStage.SNAPSHOT -> r.oneOf(DiagnosticReason.SNAPSHOT_INVALID, DiagnosticReason.SNAPSHOT_EMPTY, DiagnosticReason.STORAGE_ERROR)
            DiagnosticStage.DELIVERY_SELECTION -> r.oneOf(DiagnosticReason.SELECTED, DiagnosticReason.NOT_SELECTED, DiagnosticReason.RESPONSE_ERROR, DiagnosticReason.STALE_SESSION, DiagnosticReason.STALE_EPOCH, DiagnosticReason.SNAPSHOT_INVALID, DiagnosticReason.SNAPSHOT_EMPTY)
            DiagnosticStage.BRIDGE_HANDOFF -> r.oneOf(DiagnosticReason.QUEUED, DiagnosticReason.STALE_PENDING, DiagnosticReason.HANDOFF, DiagnosticReason.BRIDGE_LIMIT, DiagnosticReason.UNSCOPED)
            DiagnosticStage.PRESENCE -> r.ordinal in DiagnosticReason.PRESENCE_ARMED.ordinal..DiagnosticReason.NO_POST.ordinal
            DiagnosticStage.CLOCK_CHANGE -> r == DiagnosticReason.CLOCK_DISCONTINUITY
            DiagnosticStage.GAP -> r.oneOf(DiagnosticReason.CONTENTION, DiagnosticReason.CALLBACK_LIMIT, DiagnosticReason.BUFFER_FULL, DiagnosticReason.ALIAS_LIMIT, DiagnosticReason.CONTEXT_LIMIT, DiagnosticReason.SEQUENCE_LIMIT, DiagnosticReason.RECORD_FAILURE, DiagnosticReason.BRIDGE_LIMIT, DiagnosticReason.CLOCK_DISCONTINUITY)
            DiagnosticStage.GATE_CLOSE, DiagnosticStage.PROCESS_SCOPE_END -> r.oneOf(DiagnosticReason.TIME_LIMIT, DiagnosticReason.BUFFER_FULL, DiagnosticReason.ALIAS_LIMIT, DiagnosticReason.CONTEXT_LIMIT, DiagnosticReason.SEQUENCE_LIMIT, DiagnosticReason.RECORD_FAILURE, DiagnosticReason.MANUAL)
            else -> false
        }
    }
    private fun phaseAllowed(s: DiagnosticStage, p: DiagnosticPhase): Boolean = when (s) {
        DiagnosticStage.RESERVE_TX -> p in arrayOf(DiagnosticPhase.OPEN, DiagnosticPhase.BEGIN_TX, DiagnosticPhase.POLICY, DiagnosticPhase.SET_SUCCESSFUL, DiagnosticPhase.END_TX, DiagnosticPhase.CLOSE)
        DiagnosticStage.RESERVE_POLICY -> p in arrayOf(DiagnosticPhase.POLICY, DiagnosticPhase.PRUNE, DiagnosticPhase.CONTAINS, DiagnosticPhase.COUNT, DiagnosticPhase.INSERT)
        DiagnosticStage.PRESENCE -> p in arrayOf(DiagnosticPhase.NONE, DiagnosticPhase.PREPARE, DiagnosticPhase.SCHEDULE)
        DiagnosticStage.PREPARE -> p in arrayOf(DiagnosticPhase.NONE, DiagnosticPhase.PREPARE)
        DiagnosticStage.CHILD_NOTIFY -> p in arrayOf(DiagnosticPhase.NONE, DiagnosticPhase.CHILD)
        DiagnosticStage.SUMMARY_NOTIFY, DiagnosticStage.SUMMARY_RECONCILE, DiagnosticStage.SUMMARY_CANCEL -> p in arrayOf(DiagnosticPhase.NONE, DiagnosticPhase.SUMMARY, DiagnosticPhase.CANCEL)
        DiagnosticStage.EXPIRY_SCHEDULE, DiagnosticStage.REPAIR_SCHEDULE -> p in arrayOf(DiagnosticPhase.NONE, DiagnosticPhase.SCHEDULE)
        DiagnosticStage.CANCEL -> p in arrayOf(DiagnosticPhase.NONE, DiagnosticPhase.CANCEL)
        DiagnosticStage.CAPTURE, DiagnosticStage.CURRENT, DiagnosticStage.SEEN, DiagnosticStage.TOMBSTONE -> p in arrayOf(DiagnosticPhase.NONE, DiagnosticPhase.OPEN, DiagnosticPhase.CLOSE)
        DiagnosticStage.BRIDGE_HANDOFF, DiagnosticStage.BIND, DiagnosticStage.RESET, DiagnosticStage.CLEAR, DiagnosticStage.SNAPSHOT, DiagnosticStage.DELIVERY_SELECTION -> p in arrayOf(DiagnosticPhase.NONE, DiagnosticPhase.BRIDGE)
        else -> p == DiagnosticPhase.NONE
    }
}
