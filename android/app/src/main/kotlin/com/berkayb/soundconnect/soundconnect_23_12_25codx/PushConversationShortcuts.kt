package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.Context
import android.content.Intent
import android.content.LocusId
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.drawable.Icon
import android.os.Build
import androidx.core.app.Person
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters

/** Slow OS calls are serialized on worker threads, never under the binding lock. */
internal object PushConversationShortcuts {
    private val shortcutLock = Any()
    private const val CLEANUP_WORK = "soundconnect-push-shortcut-cleanup"

    fun publish(context: Context, payload: PushNotificationPayload,
                binding: PushNotificationState.Binding, person: Person,
                avatar: Bitmap, intent: Intent): String? = synchronized(shortcutLock) {
        if (Build.VERSION.SDK_INT < 30) return@synchronized null
        if (!PushNotificationState.current(context, binding)) return@synchronized null
        try {
            val manager = context.getSystemService(ShortcutManager::class.java)
            val id = PushShortcutScope.id(binding.recipient, binding.epoch, payload.conversationId)
            val shortcutIntent = Intent(intent).apply {
                action = "com.soundconnect.OPEN_CONVERSATION"
                data = android.net.Uri.parse("soundconnect-push://conversation/$id")
                removeExtra("sc.push.notificationId")
            }
            val shortcut = ShortcutInfo.Builder(context, id)
                .setShortLabel(payload.senderName).setLongLabel(payload.senderName)
                .setIcon(Icon.createWithBitmap(avatar)).setIntent(shortcutIntent)
                .setPersons(arrayOf(person.toAndroidPerson())).setLongLived(true)
                .setLocusId(LocusId(id)).build()
            manager.enableShortcuts(listOf(id))
            manager.pushDynamicShortcut(shortcut)
            if (PushNotificationState.current(context, binding)) id
            else {
                // Logout may have happened while a slow OEM call was running.
                // Its cleanup shares this worker lock and removes this epoch.
                scheduleCleanup(context)
                null
            }
        } catch (_: Exception) { null } // Message still appears if an OEM denies shortcuts.
    }

    fun scheduleCleanup(context: Context) {
        if (Build.VERSION.SDK_INT < 30) return
        runCatching {
            val request = OneTimeWorkRequest.Builder(PushShortcutCleanupWorker::class.java)
            if (Build.VERSION.SDK_INT >= 31) request.setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(CLEANUP_WORK,
                ExistingWorkPolicy.REPLACE, request.build())
        }
    }

    fun clearStale(context: Context): Boolean = synchronized(shortcutLock) {
        if (Build.VERSION.SDK_INT < 30) return@synchronized true
        try {
            val manager = context.getSystemService(ShortcutManager::class.java)
            val snapshot = manager.getShortcuts(ShortcutManager.FLAG_MATCH_DYNAMIC or
                ShortcutManager.FLAG_MATCH_CACHED or ShortcutManager.FLAG_MATCH_PINNED)
                .map { it.id }
            val binding = PushNotificationState.currentBinding(context)
            val ids = PushShortcutScope.staleIds(snapshot, binding?.recipient, binding?.epoch)
            if (ids.isEmpty()) return@synchronized true
            // User-pinned shortcuts cannot be removed by an app. Scrub their
            // identity and disable them; their stale target is also authorized in-app.
            val scrubbed = runCatching {
                manager.updateShortcuts(ids.map {
                    ShortcutInfo.Builder(context, it).setShortLabel("Soundconnect")
                        .setLongLabel("Soundconnect")
                        .setPersons(arrayOf(android.app.Person.Builder().setName("Soundconnect").build()))
                        .setIcon(Icon.createWithResource(context, R.drawable.ic_notification)).build()
                })
            }.getOrDefault(false)
            // One failed optional scrub must not skip revocation/removal.
            val disabled = runCatching { manager.disableShortcuts(ids, "Sohbeti görmek için uygulamaya giriş yap.") }.isSuccess
            val removed = runCatching { manager.removeLongLivedShortcuts(ids) }.isSuccess
            scrubbed && disabled && removed
        } catch (_: Exception) { false }
    }
}

class PushShortcutCleanupWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result =
        if (PushConversationShortcuts.clearStale(applicationContext)) Result.success() else Result.retry()
}
