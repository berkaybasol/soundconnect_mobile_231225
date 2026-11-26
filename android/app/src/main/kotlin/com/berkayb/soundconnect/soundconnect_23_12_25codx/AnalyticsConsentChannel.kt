package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.Context
import android.content.ComponentName
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.analytics.FirebaseAnalytics.ConsentStatus
import com.google.firebase.analytics.FirebaseAnalytics.ConsentType
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.TimeUnit

/** No Firebase call or SDK registration occurs when a Flutter engine starts. */
internal object AnalyticsConsentChannel {
    private const val OWNER = "analyticsOwner"
    private const val RECOVERY = "resetBeforeNewAudience"
    private const val TAG = "SC-GA4"
    private var sdk: FirebaseAnalytics? = null
    private var clearing = false
    private var activeProfile: String? = null
    @Volatile var workersAllowed = false
        private set

    fun attach(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "com.soundconnect/analytics_consent").setMethodCallHandler { call, result ->
            if (!context.resources.getBoolean(R.bool.soundconnect_ga4_staging_enabled) ||
                !context.resources.getBoolean(R.bool.analytics_workers_supported)) {
                result.success(false)
                return@setMethodCallHandler
            }
            // A durable marker is installed before SDK initialization, so a process
            // death cannot make a different actor adopt potentially queued events.
            val state = context.getSharedPreferences("sc_analytics_runtime", Context.MODE_PRIVATE)
            try {
                when (call.method) {
                    "prepare" -> {
                        val identity = requireNotNull(call.argument<String>("identity"))
                        check(UUID.fromString(identity).toString() == identity)
                        val owner = state.getString(OWNER, null)
                        if (!clearing && (owner == null || owner == identity) && !state.getBoolean(RECOVERY, false)) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        // An old SDK queue survived a process death. Its code may
                        // start only after this new actor's actual consent. Make
                        // the SDK upload components unavailable throughout reset.
                        // The durable flag makes interruptions retry the reset.
                        workersAllowed = false
                        check(state.edit().putBoolean(RECOVERY, true).commit())
                        setUploadComponents(context, PackageManager.COMPONENT_ENABLED_STATE_DISABLED)
                        val analytics = sdk ?: FirebaseAnalytics.getInstance(context).also { sdk = it }
                        reset(context, analytics, state, result)
                    }
                    "start" -> {
                        val identity = call.argument<String>("identity")
                        val profile = call.argument<String>("profile")
                        if (identity == null || UUID.fromString(identity).toString() != identity ||
                            profile !in setOf("guest", "listener", "musician", "studio", "venue")) {
                            result.error("invalid", "Invalid analytics audience", null)
                            return@setMethodCallHandler
                        }
                        val owner = state.getString(OWNER, null)
                        if (clearing || state.getBoolean(RECOVERY, false) || (owner != null && owner != identity)) {
                            Log.i(TAG, "Different unclosed audience; collection held")
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        check(owner != null || state.edit().putString(OWNER, identity).commit())
                        workersAllowed = true
                        val analytics = sdk ?: FirebaseAnalytics.getInstance(context).also { sdk = it }
                        analytics.setConsent(consent(true))
                        analytics.setAnalyticsCollectionEnabled(true)
                        analytics.setUserId(identity)
                        analytics.setUserProperty("profile_type", profile)
                        activeProfile = profile
                        analytics.logEvent("foreground_visit", Bundle().apply { putString("profile_type", profile) })
                        Log.i(TAG, "Consented foreground visit submitted")
                        result.success(true)
                    }
                    "event" -> {
                        val identity = call.argument<String>("identity")
                        val name = call.argument<String>("name")
                        val fields = call.argument<Map<String, Any>>("parameters")
                        if (workersAllowed && !clearing && sdk != null && identity != null &&
                            state.getString(OWNER, null) == identity && activeProfile != null &&
                            fields != null && fields["profile_type"] == activeProfile && name != null) {
                            val bundle = parameters(name, fields)
                            if (bundle != null) sdk?.logEvent(name, bundle)
                        }
                        result.success(null)
                    }
                    "suspend" -> {
                        workersAllowed = false
                        sdk?.setAnalyticsCollectionEnabled(false)
                        result.success(null)
                    }
                    "stop" -> {
                        workersAllowed = false
                        val analytics = sdk
                        if (analytics == null) {
                            // Do not instantiate the SDK to clear a previous process.
                            Log.i(TAG, "Collection off; SDK uninitialized")
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        // Persist the reset requirement before touching SDK storage. A timeout
                        // or process death must retry cleanup even for the same audience.
                        check(state.edit().putBoolean(RECOVERY, true).commit())
                        reset(context, analytics, state, result)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                workersAllowed = false
                sdk?.setAnalyticsCollectionEnabled(false)
                result.error("unavailable", "Analytics unavailable", null)
            }
        }
    }

    private fun reset(
        context: Context, analytics: FirebaseAnalytics, state: SharedPreferences, result: MethodChannel.Result
    ) {
        clearing = true
        analytics.setAnalyticsCollectionEnabled(false)
        analytics.setConsent(consent(false))
        analytics.resetAnalyticsData()
        Tasks.withTimeout(analytics.appInstanceId, 15, TimeUnit.SECONDS).addOnCompleteListener { task ->
            try {
                check(task.isSuccessful && task.result == null)
                setUploadComponents(context, PackageManager.COMPONENT_ENABLED_STATE_DEFAULT)
                check(state.edit().remove(OWNER).remove(RECOVERY).commit())
                clearing = false
                result.success(null)
            } catch (_: Exception) {
                result.error("clear", "Analytics reset not confirmed", null)
            }
        }
    }

    private fun setUploadComponents(context: Context, setting: Int) {
        val manager = context.packageManager
        for (name in listOf("AppMeasurementReceiver", "AppMeasurementService", "AppMeasurementJobService")) {
            val component = ComponentName(context, "com.google.android.gms.measurement.$name")
            manager.setComponentEnabledSetting(component, setting, PackageManager.DONT_KILL_APP)
            check(manager.getComponentEnabledSetting(component) == setting)
        }
    }

    private val actions = setOf(
        "table_join_requested", "table_created", "overthinking_published", "profile_share_published",
        "comment_published", "profile_media_uploaded", "spotify_track_added", "band_created",
        "band_joined", "venue_musician_connected", "venue_band_connected", "collab_published",
        "market_listing_published", "collab_applied", "venue_event_published", "studio_room_created",
        "backline_equipment_added"
    )

    private fun parameters(name: String, fields: Map<String, Any>): Bundle? {
        val bundle = Bundle().apply { putString("profile_type", activeProfile) }
        if (name == "meaningful_action") {
            val action = fields["action_type"] as? String ?: return null
            val occurred = (fields["occurred_at_ms"] as? Number)?.toLong() ?: return null
            if (activeProfile == "guest" || action !in actions || occurred <= 0) return null
            bundle.putString("action_type", action)
            bundle.putLong("occurred_at_ms", occurred)
            return bundle
        }
        if (name != "section_time") return null
        val section = fields["section"] as? String ?: return null
        val duration = (fields["duration_ms"] as? Number)?.toLong() ?: return null
        if (duration !in 1L..120000L || section !in setOf(
            "tables","overthinking","marketplace","collab","discover","profiles","other")) return null
        bundle.putString("section", section)
        bundle.putLong("duration_ms", duration)
        if (section == "profiles") {
            val viewed = fields["viewed_profile_type"] as? String ?: return null
            val own = (fields["is_own_profile"] as? Number)?.toLong() ?: return null
            if (viewed !in setOf("listener","musician","band","venue","studio") || own !in 0L..1L) return null
            bundle.putString("viewed_profile_type", viewed)
            bundle.putLong("is_own_profile", own)
        } else if (section == "tables") {
            val table = fields["table_view"] as? String ?: return null
            if (table !in setOf("list","preview","chat","create")) return null
            bundle.putString("table_view", table)
        } else if (section == "discover" && fields["navigation_source"] == "discover") {
            bundle.putString("navigation_source", "discover")
        }
        return bundle
    }

    private fun consent(allowed: Boolean) = mapOf(
        ConsentType.ANALYTICS_STORAGE to if (allowed) ConsentStatus.GRANTED else ConsentStatus.DENIED,
        ConsentType.AD_STORAGE to ConsentStatus.DENIED,
        ConsentType.AD_USER_DATA to ConsentStatus.DENIED,
        ConsentType.AD_PERSONALIZATION to ConsentStatus.DENIED,
    )
}
