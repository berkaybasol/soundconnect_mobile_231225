package com.berkayb.soundconnect.soundconnect_23_12_25codx

/** Epochs are never reused, including when the same account signs in again. */
internal object PushShortcutScope {
    private const val OWNED_PREFIX = "soundconnect-dm-"
    private fun prefix(recipient: String, epoch: String) = "${OWNED_PREFIX}v2-$recipient-$epoch-"
    fun id(recipient: String, epoch: String, conversation: String): String =
        prefix(recipient, epoch) + conversation

    // Enumerate OS IDs before capturing the current binding. A later publish
    // cannot enter this snapshot, and a new epoch cannot reuse a removed ID.
    fun staleIds(snapshot: List<String>, recipient: String?, epoch: String?): List<String> {
        val currentPrefix = if (recipient != null && epoch != null) prefix(recipient, epoch) else null
        return snapshot.filter { it.startsWith(OWNED_PREFIX) &&
            (currentPrefix == null || !it.startsWith(currentPrefix)) }
    }
}
