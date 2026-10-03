package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log
import androidx.work.Data

/** Local WorkManager output/debug aid, not production telemetry. No free-form values accepted. */
internal object PushAvatarDiagnostics {
    fun record(context: Context, outcome: PushAvatarOutcome, reason: PushAvatarReason, attempt: Int): Data {
        val boundedAttempt = attempt.coerceIn(0, PushAvatarPolicy.MAX_ATTEMPTS)
        if (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            Log.d("SCAvatar", "outcome=${outcome.name} reason=${reason.name} attempt=$boundedAttempt")
        }
        return Data.Builder().putString("avatarOutcome", outcome.name)
            .putString("avatarReason", reason.name).putInt("avatarAttempt", boundedAttempt).build()
    }
}
