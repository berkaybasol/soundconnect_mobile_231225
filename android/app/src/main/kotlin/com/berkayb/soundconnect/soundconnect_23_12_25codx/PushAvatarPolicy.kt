package com.berkayb.soundconnect.soundconnect_23_12_25codx

/** Fixed diagnostic vocabulary only: never attach URLs, identity, content or exception text. */
internal enum class PushAvatarReason(val transient: Boolean = false) {
    HTTP_TRANSIENT(true), NETWORK_TIMEOUT(true), NETWORK_IO(true), FETCH_DEADLINE(true),
    HTTP_REDIRECT, HTTP_PERMANENT, INVALID_MIME, OVERSIZE, INVALID_IMAGE, FETCH_ERROR,
    CANCELLED, INVALID_PAYLOAD, NO_SAFE_URL, EXPIRED, STALE_BINDING, FOREGROUND,
    NOT_ACTIVE, POSTED, POST_REJECTED, ENQUEUE_REQUESTED, ENQUEUE_FAILED, ATTEMPT_LIMIT
}

internal enum class PushAvatarOutcome {
    ENQUEUE_REQUESTED, SKIPPED, POSTED, TERMINAL, RETRY, ATTEMPT_LIMIT, EXPIRY_BEFORE_RETRY
}

internal object PushAvatarPolicy {
    const val MAX_ATTEMPTS = 3
    // WorkManager's minimum backoff. Exponential retries wait at least 10s, then 20s.
    const val BACKOFF_MS = 10_000L

    fun httpFailure(status: Int): PushAvatarReason? = when (status) {
        200 -> null
        408, 429, in 500..599 -> PushAvatarReason.HTTP_TRANSIENT
        in 300..399 -> PushAvatarReason.HTTP_REDIRECT
        else -> PushAvatarReason.HTTP_PERMANENT
    }

    fun guard(now: Long, expiresAt: Long, stopped: Boolean, bindingCurrent: Boolean,
              foreground: Boolean, active: Boolean): PushAvatarReason? = when {
        stopped -> PushAvatarReason.CANCELLED
        now >= expiresAt -> PushAvatarReason.EXPIRED
        !bindingCurrent -> PushAvatarReason.STALE_BINDING
        foreground -> PushAvatarReason.FOREGROUND
        !active -> PushAvatarReason.NOT_ACTIVE
        else -> null
    }

    fun retry(reason: PushAvatarReason, runAttemptCount: Int, now: Long,
              expiresAt: Long): PushAvatarOutcome {
        if (!reason.transient) return PushAvatarOutcome.TERMINAL
        if (runAttemptCount !in 0 until MAX_ATTEMPTS - 1) return PushAvatarOutcome.ATTEMPT_LIMIT
        val delay = BACKOFF_MS * (1L shl runAttemptCount)
        if (expiresAt <= now || expiresAt - now <= delay) return PushAvatarOutcome.EXPIRY_BEFORE_RETRY
        return PushAvatarOutcome.RETRY
    }
}
