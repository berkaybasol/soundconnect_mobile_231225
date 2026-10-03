package com.berkayb.soundconnect.soundconnect_23_12_25codx

/** Bounded bridge values only. Never returns notification text, avatars or arbitrary extras. */
internal object PushDeliveredPolicy {
    const val MAX_IDS = 100
    const val RECIPIENT_EXTRA = "sc.push.recipientId"
    const val EPOCH_EXTRA = "sc.push.bindingEpoch"
    const val ID_EXTRA = "sc.push.notificationId"

    data class Scope(val recipientId: String, val bindingEpoch: String)
    data class Entry(val tag: String?, val androidId: Int, val channelMatches: Boolean,
                     val recipientId: String?, val bindingEpoch: String?, val notificationId: String?)
    data class DismissRequest(val scope: Scope, val notificationIds: Set<String>)
    data class Snapshot(val scope: Scope, val notificationIds: List<String>) {
        fun toMap(): Map<String, Any> = mapOf("recipientId" to scope.recipientId,
            "bindingEpoch" to scope.bindingEpoch, "notificationIds" to notificationIds)
    }

    fun snapshotRecipient(arguments: Any?): String? =
        ((arguments as? Map<*, *>)?.get("recipientId") as? String)?.takeIf(::canonical)

    fun dismissRequest(arguments: Any?): DismissRequest? {
        val args = arguments as? Map<*, *> ?: return null
        val recipient = (args["recipientId"] as? String)?.takeIf(::canonical) ?: return null
        val epoch = (args["bindingEpoch"] as? String)?.takeIf(::canonical) ?: return null
        val ids = args["notificationIds"] as? List<*> ?: return null
        if (ids.size > MAX_IDS || ids.any { it !is String || !canonical(it) }) return null
        return DismissRequest(Scope(recipient, epoch), ids.filterIsInstance<String>().toSet())
    }

    fun snapshot(scope: Scope?, requestedRecipient: String, active: List<Entry>): Snapshot? {
        if (!valid(scope) || scope!!.recipientId != requestedRecipient || !canonical(requestedRecipient)) return null
        return Snapshot(scope, active.asSequence().filter { owned(scope, it) }
            .map { it.notificationId!! }.distinct().sorted().take(MAX_IDS).toList())
    }

    fun dismissTargets(scope: Scope?, request: DismissRequest, active: List<Entry>): List<Entry> {
        if (!valid(scope) || scope != request.scope || request.notificationIds.size > MAX_IDS
            || request.notificationIds.any { !canonical(it) }) return emptyList()
        return active.filter { owned(scope!!, it) && it.notificationId in request.notificationIds }
    }

    private fun owned(scope: Scope, entry: Entry): Boolean = entry.channelMatches && entry.androidId == 0
        && entry.recipientId == scope.recipientId && entry.bindingEpoch == scope.bindingEpoch
        && canonical(entry.notificationId) && entry.notificationId == entry.tag

    private fun valid(scope: Scope?) = scope != null && canonical(scope.recipientId) && canonical(scope.bindingEpoch)
    private fun canonical(value: String?) = value != null && PushNotificationPayload.uuid(value) == value
}
