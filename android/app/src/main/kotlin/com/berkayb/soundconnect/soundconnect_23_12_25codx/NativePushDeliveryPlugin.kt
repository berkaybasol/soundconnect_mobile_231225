package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** The Dart listener/initial handshake lives with the engine, not its Activity. */
internal class NativePushDeliveryPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null
    private var owner: Any? = null
    private var ready = false
    private data class Pending(val intent: Intent, val binding: PushNotificationState.Binding)
    private var pending: Pending? = null
    private var engineIdentity = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        engineIdentity = System.identityHashCode(binding.binaryMessenger)
        channel = MethodChannel(binding.binaryMessenger, "com.soundconnect/push_delivery").also {
            it.setMethodCallHandler(this)
        }
    }

    fun attach(activity: Any) {
        owner = activity
        trace("attach")
        // onCreate supplies the current launch intent before draining a pending tap.
    }

    fun detach(activity: Any) {
        if (owner !== activity) return
        trace("detach")
        owner = null
        // A configuration change can retain both the engine and its pending tap.
    }

    fun accept(activity: Any, intent: Intent?) {
        if (owner !== activity) return // A retired Activity cannot feed the new binding.
        val ctx = context ?: return
        val target = NativePushOpen.target(ctx, intent)
        if (target != null) {
            val binding = PushNotificationState.capture(ctx, target.getValue("recipientId"))
            if (binding != null) {
                pending = Pending(Intent(intent), binding)
                trace("queued", target["notificationId"])
            }
        }
        clearIntent(intent)
        if (ready) takePending()?.let { channel?.invokeMethod("opened", it) }
    }

    private fun takePending(): Map<String, String>? {
        if (owner == null) return null
        val value = pending ?: return null
        pending = null
        val ctx = context ?: return null
        // Recheck the exact captured native owner/epoch/reset gate after a delayed
        // handshake or reattach. Dismissal is never a server read acknowledgment.
        if (!PushNotificationState.current(ctx, value.binding)) {
            trace("stale-pending")
            return null
        }
        val target = NativePushOpen.target(ctx, value.intent)
        if (target != null) trace("handoff", target["notificationId"])
        return target
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null || channel == null) { result.notImplemented(); return }
        when (call.method) {
            "initialMessage" -> {
                // Dart calls this only after restoring the session and subscribing.
                ready = true
                trace("ready")
                result.success(takePending())
            }
            "bindRecipient" -> try {
                val recipient = call.argument<String>("recipientId")
                PushNotificationState.bind(ctx, recipient)
                if (pending?.binding?.let { !PushNotificationState.current(ctx, it) } == true) pending = null
                result.success(null)
            } catch (_: Exception) { result.error("push_binding", "Notification binding unavailable.", null) }
            "deliveredSnapshot" -> {
                val recipient = PushDeliveredPolicy.snapshotRecipient(call.arguments)
                if (recipient == null) result.error("invalid_arguments", "A canonical recipient ID is required.", null)
                else try { result.success(PushNotificationState.deliveredSnapshot(ctx, recipient)) }
                catch (_: Exception) { result.error("push_delivery", "Notification snapshot unavailable.", null) }
            }
            "dismissDelivered" -> {
                val request = PushDeliveredPolicy.dismissRequest(call.arguments)
                if (request == null) result.error("invalid_arguments", "Canonical binding and up to 100 notification IDs are required.", null)
                else try {
                    PushNotificationState.dismissDelivered(ctx, request)
                    result.success(null)
                } catch (_: Exception) { result.error("push_delivery", "Notification dismissal unavailable.", null) }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        trace("engine-detach")
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        owner = null
        pending = null
        ready = false
    }

    private fun trace(event: String, notification: String? = null) {
        val ctx = context ?: return
        if ((ctx.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) == 0) return
        Log.d("SCNativeOpen", "$event engine=$engineIdentity activity=${owner?.let { System.identityHashCode(it) }} ready=$ready notification=${notification.orEmpty()}")
    }

    private fun clearIntent(intent: Intent?) {
        if (intent == null || !PushOpenTarget.supports(intent.action)) return
        PushOpenTarget.fields.forEach { intent.removeExtra("sc.push.$it") }
        intent.removeExtra(PushDeliveredPolicy.EPOCH_EXTRA)
        intent.action = Intent.ACTION_MAIN
        intent.data = null
    }
}
