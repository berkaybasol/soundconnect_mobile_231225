package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test

class PushAvatarPolicyTest {
    @Test fun onlyNarrowHttpFailuresAreTransient() {
        assertNull(PushAvatarPolicy.httpFailure(200))
        for (status in listOf(408, 429, 500, 502, 503, 504, 599)) {
            assertEquals(PushAvatarReason.HTTP_TRANSIENT, PushAvatarPolicy.httpFailure(status))
        }
        for (status in listOf(301, 302, 307, 308)) {
            assertEquals(PushAvatarReason.HTTP_REDIRECT, PushAvatarPolicy.httpFailure(status))
        }
        for (status in listOf(0, 201, 204, 400, 401, 403, 404, 410, 499, 600)) {
            assertEquals(PushAvatarReason.HTTP_PERMANENT, PushAvatarPolicy.httpFailure(status))
        }
    }

    @Test fun threeAttemptsMeansOnlyTwoRetriesEvenAfterWorkerRestarts() {
        for (reason in listOf(PushAvatarReason.HTTP_TRANSIENT, PushAvatarReason.NETWORK_TIMEOUT,
            PushAvatarReason.NETWORK_IO, PushAvatarReason.FETCH_DEADLINE)) {
            assertEquals(PushAvatarOutcome.RETRY, PushAvatarPolicy.retry(reason, 0, 100, 100_000))
            assertEquals(PushAvatarOutcome.RETRY, PushAvatarPolicy.retry(reason, 1, 100, 100_000))
            for (attempt in listOf(-1, 2, 3, Int.MAX_VALUE)) {
                assertEquals(PushAvatarOutcome.ATTEMPT_LIMIT, PushAvatarPolicy.retry(reason, attempt, 100, 100_000))
            }
        }
    }

    @Test fun everyNonTransientReasonIsTerminalIncludingBadDecodeAndCancelledIo() {
        for (reason in PushAvatarReason.entries.filter { !it.transient }) {
            assertEquals(reason.name, PushAvatarOutcome.TERMINAL, PushAvatarPolicy.retry(reason, 0, 100, 100_000))
        }
    }

    @Test fun backoffMustFitBeforeExpiryAndUsesExponentialSecondDelay() {
        val reason = PushAvatarReason.NETWORK_TIMEOUT
        assertEquals(10_000L, PushAvatarPolicy.BACKOFF_MS)
        for ((attempt, remaining) in listOf(0 to 0, 0 to -1, 0 to 10_000, 1 to 20_000)) {
            assertEquals(PushAvatarOutcome.EXPIRY_BEFORE_RETRY,
                PushAvatarPolicy.retry(reason, attempt, 1_000, 1_000L + remaining))
        }
        assertEquals(PushAvatarOutcome.RETRY, PushAvatarPolicy.retry(reason, 0, 1_000, 11_001))
        assertEquals(PushAvatarOutcome.RETRY, PushAvatarPolicy.retry(reason, 1, 1_000, 21_001))
    }

    @Test fun stateChangesDuringFetchBlockBothUpdateAndRetry() {
        fun guard(stopped: Boolean = false, bound: Boolean = true, foreground: Boolean = false,
                  active: Boolean = true, now: Long = 100) =
            PushAvatarPolicy.guard(now, 200, stopped, bound, foreground, active)
        assertNull(guard())
        assertEquals(PushAvatarReason.CANCELLED, guard(stopped = true))
        assertEquals(PushAvatarReason.STALE_BINDING, guard(bound = false))
        assertEquals(PushAvatarReason.FOREGROUND, guard(foreground = true))
        assertEquals(PushAvatarReason.NOT_ACTIVE, guard(active = false))
        assertEquals(PushAvatarReason.EXPIRED, guard(now = 200))
        assertEquals(PushAvatarReason.EXPIRED, guard(now = 201))
    }
}
