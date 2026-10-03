package com.berkayb.soundconnect.soundconnect_23_12_25codx

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL

internal sealed class PushAvatarFetchResult {
    class Bytes(val value: ByteArray) : PushAvatarFetchResult()
    class Failure(val reason: PushAvatarReason) : PushAvatarFetchResult()
}

/** Receives only a URL already accepted by PushNotificationPayload's exact-host allowlist. */
internal class PushAvatarFetch(
    private val stopped: () -> Boolean,
    private val elapsedMillis: () -> Long,
    private val open: (String) -> HttpURLConnection = { URL(it).openConnection() as HttpURLConnection }
) {
    @Volatile private var connection: HttpURLConnection? = null

    fun cancel() { try { connection?.disconnect() } catch (_: Exception) { /* Already stopping. */ } }

    fun fetch(url: String): PushAvatarFetchResult {
        fun failure(reason: PushAvatarReason) = PushAvatarFetchResult.Failure(reason)
        if (stopped()) return failure(PushAvatarReason.CANCELLED)
        val deadline = elapsedMillis() + 4_000
        try {
            val active = open(url)
            connection = active
            active.instanceFollowRedirects = false
            active.connectTimeout = 1_500
            active.readTimeout = 1_000
            active.useCaches = false
            if (stopped()) return failure(PushAvatarReason.CANCELLED)
            PushAvatarPolicy.httpFailure(active.responseCode)?.let { return failure(it) }
            if (active.contentLengthLong > MAX_BYTES) return failure(PushAvatarReason.OVERSIZE)
            if (!active.contentType.orEmpty().startsWith("image/", ignoreCase = true)) {
                return failure(PushAvatarReason.INVALID_MIME)
            }
            val bytes = ByteArrayOutputStream()
            active.inputStream.use { stream ->
                val buffer = ByteArray(8192)
                while (true) {
                    if (stopped()) return failure(PushAvatarReason.CANCELLED)
                    if (elapsedMillis() >= deadline) return failure(PushAvatarReason.FETCH_DEADLINE)
                    val count = stream.read(buffer)
                    if (count < 0) break
                    if (bytes.size() + count > MAX_BYTES) return failure(PushAvatarReason.OVERSIZE)
                    bytes.write(buffer, 0, count)
                }
            }
            if (stopped()) return failure(PushAvatarReason.CANCELLED)
            if (elapsedMillis() >= deadline) return failure(PushAvatarReason.FETCH_DEADLINE)
            return PushAvatarFetchResult.Bytes(bytes.toByteArray())
        } catch (_: SocketTimeoutException) {
            return failure(if (stopped()) PushAvatarReason.CANCELLED else PushAvatarReason.NETWORK_TIMEOUT)
        } catch (_: IOException) {
            return failure(if (stopped()) PushAvatarReason.CANCELLED else PushAvatarReason.NETWORK_IO)
        } catch (_: Exception) {
            return failure(PushAvatarReason.FETCH_ERROR)
        } finally {
            try { connection?.disconnect() } catch (_: Exception) { /* Preserve the classified result. */ }
            connection = null
        }
    }

    companion object { const val MAX_BYTES = 512 * 1024 }
}
