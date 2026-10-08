package com.berkayb.soundconnect.soundconnect_23_12_25codx

import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL

class PushAvatarFetchTest {
    private class FakeConnection(
        val status: Int = 200,
        val mime: String = "image/png",
        val size: Long = -1,
        val body: () -> InputStream = { ByteArrayInputStream(byteArrayOf(1, 2, 3)) }
    ) : HttpURLConnection(URL("https://cdn.invalid/avatar")) {
        var disconnected = false
        var bodyRequested = false
        override fun connect() = Unit
        override fun disconnect() { disconnected = true }
        override fun usingProxy() = false
        override fun getResponseCode() = status
        override fun getContentType() = mime
        override fun getContentLengthLong() = size
        override fun getInputStream(): InputStream { bodyRequested = true; return body() }
    }

    private fun reason(result: PushAvatarFetchResult) = (result as PushAvatarFetchResult.Failure).reason
    private fun fetch(connection: FakeConnection) = PushAvatarFetch({ false }, { 0L }, { connection }).fetch("safe-url")

    @Test fun successfulFetchKeepsStrictNetworkSettingsAndDisconnects() {
        val connection = FakeConnection(mime = "IMAGE/PNG")
        assertArrayEquals(byteArrayOf(1, 2, 3), (fetch(connection) as PushAvatarFetchResult.Bytes).value)
        assertFalse(connection.instanceFollowRedirects)
        assertFalse(connection.useCaches)
        assertEquals(1500, connection.connectTimeout)
        assertEquals(1000, connection.readTimeout)
        assertTrue(connection.disconnected)
    }

    @Test fun statusIsClassifiedBeforeOpeningErrorOrRedirectBody() {
        for ((status, expected) in listOf(408 to PushAvatarReason.HTTP_TRANSIENT,
            429 to PushAvatarReason.HTTP_TRANSIENT, 503 to PushAvatarReason.HTTP_TRANSIENT,
            404 to PushAvatarReason.HTTP_PERMANENT, 302 to PushAvatarReason.HTTP_REDIRECT)) {
            val connection = FakeConnection(status = status, body = { throw IOException("must not read") })
            assertEquals(expected, reason(fetch(connection)))
            assertFalse(connection.bodyRequested)
            assertTrue(connection.disconnected)
        }
    }

    @Test fun mimeAndAdvertisedSizeFailuresNeverReadBody() {
        for ((connection, expected) in listOf(
            FakeConnection(mime = "text/html") to PushAvatarReason.INVALID_MIME,
            FakeConnection(size = PushAvatarFetch.MAX_BYTES + 1L) to PushAvatarReason.OVERSIZE)) {
            assertEquals(expected, reason(fetch(connection)))
            assertFalse(connection.bodyRequested)
        }
    }

    @Test fun missingOrDishonestContentLengthStillCannotExceedByteLimit() {
        for (size in listOf(-1L, 1L)) {
            val connection = FakeConnection(size = size,
                body = { ByteArrayInputStream(ByteArray(PushAvatarFetch.MAX_BYTES + 1)) })
            assertEquals(PushAvatarReason.OVERSIZE, reason(fetch(connection)))
            assertTrue(connection.disconnected)
        }
        val exactlyLimit = FakeConnection(body = { ByteArrayInputStream(ByteArray(PushAvatarFetch.MAX_BYTES)) })
        assertEquals(PushAvatarFetch.MAX_BYTES, (fetch(exactlyLimit) as PushAvatarFetchResult.Bytes).value.size)
    }

    @Test fun timeoutAndIoHaveSafeDistinctTransientCategories() {
        for ((exception, expected) in listOf(SocketTimeoutException("private-url") to PushAvatarReason.NETWORK_TIMEOUT,
            IOException("private-token") to PushAvatarReason.NETWORK_IO,
            IllegalStateException("private-content") to PushAvatarReason.FETCH_ERROR)) {
            val connection = FakeConnection(body = { throw exception })
            assertEquals(expected, reason(fetch(connection)))
            assertTrue(connection.disconnected)
        }
    }

    @Test fun stoppingBeforeOrDuringIoNeverBecomesARetryableIoFailure() {
        var opened = false
        val before = PushAvatarFetch({ true }, { 0L }, { opened = true; FakeConnection() }).fetch("safe-url")
        assertEquals(PushAvatarReason.CANCELLED, reason(before))
        assertFalse(opened)
        var stopped = false
        val connection = FakeConnection(body = { stopped = true; throw IOException("cancelled socket") })
        val during = PushAvatarFetch({ stopped }, { 0L }, { connection }).fetch("safe-url")
        assertEquals(PushAvatarReason.CANCELLED, reason(during))
        assertTrue(connection.disconnected)
    }

    @Test fun streamDeadlineIncludingSlowEofIsTransientAndDoesNotDecodePartialBytes() {
        var now = 0L
        val connection = FakeConnection(body = { object : InputStream() {
            override fun read(): Int { now = 4_000; return -1 }
        } })
        assertEquals(PushAvatarReason.FETCH_DEADLINE,
            reason(PushAvatarFetch({ false }, { now }, { connection }).fetch("safe-url")))
        assertTrue(connection.disconnected)
    }

    @Test fun a503ThenSuccessRequiresSeparateAttemptsAndKeepsSameStrictFetchPolicy() {
        val connections = ArrayDeque(listOf(FakeConnection(status = 503), FakeConnection()))
        val fetcher = PushAvatarFetch({ false }, { 0L }, { connections.removeFirst() })
        val first = fetcher.fetch("safe-url")
        assertEquals(PushAvatarOutcome.RETRY, PushAvatarPolicy.retry(reason(first), 0, 0, 60_000))
        assertTrue(fetcher.fetch("safe-url") is PushAvatarFetchResult.Bytes)
        assertTrue(connections.isEmpty())
    }
}
