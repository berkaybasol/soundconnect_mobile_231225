package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.app.NotificationManager
import android.content.Context
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.util.UUID

/** No bearer/FCM token here. No-backup storage prevents restored account bindings. */
object PushNotificationState {
    private val lock = Any()
    const val CHANNEL = "soundconnect_notifications"
    data class Binding(val recipient: String, val epoch: String)
    private fun file(context: Context) = AtomicFile(File(context.noBackupFilesDir, "soundconnect-push-rendering"))
    private fun read(context: Context): JSONObject = try {
        JSONObject(String(file(context).readFully(), Charsets.UTF_8))
    } catch (_: Exception) { JSONObject() }
    private fun write(context: Context, json: JSONObject) {
        val storage = file(context)
        val stream = storage.startWrite()
        try { stream.write(json.toString().toByteArray(Charsets.UTF_8)); storage.finishWrite(stream) }
        catch (error: Exception) { storage.failWrite(stream); throw error }
    }
    fun bind(context: Context, recipient: String?) = synchronized(lock) {
        val state = read(context)
        val normalized = if (PushFeatureGate.enabled(context)) PushNotificationPayload.uuid(recipient) else null
        if (normalized != state.optString("recipientId").ifEmpty { null } || normalized == null || state.optString("epoch").isBlank()) {
            write(context, JSONObject().put("recipientId", normalized ?: "").put("epoch", UUID.randomUUID().toString()))
            clearDelivered(context)
            // WorkManager persists cleanup; no slow ShortcutManager operation
            // may run while the platform main thread owns this binding lock.
            PushConversationShortcuts.scheduleCleanup(context)
        }
    }
    internal fun setResetRequired(context: Context, required: Boolean) = synchronized(lock) {
        // A successful token deletion may have swallowed a failed native clear.
        // Persist a fresh empty binding before releasing the independent latch.
        if (!required) bind(context, null)
        PushResetState.setRequired(context, required)
        if (required) {
            clearDelivered(context)
            PushConversationShortcuts.scheduleCleanup(context)
        }
    }
    fun capture(context: Context, recipient: String): Binding? = synchronized(lock) {
        if (!PushFeatureGate.enabled(context) || PushResetState.blocksRendering(context)) return@synchronized null
        val state = read(context)
        if (state.optString("recipientId") != recipient || state.optString("epoch").isBlank()) null
        else Binding(recipient, state.getString("epoch"))
    }
    fun currentBinding(context: Context): Binding? = synchronized(lock) {
        if (!PushFeatureGate.enabled(context) || PushResetState.blocksRendering(context)) return@synchronized null
        val state = read(context)
        val recipient = PushNotificationPayload.uuid(state.optString("recipientId"))
        val epoch = PushNotificationPayload.uuid(state.optString("epoch"))
        if (recipient == null || epoch == null) null else Binding(recipient, epoch)
    }
    fun current(context: Context, binding: Binding): Boolean = capture(context, binding.recipient) == binding
    /** Atomic check+update prevents a logout racing an avatar update. */
    fun post(context: Context, binding: Binding, notificationId: String? = null,
             action: () -> Boolean): Boolean = synchronized(lock) {
        if (!current(context, binding)) false
        else if (notificationId == null) action()
        else try {
            if (PushNotificationPayload.uuid(notificationId) != notificationId
                || !PushNotificationLedger.mayUpdate(context, binding.recipient, notificationId,
                    System.currentTimeMillis())) false else action()
        } catch (_: Exception) { false }
    }

    /**
     * Reserve durably before notifying, under the same lock as logout. A process
     * death between the commit and Android notify can omit an OS alert (the inbox
     * remains authoritative), but cannot resurrect a dismissed alert on retry.
     * The ledger is separate from the binding, so logout/relogin does not erase it.
     */
    fun postInitial(context: Context, binding: Binding, id: String, expiresAt: Long,
                    action: () -> Boolean): Boolean = synchronized(lock) {
        if (!current(context, binding) || PushNotificationPayload.uuid(id) != id) false
        else try {
            if (!PushNotificationLedger.reserve(context, binding.recipient, id,
                    expiresAt, System.currentTimeMillis())) false
            else action()
        } catch (_: Exception) {
            // Storage errors/full ledger fail closed; never discard older dedup IDs.
            false
        }
    }

    /** Optional fast path only; postInitial always checks again atomically. */
    fun seen(context: Context, binding: Binding, id: String): Boolean = synchronized(lock) {
        if (!current(context, binding)) true
        else try {
            PushNotificationLedger.seen(context, binding.recipient, id, System.currentTimeMillis())
        } catch (_: Exception) { true }
    }
    internal fun deliveredSnapshot(context: Context, recipient: String): Map<String, Any>? = synchronized(lock) {
        val binding = currentBinding(context) ?: return@synchronized null
        if (binding.recipient != recipient) return@synchronized null
        reconcileDeliveredGroups(context, binding)
        PushDeliveredPolicy.snapshot(PushDeliveredPolicy.Scope(binding.recipient, binding.epoch),
            recipient, deliveredEntries(context))?.toMap()
    }

    internal fun dismissDelivered(context: Context, request: PushDeliveredPolicy.DismissRequest) = synchronized(lock) {
        val binding = currentBinding(context) ?: return@synchronized
        val scope = PushDeliveredPolicy.Scope(binding.recipient, binding.epoch)
        if (scope != request.scope || request.notificationIds.isEmpty()) return@synchronized
        val manager = context.getSystemService(NotificationManager::class.java)
        // Same lock as avatar post/current binding. Never reset the binding or clear the channel.
        val targets = PushDeliveredPolicy.dismissTargets(scope, request, deliveredEntries(context))
        // Android cancellation is queued remotely. Persist before cancel, so an
        // avatar update cannot trust a briefly stale OS active-notification list.
        // Storage failure throws before cancel; update eligibility also fails closed.
        PushNotificationLedger.markDismissed(context, binding.recipient, request.notificationIds)
        targets.forEach {
            manager.cancel(it.tag, it.androidId)
        }
        reconcileDeliveredGroups(context, binding)
    }

    internal fun reconcileGroup(context: Context, binding: Binding,
                                scheduleRepair: Boolean = true): Boolean = synchronized(lock) {
        if (current(context, binding)) PushNotificationGroups.reconcileLocked(context, binding,
            scheduleRepair = scheduleRepair) else true
    }

    internal fun reconcileVenueGroup(context: Context, binding: Binding,
                                     scheduleRepair: Boolean = true): Boolean = synchronized(lock) {
        if (current(context, binding)) VenueNotificationGroups.reconcileLocked(context, binding,
            scheduleRepair = scheduleRepair) else true
    }

    private fun reconcileDeliveredGroups(context: Context, binding: Binding) {
        // Attempt both independent groups, even if one group's platform update fails.
        // Propagate failures so the caller can retry; no unknown card is authorized.
        val dm = runCatching { PushNotificationGroups.reconcileLocked(context, binding) }
        val venue = runCatching { VenueNotificationGroups.reconcileLocked(context, binding) }
        dm.getOrThrow()
        venue.getOrThrow()
    }

    internal fun dismissNotification(context: Context, binding: Binding, id: String) =
        dismissGroup(context, binding, setOf(id))

    /** Immutable delete-intent IDs remain valid after Android already removed their cards. */
    internal fun dismissGroup(context: Context, binding: Binding, ids: Set<String>) = synchronized(lock) {
        if (!current(context, binding) || ids.isEmpty() || ids.size > PushDeliveredPolicy.MAX_IDS ||
            ids.any { PushNotificationPayload.uuid(it) != it }) return@synchronized
        PushNotificationLedger.markDismissed(context, binding.recipient, ids)
        val manager = context.getSystemService(NotificationManager::class.java)
        // A canonical UUID denotes one durable delivery and is not reused across epochs.
        ids.forEach { manager.cancel(it, 0) }
        reconcileDeliveredGroups(context, binding)
    }

    internal fun expireNotification(context: Context, binding: Binding, id: String,
                                    expiresAt: Long, now: Long = System.currentTimeMillis()) = synchronized(lock) {
        if (!current(context, binding) || PushNotificationPayload.uuid(id) != id ||
            expiresAt <= 0 || now < expiresAt) return@synchronized
        val savedExpiry = PushNotificationLedger.expiry(context, binding.recipient, id)
        if (savedExpiry != null && savedExpiry != expiresAt) return@synchronized
        val manager = context.getSystemService(NotificationManager::class.java)
        if (savedExpiry == null) {
            // reserve() prunes expired reservations. A delayed expiry worker must
            // still remove its scoped OS card, especially on API 24-25. Never
            // cancel an unrelated current account's card from a legacy worker.
            val scope = PushDeliveredPolicy.Scope(binding.recipient, binding.epoch)
            val owned = PushDeliveredPolicy.dismissTargets(scope,
                PushDeliveredPolicy.DismissRequest(scope, setOf(id)), deliveredEntries(context))
            owned.forEach { entry ->
                val active = manager.activeNotifications.firstOrNull { it.tag == entry.tag && it.id == entry.androidId }
                val activeExpiry = active?.notification?.extras?.getLong(PushNotificationGroups.EXPIRY_EXTRA, 0) ?: 0
                // Older installed cards have no expiry extra; their stored worker
                // already provides its due time. New cards must match exactly.
                if (activeExpiry == 0L || activeExpiry == expiresAt) manager.cancel(entry.tag, entry.androidId)
            }
        } else {
            PushNotificationLedger.markDismissed(context, binding.recipient, setOf(id))
            manager.cancel(id, 0)
        }
        reconcileDeliveredGroups(context, binding)
    }

    private fun deliveredEntries(context: Context): List<PushDeliveredPolicy.Entry> {
        val manager = context.getSystemService(NotificationManager::class.java)
        return manager.activeNotifications.map { active ->
            val extras = active.notification.extras
            PushDeliveredPolicy.Entry(active.tag, active.id,
                android.os.Build.VERSION.SDK_INT < 26 || active.notification.channelId == CHANNEL,
                extras?.getString(PushDeliveredPolicy.RECIPIENT_EXTRA),
                extras?.getString(PushDeliveredPolicy.EPOCH_EXTRA),
                extras?.getString(PushDeliveredPolicy.ID_EXTRA))
        }
    }

    fun clearDelivered(context: Context) = synchronized(lock) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.activeNotifications.filter {
            if (android.os.Build.VERSION.SDK_INT >= 26) it.notification.channelId == CHANNEL
            else PushNotificationPayload.uuid(it.tag) != null || PushNotificationGroups.isSummaryTag(it.tag)
                || VenueNotificationGroups.isSummaryTag(it.tag)
        }.forEach { manager.cancel(it.tag, it.id) }
    }
}
