package com.berkayb.soundconnect.soundconnect_23_12_25codx

/** Storage operations run inside one SQLite transaction, under the account lock. */
internal interface PushLedgerEntries {
    fun removeExpired(now: Long)
    fun contains(recipient: String, notification: String): Boolean
    fun count(): Long
    fun insert(recipient: String, notification: String, expiresAt: Long)
}

/** No account epoch here: a seen delivery remains seen across logout and restart. */
internal object PushNotificationLedgerPolicy {
    const val MAX_ENTRIES = 100_000L
    const val MAX_TTL_MILLIS = 28L * 86400 * 1000

    fun reserve(entries: PushLedgerEntries, recipient: String, notification: String,
                expiresAt: Long, now: Long, maximum: Long = MAX_ENTRIES): Boolean {
        if (now < 0 || expiresAt <= now || expiresAt - now > MAX_TTL_MILLIS) return false
        entries.removeExpired(now)
        if (entries.contains(recipient, notification) || entries.count() >= maximum) return false
        entries.insert(recipient, notification, expiresAt)
        return true
    }
}
