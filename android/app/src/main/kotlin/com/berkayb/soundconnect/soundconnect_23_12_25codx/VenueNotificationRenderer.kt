package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/** Validated display copy, no cached navigation target and no conversation shortcut. */
internal class VenueNotificationRenderer(
    private val context: Context,
    private val foreground: () -> Boolean = { DmNotificationRenderer(context).foreground() }
) {
    fun receive(data: Map<String, String>): Boolean {
        val payload = VenuePushPayload.parse(data, System.currentTimeMillis()) ?: return false
        val binding = PushNotificationState.capture(context, payload.recipientId) ?: return false
        if (PushNotificationState.seen(context, binding, payload.notificationId)) return false
        return post(payload, binding)
    }

    // The test-only false value keeps real NotificationManager fixtures from
    // scheduling workers against their isolated storage after the fixture ends.
    internal fun post(payload: VenuePushPayload, binding: PushNotificationState.Binding,
                      scheduleWork: Boolean = true): Boolean {
        if (!PushFeatureGate.enabled(context) || foreground()
            || payload.recipientId != binding.recipient || payload.expiresAt <= System.currentTimeMillis()
            || !payload.hasValidDisplay()
            || !NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context,
                Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(
            PushNotificationState.CHANNEL, "Soundconnect bildirimleri", NotificationManager.IMPORTANCE_HIGH
        ).apply { description = "Mesajlar ve uygulama güncellemeleri" })
        val intent = Intent(context, MainActivity::class.java).apply {
            action = PushOpenTarget.NOTIFICATION_ACTION
            data = Uri.parse("soundconnect-push://notification/${payload.notificationId}")
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            payload.target().forEach { (key, value) -> putExtra("sc.push.$key", value) }
            putExtra(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
        }
        val pending = PendingIntent.getActivity(context, payload.notificationId.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val publicVersion = NotificationCompat.Builder(context, PushNotificationState.CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Soundconnect").setContentText("Yeni bir bildirimin var.").build()
        val notification = NotificationCompat.Builder(context, PushNotificationState.CHANNEL)
            .addExtras(Bundle().apply {
                putString(PushDeliveredPolicy.RECIPIENT_EXTRA, binding.recipient)
                putString(PushDeliveredPolicy.EPOCH_EXTRA, binding.epoch)
                putString(PushDeliveredPolicy.ID_EXTRA, payload.notificationId)
                putLong(PushNotificationGroups.EXPIRY_EXTRA, payload.expiresAt)
            })
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(ContextCompat.getColor(context, R.color.soundconnect_icon_accent))
            .setContentTitle(payload.title).setContentText(payload.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(payload.body))
            .setGroup(VenueNotificationGroups.groupKey(binding))
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)
            .setDeleteIntent(PushNotificationGroups.deleteIntent(context, binding, setOf(payload.notificationId)))
            .setContentIntent(pending).setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_EVENT).setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(if (Build.VERSION.SDK_INT < 26) NotificationCompat.DEFAULT_ALL else 0)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setPublicVersion(publicVersion)
            .setOnlyAlertOnce(true).setWhen(payload.sentAt)
            .setTimeoutAfter((payload.expiresAt - System.currentTimeMillis()).coerceAtLeast(1)).build()
        val posted = try {
            PushNotificationState.postInitial(context, binding, payload.notificationId, payload.expiresAt) {
                if (foreground() || payload.expiresAt <= System.currentTimeMillis()) false
                else {
                    manager.notify(payload.notificationId, 0, notification)
                    try {
                        VenueNotificationGroups.reconcileLocked(context, binding, notification,
                            payload.notificationId, scheduleRepair = scheduleWork)
                    } catch (_: Exception) { /* Expiry/read reconciliation still owns the accepted child. */ }
                    true
                }
            }
        } catch (_: Exception) { false }
        if (posted && scheduleWork) try {
            val expiry = OneTimeWorkRequest.Builder(PushExpiryWorker::class.java)
                .setInputData(Data.Builder().putString("notificationId", payload.notificationId)
                    .putString("recipientId", binding.recipient).putString("bindingEpoch", binding.epoch)
                    .putLong("expiresAt", payload.expiresAt).build())
                .setInitialDelay((payload.expiresAt - System.currentTimeMillis()).coerceAtLeast(0), TimeUnit.MILLISECONDS)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork("push-expiry-${payload.notificationId}",
                ExistingWorkPolicy.KEEP, expiry)
        } catch (_: Exception) { /* Inbox is authoritative; API24 expiry work remains best effort. */ }
        return posted
    }
}
