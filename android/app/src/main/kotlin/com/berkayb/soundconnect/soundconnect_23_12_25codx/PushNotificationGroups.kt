package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.work.BackoffPolicy
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

/** Standard Android grouping. All calls that inspect or change a group hold the binding lock. */
internal object PushNotificationGroups {
    const val SUMMARY_ID = 1
    const val EXPIRY_EXTRA = "sc.push.expiresAt"
    const val SUMMARY_EXTRA = "sc.push.dmGroupSummary"
    private const val SIGNATURE_EXTRA = "sc.push.dmGroupSignature"
    const val IDS_EXTRA = "sc.push.dismissedIds"
    const val DISMISS_ACTION = "com.soundconnect.DISMISS_DM_NOTIFICATION"
    const val DISMISS_GROUP_ACTION = "com.soundconnect.DISMISS_DM_GROUP"
    private const val PREFIX = "sc.dm.group:"

    fun groupKey(binding: PushNotificationState.Binding) = "$PREFIX${binding.recipient}:${binding.epoch}"
    fun summaryTag(binding: PushNotificationState.Binding) = "${groupKey(binding)}:summary"
    fun isSummaryTag(tag: String?): Boolean = tag?.startsWith(PREFIX) == true && tag.endsWith(":summary")

    fun deleteIntent(context: Context, binding: PushNotificationState.Binding,
                     ids: Set<String>, group: Boolean = false): PendingIntent {
        // A replaced summary must not mutate a previously delivered delete callback:
        // its immutable identity includes the exact represented set and binding epoch.
        val canonicalIds = ids.sorted()
        val digest = signature(ids)
        val intent = Intent(context, PushNotificationDismissReceiver::class.java).apply {
            action = if (group) DISMISS_GROUP_ACTION else DISMISS_ACTION
            data = Uri.parse("soundconnect-push://dismiss/${binding.recipient}/${binding.epoch}/${if (group) "group" else "child"}/$digest")
            putExtra(PushDeliveredPolicy.RECIPIENT_EXTRA, binding.recipient)
            putExtra(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
            putStringArrayListExtra(IDS_EXTRA, ArrayList(canonicalIds))
        }
        return PendingIntent.getBroadcast(context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** The ledger excludes canceled-but-still-active Android rows before a summary can be rebuilt. */
    fun reconcileLocked(context: Context, binding: PushNotificationState.Binding,
                        posted: Notification? = null, postedId: String? = null,
                        scheduleRepair: Boolean = true): Boolean {
        if (!PushNotificationState.current(context, binding)) return true
        val manager = context.getSystemService(NotificationManager::class.java)
        val now = System.currentTimeMillis()
        val candidates = linkedMapOf<String, Notification>()
        val activeNotifications = manager.activeNotifications
        activeNotifications.forEach { active ->
            if (ownedChild(active.tag, active.id, active.notification, binding)) {
                candidates[active.tag!!] = active.notification
            }
        }
        // notify() queues work in system_server. Include the child just posted under
        // this lock even if activeNotifications has not caught up yet.
        if (posted != null && ownedChild(postedId, 0, posted, binding)) candidates[postedId!!] = posted
        val eligible = PushNotificationLedger.eligibleIds(context, binding.recipient, candidates.keys, now)
        val children = candidates.filter { (id, notification) ->
            id in eligible && notification.extras.getLong(EXPIRY_EXTRA, 0) > now
        }
        // In particular API 24-25 has no platform timeout. A new reservation
        // may have pruned an expired ledger row before its delayed worker runs.
        // Remove only this group's verified owned stale cards, not just its count.
        (candidates.keys - children.keys).forEach { manager.cancel(it, 0) }
        val existing = activeNotifications.firstOrNull { active ->
            val notification = active.notification
            active.tag == summaryTag(binding) && active.id == SUMMARY_ID
                && (Build.VERSION.SDK_INT < 26 || notification.channelId == PushNotificationState.CHANNEL)
                && notification.group == groupKey(binding)
                && notification.flags and Notification.FLAG_GROUP_SUMMARY != 0
                && notification.extras.getBoolean(SUMMARY_EXTRA, false)
                && notification.extras.getString(PushDeliveredPolicy.RECIPIENT_EXTRA) == binding.recipient
                && notification.extras.getString(PushDeliveredPolicy.EPOCH_EXTRA) == binding.epoch
        }?.notification
        if (children.isEmpty()) {
            // Canceling a summary can cancel its children in Android. This branch
            // is only entered after every owned child is absent or tombstoned/expired.
            if (existing == null) return true
            try { manager.cancel(summaryTag(binding), SUMMARY_ID) }
            finally { if (scheduleRepair) scheduleReconciliation(context, binding) }
            return false
        }
        val latestExpiry = children.values.maxOf { it.extras.getLong(EXPIRY_EXTRA) }
        val latestTime = children.values.maxOf { it.`when` }
        val signature = signature(children.keys)
        val summaryAccent = ContextCompat.getColor(context, R.color.soundconnect_group_accent)
        // Avatar, shortcut and inbox reconciliation do not change this generic
        // summary. Avoid spending Android's package update quota on identical
        // notifications; only trust an actually active summary, never a notify()
        // attempt, because system_server can shed updates without an exception.
        if (existing != null && existing.extras.getString(SIGNATURE_EXTRA) == signature
            && existing.number == children.size && existing.`when` == latestTime
            && existing.extras.getLong(EXPIRY_EXTRA, 0) == latestExpiry
            && existing.smallIcon?.resId == R.drawable.ic_notification
            && existing.iconLevel == 0
            && existing.color == summaryAccent) return true
        val open = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            data = Uri.parse("soundconnect-push://group/${binding.recipient}/${binding.epoch}")
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(context, 0, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val generic = if (children.size == 1) "Yeni bir mesajın var." else "${children.size} yeni mesajın var."
        // The same original vector and distinct summary/child accents let Android
        // preserve the child brand color instead of hiding or graying its icon.
        val publicVersion = NotificationCompat.Builder(context, PushNotificationState.CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(summaryAccent)
            .setContentTitle("Soundconnect").setContentText("Yeni mesajların var.")
            .setGroup(groupKey(binding)).setGroupSummary(true)
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)
            .setOnlyAlertOnce(true).setSilent(true).build()
        val summary = NotificationCompat.Builder(context, PushNotificationState.CHANNEL)
            .addExtras(Bundle().apply {
                putString(PushDeliveredPolicy.RECIPIENT_EXTRA, binding.recipient)
                putString(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
                putBoolean(SUMMARY_EXTRA, true)
                putString(SIGNATURE_EXTRA, signature)
                putLong(EXPIRY_EXTRA, latestExpiry)
            })
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(summaryAccent)
            .setContentTitle("Soundconnect").setContentText(generic)
            .setNumber(children.size)
            .setGroup(groupKey(binding)).setGroupSummary(true)
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)
            .setOnlyAlertOnce(true).setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setPublicVersion(publicVersion)
            .setContentIntent(pending)
            // Opening the group launches the app. Only actual read reconciliation
            // removes messages; auto-cancel here would cascade to all children.
            .setAutoCancel(false)
            .setDeleteIntent(deleteIntent(context, binding, children.keys, group = true))
            .setWhen(latestTime)
            // Do not set a summary OS timeout: Android can shed a newer summary
            // update under its package quota. An older timeout would then cancel
            // newer live children too. Each child retains its own OS deadline;
            // expiry workers and resume reconciliation remove the empty summary.
            // A delayed worker can leave a generic summary until reconciliation.
            .build()
        // Retain the summary for a single child: removing it would remove that
        // child too. Android owns whether the one-child header is displayed.
        try { manager.notify(summaryTag(binding), SUMMARY_ID, summary) }
        finally { if (scheduleRepair) scheduleReconciliation(context, binding) }
        return false
    }

    /** A notify attempt is not confirmation: Android can silently shed summary updates. */
    private fun scheduleReconciliation(context: Context, binding: PushNotificationState.Binding) {
        runCatching {
            val request = OneTimeWorkRequest.Builder(PushGroupReconcileWorker::class.java)
                .setInputData(Data.Builder().putString("recipientId", binding.recipient)
                    .putString("bindingEpoch", binding.epoch).build())
                // Coalesce a burst after its last group mutation. The durable work
                // also survives FCM process shutdown and contains no sender data.
                .setInitialDelay(2, TimeUnit.SECONDS)
                .setBackoffCriteria(BackoffPolicy.LINEAR, 10, TimeUnit.SECONDS)
                .build()
            WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
                "push-group-reconcile-${binding.recipient}-${binding.epoch}",
                ExistingWorkPolicy.REPLACE, request)
        }
    }

    private fun signature(ids: Set<String>): String = MessageDigest.getInstance("SHA-256")
        .digest(ids.sorted().joinToString(",").toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    private fun ownedChild(tag: String?, id: Int, notification: Notification,
                           binding: PushNotificationState.Binding): Boolean {
        val extras = notification.extras
        return id == 0 && PushNotificationPayload.uuid(tag) == tag && tag != null
            && (Build.VERSION.SDK_INT < 26 || notification.channelId == PushNotificationState.CHANNEL)
            && notification.group == groupKey(binding)
            && extras.getString(PushDeliveredPolicy.ID_EXTRA) == tag
            && extras.getString(PushDeliveredPolicy.RECIPIENT_EXTRA) == binding.recipient
            && extras.getString(PushDeliveredPolicy.EPOCH_EXTRA) == binding.epoch
            && !extras.getBoolean(SUMMARY_EXTRA, false)
    }
}

/** Repairs only a summary of currently present, eligible children; never reposts a child. */
class PushGroupReconcileWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result = reconcile(applicationContext, inputData.getString("recipientId"),
        inputData.getString("bindingEpoch"), runAttemptCount, isStopped)

    companion object {
        internal fun reconcile(context: Context, recipientId: String?, bindingEpoch: String?,
                               attempt: Int, stopped: Boolean = false): Result {
            val recipient = PushNotificationPayload.uuid(recipientId) ?: return Result.success()
            val epoch = PushNotificationPayload.uuid(bindingEpoch) ?: return Result.success()
            if (stopped) return Result.success()
            val confirmed = runCatching {
                PushNotificationState.reconcileGroup(context,
                    PushNotificationState.Binding(recipient, epoch), scheduleRepair = false)
            }.getOrDefault(false)
            return if (confirmed || attempt >= 3) Result.success() else Result.retry()
        }
    }
}

/** Non-exported immutable PendingIntent target. Dismissal never acknowledges server reads. */
class PushNotificationDismissReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != PushNotificationGroups.DISMISS_ACTION &&
            intent.action != PushNotificationGroups.DISMISS_GROUP_ACTION) return
        val recipient = PushNotificationPayload.uuid(intent.getStringExtra(PushDeliveredPolicy.RECIPIENT_EXTRA)) ?: return
        val epoch = PushNotificationPayload.uuid(intent.getStringExtra(PushDeliveredPolicy.EPOCH_EXTRA)) ?: return
        val ids = intent.getStringArrayListExtra(PushNotificationGroups.IDS_EXTRA) ?: return
        if (ids.isEmpty() || ids.size > PushDeliveredPolicy.MAX_IDS ||
            ids.any { PushNotificationPayload.uuid(it) != it }) return
        if (intent.action == PushNotificationGroups.DISMISS_ACTION && ids.size != 1) return
        try {
            PushNotificationState.dismissGroup(context, PushNotificationState.Binding(recipient, epoch), ids.toSet())
        } catch (_: Exception) {
            // A storage failure cannot authorize a repost. Renderer/worker guards
            // also require current Android presence and a readable eligible ledger.
        }
    }
}
