package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.Context

/** The build opt-in also fences native callbacks and work persisted by an older APK. */
internal object PushFeatureGate {
    fun enabled(context: Context): Boolean = try {
        context.resources.getBoolean(R.bool.soundconnect_push_enabled)
    } catch (_: Exception) { false }

    fun onAppLaunch(context: Context) {
        if (enabled(context)) return
        try {
            // Rotate the epoch before logout/login can run without the disabled
            // Dart coordinator. Re-enabling later must not revive an old owner.
            PushNotificationState.bind(context, null)
        } catch (_: Exception) {
            // Even a storage failure cannot bypass enabled()/capture(). Still
            // make a best-effort attempt to remove previously visible cards.
            try { PushNotificationState.clearDelivered(context) } catch (_: Exception) { }
        }
    }
}
