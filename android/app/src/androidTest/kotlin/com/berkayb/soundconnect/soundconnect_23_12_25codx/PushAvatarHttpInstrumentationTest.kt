package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketTimeoutException
import java.net.URL
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/**
 * Real Android HTTP transport through the fetcher's existing connection seam.
 * Only a loopback fixture is contacted. No production URL policy, TLS settings,
 * account state, notification APIs, or WorkManager queues are changed.
 * Policy assertions below do not establish actual WorkManager retry scheduling.
 */
@RunWith(AndroidJUnit4::class)
class PushAvatarHttpInstrumentationTest {
    @Test(timeout = 12_000) fun requestTimeout408IsRetryableOnAndroidTransport() =
        assertHttpFailure(408, PushAvatarReason.HTTP_TRANSIENT, PushAvatarOutcome.RETRY)

    @Test(timeout = 12_000) fun rateLimited429IsRetryableOnAndroidTransport() =
        assertHttpFailure(429, PushAvatarReason.HTTP_TRANSIENT, PushAvatarOutcome.RETRY)

    @Test(timeout = 12_000) fun unavailable503IsRetryableOnAndroidTransport() =
        assertHttpFailure(503, PushAvatarReason.HTTP_TRANSIENT, PushAvatarOutcome.RETRY)

    @Test(timeout = 12_000) fun missing404IsPermanentOnAndroidTransport() =
        assertHttpFailure(404, PushAvatarReason.HTTP_PERMANENT, PushAvatarOutcome.TERMINAL)

    @Test(timeout = 12_000) fun redirect302DoesNotRequestTheRedirectTarget() {
        HttpFixture(status = 302).use { fixture ->
            val result = fixture.fetcher().fetch(FIXTURE_INPUT)
            assertFailure(result, PushAvatarReason.HTTP_REDIRECT, PushAvatarOutcome.TERMINAL)
            fixture.assertSingleRequest()
            assertFalse("Redirect target must never be requested", fixture.redirectRequested.get())
        }
    }

    @Test(timeout = 12_000) fun stalledImageBodyBecomesRetryableNetworkTimeout() {
        HttpFixture(status = 200, body = validPng(), stallBody = true).use { fixture ->
            val result = fixture.fetcher().fetch(FIXTURE_INPUT)
            assertTrue("Fixture must have sent the 200 image headers", fixture.headersSent.get())
            assertFailure(result, PushAvatarReason.NETWORK_TIMEOUT, PushAvatarOutcome.RETRY)
            fixture.assertSingleRequest()
        }
    }

    @Test(timeout = 12_000) fun successfulImageSurvivesRealAndroidHttpTransport() {
        val png = validPng()
        HttpFixture(status = 200, body = png).use { fixture ->
            val result = fixture.fetcher().fetch(FIXTURE_INPUT)
            assertTrue("Expected complete image bytes", result is PushAvatarFetchResult.Bytes)
            val bytes = (result as PushAvatarFetchResult.Bytes).value
            assertArrayEquals(png, bytes)
            val image = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            assertNotNull("Transport result must remain a decodable PNG", image)
            image!!.let {
                try {
                    assertEquals(2, it.width)
                    assertEquals(2, it.height)
                    assertEquals(Color.MAGENTA, it.getPixel(1, 1))
                } finally { it.recycle() }
            }
            fixture.assertSingleRequest()
        }
    }

    private fun assertHttpFailure(status: Int, reason: PushAvatarReason, outcome: PushAvatarOutcome) {
        HttpFixture(status = status).use { fixture ->
            assertFailure(fixture.fetcher().fetch(FIXTURE_INPUT), reason, outcome)
            fixture.assertSingleRequest()
        }
    }

    private fun assertFailure(result: PushAvatarFetchResult, reason: PushAvatarReason,
                              outcome: PushAvatarOutcome) {
        assertTrue("Expected a classified transport failure", result is PushAvatarFetchResult.Failure)
        val actual = (result as PushAvatarFetchResult.Failure).reason
        assertEquals(reason, actual)
        // This is the real transport result passed to the real retry policy,
        // not a claim that a WorkManager retry has run on the device.
        assertEquals(outcome, PushAvatarPolicy.retry(actual, 0, 1_000L, 61_000L))
    }

    private fun validPng(): ByteArray {
        val image = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
        return try {
            image.eraseColor(Color.MAGENTA)
            ByteArrayOutputStream().use {
                check(image.compress(Bitmap.CompressFormat.PNG, 100, it))
                it.toByteArray()
            }
        } finally { image.recycle() }
    }

    private class HttpFixture(
        private val status: Int,
        private val body: ByteArray = byteArrayOf(),
        private val stallBody: Boolean = false
    ) : Closeable {
        private val loopback = InetAddress.getByAddress(byteArrayOf(127, 0, 0, 1))
        private val server = ServerSocket().apply {
            reuseAddress = false
            bind(InetSocketAddress(loopback, 0), 1)
            soTimeout = 4_000
        }
        private val closed = AtomicBoolean(false)
        private val activeSocket = AtomicReference<Socket?>()
        private val failure = AtomicReference<Throwable?>()
        private val requestCount = AtomicInteger(0)
        private val requestHandled = CountDownLatch(1)
        private val releaseStall = CountDownLatch(1)
        val headersSent = AtomicBoolean(false)
        val redirectRequested = AtomicBoolean(false)
        private val executor = Executors.newSingleThreadExecutor { task ->
            Thread(task, "avatar-loopback-fixture").apply { isDaemon = true }
        }

        init {
            require(body.size <= 1024)
            executor.execute {
                try {
                    // At most two requests: the second exists only to detect an
                    // unexpected transport retry or redirect, never to hide it.
                    repeat(2) {
                        if (closed.get()) return@execute
                        val socket = try { server.accept() } catch (_: SocketTimeoutException) {
                            return@execute
                        }
                        activeSocket.set(socket)
                        socket.use { client ->
                            client.soTimeout = 1_500
                            val firstLine = readHeaders(client)
                            requestCount.incrementAndGet()
                            val isRedirect = firstLine.startsWith("GET /unexpected ")
                            redirectRequested.set(redirectRequested.get() || isRedirect)
                            check(isRedirect || firstLine.startsWith("GET /avatar "))
                            val replyStatus = if (isRedirect) 200 else status
                            val output = client.getOutputStream()
                            val headers = buildString {
                                append("HTTP/1.1 $replyStatus Fixture\r\n")
                                append("Content-Type: image/png\r\n")
                                append("Content-Length: ${body.size}\r\n")
                                append("Connection: close\r\n")
                                if (replyStatus == 302) {
                                    append("Location: http://127.0.0.1:${server.localPort}/unexpected\r\n")
                                }
                                append("\r\n")
                            }
                            output.write(headers.toByteArray(Charsets.US_ASCII))
                            output.flush()
                            headersSent.set(true)
                            requestHandled.countDown()
                            if (stallBody) {
                                // Longer than the fetcher's 1s socket read timeout;
                                // close() releases this latch immediately on failure.
                                releaseStall.await(3_500, TimeUnit.MILLISECONDS)
                            } else {
                                output.write(body)
                                output.flush()
                            }
                        }
                        activeSocket.set(null)
                        server.soTimeout = 300
                    }
                } catch (error: Throwable) {
                    if (!closed.get()) failure.compareAndSet(null, error)
                } finally {
                    requestHandled.countDown()
                }
            }
        }

        fun fetcher() = PushAvatarFetch({ false }, { SystemClock.elapsedRealtime() }) { input ->
            check(input == FIXTURE_INPUT)
            // NO_PROXY bypasses device/global proxy configuration for this local
            // connection without mutating any such settings. No DNS is required.
            URL("http://127.0.0.1:${server.localPort}/avatar")
                .openConnection(Proxy.NO_PROXY) as HttpURLConnection
        }

        fun assertSingleRequest() {
            assertTrue("Local fixture did not handle a request",
                requestHandled.await(1_000, TimeUnit.MILLISECONDS))
            assertNull("Local fixture failed", failure.get())
            assertEquals("Transport must make exactly one request", 1, requestCount.get())
        }

        private fun readHeaders(socket: Socket): String {
            val bytes = ByteArrayOutputStream()
            val input = socket.getInputStream()
            val deadline = SystemClock.elapsedRealtime() + 3_000
            var tail = 0
            while (bytes.size() < 8192) {
                check(SystemClock.elapsedRealtime() < deadline) { "Local request header deadline exceeded" }
                val value = input.read()
                check(value >= 0) { "Incomplete local request headers" }
                bytes.write(value)
                tail = (tail shl 8) or value
                if (tail == 0x0d0a0d0a) {
                    return bytes.toString("US-ASCII").substringBefore("\r\n")
                }
            }
            error("Local request headers exceeded the fixture limit")
        }

        override fun close() {
            closed.set(true)
            releaseStall.countDown()
            try { activeSocket.getAndSet(null)?.close() } catch (_: Exception) { }
            try { server.close() } catch (_: Exception) { }
            executor.shutdownNow()
            assertTrue("Local fixture thread must stop",
                executor.awaitTermination(2_000, TimeUnit.MILLISECONDS))
        }
    }

    companion object {
        // This seam input is never resolved or contacted; production payload
        // validation is intentionally outside this isolated transport test.
        private const val FIXTURE_INPUT = "https://avatar-fixture.invalid/avatar.png"
    }
}
