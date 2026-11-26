package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.app.Service
import android.app.job.JobParameters
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.IBinder
import androidx.core.app.CoreComponentFactory

/** Android may start an upload component while the app process is cold. Keep
 * the required SDK registrations discoverable, but run their implementation
 * only when the current foreground actor has authorized this process. */
class AnalyticsComponentFactory : CoreComponentFactory() {
    override fun instantiateReceiver(cl: ClassLoader, className: String, intent: Intent?): BroadcastReceiver {
        if (!AnalyticsConsentChannel.workersAllowed && className == "com.google.android.gms.measurement.AppMeasurementReceiver") {
            return object : BroadcastReceiver() { override fun onReceive(context: Context, intent: Intent) {} }
        }
        return super.instantiateReceiver(cl, className, intent)
    }

    override fun instantiateService(cl: ClassLoader, className: String, intent: Intent?): Service {
        if (!AnalyticsConsentChannel.workersAllowed) {
            when (className) {
                "com.google.android.gms.measurement.AppMeasurementService" -> return DormantService()
                "com.google.android.gms.measurement.AppMeasurementJobService" -> return DormantJob()
            }
        }
        return super.instantiateService(cl, className, intent)
    }

    private class DormantService : Service() {
        override fun onBind(intent: Intent): IBinder? = null
        override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
            stopSelfResult(startId)
            return START_NOT_STICKY
        }
    }

    private class DormantJob : JobService() {
        override fun onStartJob(params: JobParameters) = false
        override fun onStopJob(params: JobParameters) = false
    }
}
