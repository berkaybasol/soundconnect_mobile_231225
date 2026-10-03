package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.Manifest
import android.app.ActivityManager
import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.IconCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import java.util.concurrent.TimeUnit
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters

/** Renders Android DM even when Flutter is not running. FlutterFire keeps token/foreground events. */
class SoundconnectMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        if (!PushFeatureGate.enabled(this)) return
        // The plugin's separate receiver still drives foreground reconciliation.
        val renderer = DmNotificationRenderer(this)
        if (renderer.foreground() || !NotificationManagerCompat.from(this).areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(this,
                Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val avatarHost = applicationInfo.metaData?.getString("com.soundconnect.push_avatar_host").orEmpty()
        // applicationInfo from Context need not include meta-data; read it explicitly.
        @Suppress("DEPRECATION")
        val configuredHost = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            .metaData?.getString("com.soundconnect.push_avatar_host") ?: avatarHost
        val payload = PushNotificationPayload.parse(remoteMessage.data, System.currentTimeMillis(), configuredHost)
            ?: run {
                VenueNotificationRenderer(this).receive(remoteMessage.data)
                return
            }
        val binding = PushNotificationState.capture(this, payload.recipientId) ?: return
        if (PushNotificationState.seen(this, binding, payload.notificationId)) return
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(
            PushNotificationState.CHANNEL, "Soundconnect bildirimleri", NotificationManager.IMPORTANCE_HIGH
        ).apply { description = "Mesajlar ve uygulama güncellemeleri" })
        val fallback = renderer.fallbackAvatar(payload.senderName)
        if (!renderer.post(payload, binding, fallback, false)) return
        // Android timeouts do not invoke deleteIntent. Reconcile the group on
        // every API level when each child expires. The summary has no OS timeout,
        // because a stale summary deadline could prematurely cancel newer siblings.
        // WorkManager remains best-effort; API 24-25 has no OS timeout fallback.
        try {
            val expiry = OneTimeWorkRequest.Builder(PushExpiryWorker::class.java)
                .setInputData(Data.Builder().putString("notificationId", payload.notificationId)
                    .putString("recipientId", binding.recipient).putString("bindingEpoch", binding.epoch)
                    .putLong("expiresAt", payload.expiresAt).build())
                .setInitialDelay((payload.expiresAt - System.currentTimeMillis()).coerceAtLeast(0), TimeUnit.MILLISECONDS)
                .build()
            WorkManager.getInstance(this).enqueueUniqueWork("push-expiry-${payload.notificationId}", ExistingWorkPolicy.KEEP, expiry)
        } catch (_: Exception) { /* In-app source and tap authorization remain authoritative. */ }
        // Network/DNS never holds the FCM callback open. Failure only leaves the
        // already-visible initial avatar; WorkManager owns the process lifetime.
        if (payload.avatarUrl != null) {
            try {
                val data = Data.Builder()
                remoteMessage.data.forEach { (key, value) -> data.putString(key, value) }
                data.putString("bindingEpoch", binding.epoch)
                val work = OneTimeWorkRequest.Builder(PushAvatarWorker::class.java)
                    .setInputData(data.build())
                    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, PushAvatarPolicy.BACKOFF_MS, TimeUnit.MILLISECONDS)
                    .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                if (Build.VERSION.SDK_INT >= 31) work.setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                WorkManager.getInstance(this).enqueueUniqueWork("push-avatar-${payload.notificationId}",
                    ExistingWorkPolicy.KEEP, work.build())
                PushAvatarDiagnostics.record(this, PushAvatarOutcome.ENQUEUE_REQUESTED, PushAvatarReason.ENQUEUE_REQUESTED, 0)
            } catch (_: Exception) {
                PushAvatarDiagnostics.record(this, PushAvatarOutcome.TERMINAL, PushAvatarReason.ENQUEUE_FAILED, 0)
            }
        } else {
            PushAvatarDiagnostics.record(this, PushAvatarOutcome.SKIPPED, PushAvatarReason.NO_SAFE_URL, 0)
        }
    }
}

internal class DmNotificationRenderer(private val context: Context) {

    fun post(payload: PushNotificationPayload, binding: PushNotificationState.Binding,
                     avatar: Bitmap, update: Boolean, cancelled: () -> Boolean = { false }): Boolean {
        if (!PushFeatureGate.enabled(context) || cancelled()) return false
        val circularAvatar = PushAvatarBitmap.circular(avatar)
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "com.soundconnect.OPEN_PUSH"
            data = Uri.parse("soundconnect-push://notification/${payload.notificationId}")
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            payload.target().forEach { (key, value) -> putExtra("sc.push.$key", value) }
            putExtra(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
        }
        val pending = PendingIntent.getActivity(context, payload.notificationId.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val person = Person.Builder().setName(payload.senderName)
            .setKey(payload.conversationId).setIcon(IconCompat.createWithBitmap(circularAvatar)).build()
        val style = NotificationCompat.MessagingStyle(Person.Builder().setName("Sen").build())
            .setGroupConversation(false)
            .addMessage(PushNotificationPayload.BODY, payload.sentAt, person)
        val publicVersion = NotificationCompat.Builder(context, PushNotificationState.CHANNEL)
            .setSmallIcon(R.drawable.ic_notification).setContentTitle("Soundconnect")
            .setContentText("Yeni bir mesajın var.").build()
        val builder = NotificationCompat.Builder(context, PushNotificationState.CHANNEL)
            .addExtras(Bundle().apply {
                putString(PushDeliveredPolicy.RECIPIENT_EXTRA, binding.recipient)
                putString(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
                putString(PushDeliveredPolicy.ID_EXTRA, payload.notificationId)
                putLong(PushNotificationGroups.EXPIRY_EXTRA, payload.expiresAt)
            })
            .setSmallIcon(R.drawable.ic_notification)
            .setGroup(PushNotificationGroups.groupKey(binding))
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)
            .setDeleteIntent(PushNotificationGroups.deleteIntent(context, binding, setOf(payload.notificationId)))
            // OEMs that tint the small icon need one color; sampled from the original emblem.
            .setColor(ContextCompat.getColor(context, R.color.soundconnect_icon_accent))
            .setContentTitle(payload.senderName).setContentText(PushNotificationPayload.BODY)
            .setLargeIcon(circularAvatar)
            .setStyle(style).setContentIntent(pending).setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE).setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(if (Build.VERSION.SDK_INT < 26) NotificationCompat.DEFAULT_ALL else 0)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setPublicVersion(publicVersion)
            .setOnlyAlertOnce(true).setWhen(payload.sentAt)
            .setTimeoutAfter((payload.expiresAt - System.currentTimeMillis()).coerceAtLeast(1))
        return try {
            val manager = context.getSystemService(NotificationManager::class.java)
            fun deliver(requireActive: Boolean): Boolean {
                // Re-check after image work, including inside the logout lock.
                // Never resurrect a tapped/dismissed/expired notification.
                // State.post/postInitial already holds the current-binding lock.
                // Read cancellation here again after bitmap/builder preparation.
                return if (PushAvatarPolicy.guard(System.currentTimeMillis(), payload.expiresAt,
                    cancelled(), true, foreground(), !requireActive || manager.activeNotifications.any {
                        it.tag == payload.notificationId
                    }) == null) {
                    val notification = builder.build()
                    manager.notify(payload.notificationId, 0, notification)
                    try {
                        PushNotificationGroups.reconcileLocked(context, binding, notification, payload.notificationId)
                    } catch (_: Exception) {
                        // The child was already posted. A summary failure must
                        // not skip its expiry scheduling or avatar work. Later
                        // delivery/read reconciliation can repair the summary.
                    }
                    true
                } else false
            }
            val posted = if (update) PushNotificationState.post(context, binding, payload.notificationId) { deliver(true) }
            else PushNotificationState.postInitial(context, binding, payload.notificationId, payload.expiresAt) { deliver(false) }
            if (posted && !cancelled()) {
                // A slow OEM ShortcutManager cannot delay the first visible alert
                // or hold the binding lock needed by logout on the UI thread.
                PushConversationShortcuts.publish(context, payload, binding, person, circularAvatar, intent)?.let {
                    builder.setShortcutId(it)
                    PushNotificationState.post(context, binding, payload.notificationId) { deliver(true) }
                }
            }
            posted
        } catch (_: Exception) { false }
    }

    fun foreground(): Boolean {
        if (context.getSystemService(KeyguardManager::class.java).isKeyguardLocked) return false
        return context.getSystemService(ActivityManager::class.java).runningAppProcesses.orEmpty().any {
            it.processName == context.packageName && it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        }
    }

    fun fallbackAvatar(name: String): Bitmap {
        val bitmap = Bitmap.createBitmap(128, 128, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(87, 61, 113) }
        canvas.drawCircle(64f, 64f, 64f, paint)
        paint.color = Color.WHITE; paint.textSize = 54f; paint.textAlign = Paint.Align.CENTER
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        val initial = name.codePoints().findFirst().orElse('S'.code)
        canvas.drawText(String(Character.toChars(initial)).uppercase(), 64f, 64f - (paint.ascent() + paint.descent()) / 2, paint)
        return bitmap
    }

}

class PushAvatarWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    private val fetcher = PushAvatarFetch({ isStopped }, { SystemClock.elapsedRealtime() })

    override fun doWork(): Result {
        val context = applicationContext
        @Suppress("DEPRECATION")
        val host = context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
            .metaData?.getString("com.soundconnect.push_avatar_host").orEmpty()
        val data = inputData.keyValueMap.mapNotNull { (key, value) -> (value as? String)?.let { key to it } }.toMap()
        val payload = PushNotificationPayload.parse(data, System.currentTimeMillis(), host)
            ?: return finish(PushAvatarOutcome.SKIPPED, PushAvatarReason.INVALID_PAYLOAD)
        val binding = PushNotificationState.Binding(payload.recipientId, inputData.getString("bindingEpoch").orEmpty())
        val renderer = DmNotificationRenderer(context)
        val manager = context.getSystemService(NotificationManager::class.java)
        fun guard(): PushAvatarReason? = PushAvatarPolicy.guard(System.currentTimeMillis(), payload.expiresAt,
            isStopped, PushNotificationState.current(context, binding), renderer.foreground(),
            manager.activeNotifications.any { it.tag == payload.notificationId })
        guard()?.let { return finish(PushAvatarOutcome.SKIPPED, it) }
        if (runAttemptCount >= PushAvatarPolicy.MAX_ATTEMPTS) {
            return finish(PushAvatarOutcome.ATTEMPT_LIMIT, PushAvatarReason.ATTEMPT_LIMIT)
        }
        val url = payload.avatarUrl ?: return finish(PushAvatarOutcome.SKIPPED, PushAvatarReason.NO_SAFE_URL)
        val fetched = fetcher.fetch(url)
        if (fetched is PushAvatarFetchResult.Failure) {
            // An account switch, tap, dismissal, expiry or foreground resume wins over retry.
            guard()?.let { return finish(PushAvatarOutcome.SKIPPED, it) }
            val decision = PushAvatarPolicy.retry(fetched.reason, runAttemptCount,
                System.currentTimeMillis(), payload.expiresAt)
            if (decision == PushAvatarOutcome.RETRY) {
                PushAvatarDiagnostics.record(context, decision, fetched.reason, runAttemptCount + 1)
                return Result.retry()
            }
            return finish(decision, fetched.reason)
        }
        val avatar = decodeAvatar((fetched as PushAvatarFetchResult.Bytes).value)
            ?: return finish(PushAvatarOutcome.TERMINAL, PushAvatarReason.INVALID_IMAGE)
        guard()?.let { return finish(PushAvatarOutcome.SKIPPED, it) }
        return if (renderer.post(payload, binding, avatar, true, cancelled = { isStopped })) {
            finish(PushAvatarOutcome.POSTED, PushAvatarReason.POSTED)
        } else finish(PushAvatarOutcome.SKIPPED, PushAvatarReason.POST_REJECTED)
    }

    private fun finish(outcome: PushAvatarOutcome, reason: PushAvatarReason): Result = Result.success(
        PushAvatarDiagnostics.record(applicationContext, outcome, reason, runAttemptCount + 1))

    override fun onStopped() { fetcher.cancel() }

    private fun decodeAvatar(raw: ByteArray): Bitmap? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(raw, 0, raw.size, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0
                || bounds.outWidth.toLong() * bounds.outHeight > 16_000_000) return null
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 256) sample *= 2
            BitmapFactory.decodeByteArray(raw, 0, raw.size, BitmapFactory.Options().apply { inSampleSize = sample })
        } catch (_: Exception) { null }
    }
}

class PushExpiryWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val id = PushNotificationPayload.uuid(inputData.getString("notificationId")) ?: return Result.success()
        val expiresAt = inputData.getLong("expiresAt", 0)
        if (expiresAt <= 0) return Result.success()
        if (System.currentTimeMillis() < expiresAt) {
            // A wall-clock rollback must not create an unbounded retry chain.
            return if (runAttemptCount < 3) Result.retry() else Result.success()
        }
        val recipient = PushNotificationPayload.uuid(inputData.getString("recipientId"))
        val epoch = PushNotificationPayload.uuid(inputData.getString("bindingEpoch"))
        val binding = if (recipient != null && epoch != null) PushNotificationState.Binding(recipient, epoch)
            else if (inputData.getString("recipientId") == null && inputData.getString("bindingEpoch") == null)
                PushNotificationState.currentBinding(applicationContext) // pre-grouping queued work
            else null
        if (binding != null) PushNotificationState.expireNotification(applicationContext, binding, id, expiresAt)
        return Result.success()
    }
}
