package com.berkayb.soundconnect.soundconnect_23_12_25codx

import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.security.SecureRandom

internal interface DiagnosticEntropy { fun fill(destination: ByteArray) }
internal class SecureDiagnosticEntropy : DiagnosticEntropy {
    override fun fill(destination: ByteArray) { SecureRandom().nextBytes(destination) }
}
internal interface DiagnosticHmac {
    fun digest(domain: Byte, recipient: ByteArray, identity: ByteArray, destination: ByteArray, offset: Int)
    fun clear()
}
internal interface DiagnosticCryptoFactory { fun prepare(key: ByteArray): DiagnosticHmac }
internal class JvmDiagnosticCrypto : DiagnosticCryptoFactory {
    override fun prepare(key: ByteArray): DiagnosticHmac {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return object : DiagnosticHmac {
            override fun digest(domain: Byte, recipient: ByteArray, identity: ByteArray, destination: ByteArray, offset: Int) {
                // Distinct fixed domains + two fixed 16-byte normalized identities; no string/UUID parsing.
                mac.update(domain); mac.update(recipient); mac.update(identity); mac.doFinal(destination, offset)
            }
            override fun clear() { mac.reset(); mac.init(SecretKeySpec(ByteArray(32), "HmacSHA256")) }
        }
    }
}

internal class TableDiagnosticsAliases(private val arena: ByteArray, factory: DiagnosticCryptoFactory, key: ByteArray) {
    private val workers = arrayOfNulls<DiagnosticHmac>(8)
    private val scratch = Array(8) { ByteArray(64) }
    var notifications = 0; private set
    var scopes = 0; private set
    init {
        try { for (i in workers.indices) workers[i] = factory.prepare(key) }
        catch (e: Exception) { clear(); throw e }
    }
    internal data class Candidate(val notification: Int, val scope: Int, val newNotification: Boolean, val newScope: Boolean)
    fun prepare(writer: Int, recipient: ByteArray, notification: ByteArray, epoch: ByteArray?): Candidate? {
        require(writer in 0..7 && recipient.size == 16 && notification.size == 16 && (epoch == null || epoch.size == 16))
        val out = scratch[writer]
        out.fill(0)
        workers[writer]!!.digest(1, recipient, notification, out, 0)
        if (epoch != null) workers[writer]!!.digest(2, recipient, epoch, out, 32)
        val n = lookup(TableDiagnosticsBuffer.ALIASES, notifications, out, 0)
        val s = if (epoch == null) 0 else lookup(TableDiagnosticsBuffer.SCOPES, scopes, out, 32)
        if (n == 0 && notifications == 64 || epoch != null && s == 0 && scopes == 16) return null
        return Candidate(if (n == 0) notifications + 1 else n,
            if (epoch != null && s == 0) scopes + 1 else s, n == 0, epoch != null && s == 0)
    }
    /** Called only after a valid record commits, under the core's single-CAS ownership. */
    fun commit(writer: Int, candidate: Candidate) {
        if (candidate.newNotification) {
            scratch[writer].copyInto(arena, TableDiagnosticsBuffer.ALIASES + notifications * 32, 0, 32)
            notifications++
        }
        if (candidate.newScope) {
            scratch[writer].copyInto(arena, TableDiagnosticsBuffer.SCOPES + scopes * 32, 32, 64)
            scopes++
        }
        scratch[writer].fill(0)
    }
    fun forgetScratch(writer: Int) { scratch[writer].fill(0) }
    private fun lookup(base: Int, size: Int, digest: ByteArray, offset: Int): Int {
        for (entry in 0 until size) {
            var different = 0
            for (i in 0 until 32) different = different or (arena[base + entry * 32 + i].toInt() xor digest[offset + i].toInt())
            if (different == 0) return entry + 1
        }
        return 0
    }
    fun clear() {
        for (i in workers.indices) {
            try { workers[i]?.clear() } catch (_: Exception) { /* no exception object retained */ }
            workers[i] = null
            scratch[i].fill(0)
        }
        arena.fill(0, TableDiagnosticsBuffer.ALIASES, TableDiagnosticsBuffer.SCOPES + 16 * 32)
        notifications = 0; scopes = 0
    }
}
