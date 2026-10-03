package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.ClipData
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.app.NotificationChannel
import android.app.NotificationManager
import android.view.WindowManager
import android.util.AtomicFile
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import org.json.JSONObject

class MainActivity : AudioServiceActivity() {
  private var pushDelivery: NativePushDeliveryPlugin? = null
  companion object {
    private const val COLLAB_SHARE_CHANNEL = "com.soundconnect/collab_share"
    private const val INSTAGRAM_PACKAGE = "com.instagram.android"
    private const val WHATSAPP_PACKAGE = "com.whatsapp"
    private const val WHATSAPP_BUSINESS_PACKAGE = "com.whatsapp.w4b"
    private val PUSH_IDENTITY_LOCK = Any()
    private const val MAX_PUSH_REVISION = 9007199254740991L
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    val isDebuggable =
      (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    if (isDebuggable) {
      window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    } else {
      window.setFlags(
        WindowManager.LayoutParams.FLAG_SECURE,
        WindowManager.LayoutParams.FLAG_SECURE
      )
    }
    super.onCreate(savedInstanceState)
    PushFeatureGate.onAppLaunch(this)
    pushDelivery?.accept(this, intent)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val notifications = getSystemService(NotificationManager::class.java)
      notifications.createNotificationChannel(NotificationChannel(
        "soundconnect_notifications", "Soundconnect bildirimleri", NotificationManager.IMPORTANCE_HIGH
      ).apply { description = "Mesajlar ve uygulama güncellemeleri" })
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    if (!flutterEngine.plugins.has(NativePushDeliveryPlugin::class.java)) {
      flutterEngine.plugins.add(NativePushDeliveryPlugin())
    }
    pushDelivery = flutterEngine.plugins.get(NativePushDeliveryPlugin::class.java) as NativePushDeliveryPlugin
    pushDelivery!!.attach(this)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.soundconnect/push")
      .setMethodCallHandler { call, result ->
        if (call.method == "installationId" || call.method == "nextMutation") {
          try {
            val identity = pushInstallation(call.method == "nextMutation")
            result.success(if (call.method == "installationId") identity["installationId"] else identity)
          } catch (_: Exception) { result.error("installation_storage", "Installation identity unavailable.", null) }
        } else if (call.method == "pushResetRequired") {
          try { result.success(PushResetState.required(this)) }
          catch (_: Exception) { result.error("push_reset_storage", "Notification reset state unavailable.", null) }
        } else if (call.method == "setPushResetRequired") {
          val required = (call.arguments as? Map<*, *>)?.get("required")
          if (required !is Boolean) {
            result.error("invalid_arguments", "A Boolean reset state is required.", null)
          } else try {
            PushNotificationState.setResetRequired(this, required)
            result.success(null)
          } catch (_: Exception) { result.error("push_reset_storage", "Notification reset state unavailable.", null) }
        } else if (call.method == "clearDelivered") {
          try {
            // bind clears both children and summaries under the same epoch lock.
            PushNotificationState.bind(this, null)
            result.success(null)
          } catch (_: Exception) { result.error("push_binding", "Notification cleanup unavailable.", null) }
        } else { result.notImplemented() }
      }
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      COLLAB_SHARE_CHANNEL
    ).setMethodCallHandler { call, result ->
      if (call.method != "share") {
        result.notImplemented()
        return@setMethodCallHandler
      }
      val target = call.argument<String>("target")
      val path = call.argument<String>("path")
      val caption = call.argument<String>("caption").orEmpty()
      if (target == null || path.isNullOrBlank()) {
        result.error("invalid_arguments", "Share target and image path are required.", null)
        return@setMethodCallHandler
      }
      try {
        shareCollabCard(target, File(path), caption)
        result.success(null)
      } catch (error: AppNotInstalledException) {
        result.error("app_not_installed", error.message, null)
      } catch (error: Exception) {
        result.error("share_failed", error.message ?: "Share failed.", null)
      }
    }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    pushDelivery?.accept(this, intent)
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    pushDelivery?.detach(this)
    pushDelivery = null
    super.cleanUpFlutterEngine(flutterEngine)
  }

  private fun pushInstallation(advance: Boolean): Map<String, Any> = synchronized(PUSH_IDENTITY_LOCK) {
    val storage = AtomicFile(File(noBackupFilesDir, "soundconnect-push-installation"))
    val saved = try { JSONObject(String(storage.readFully(), Charsets.UTF_8)) } catch (_: Exception) { null }
    var id = try { UUID.fromString(saved!!.getString("installationId")).toString() } catch (_: Exception) { null }
    var revision = try { saved!!.getLong("clientRevision") } catch (_: Exception) { -1L }
    // A lost/reset counter may never reuse an existing server identity.
    if (id == null || revision < 0 || revision >= MAX_PUSH_REVISION) {
      id = UUID.randomUUID().toString()
      revision = 0L
    }
    if (advance) revision++
    val json = JSONObject().put("installationId", id).put("clientRevision", revision)
    val output = storage.startWrite()
    try {
      output.write(json.toString().toByteArray(Charsets.UTF_8))
      storage.finishWrite(output)
    } catch (error: Exception) {
      storage.failWrite(output)
      throw error
    }
    mapOf("installationId" to id, "clientRevision" to revision)
  }

  private fun shareCollabCard(target: String, image: File, caption: String) {
    require(image.isFile) { "Share image does not exist." }
    val uri = FileProvider.getUriForFile(
      this,
      "$packageName.collab_share_files",
      image
    )
    when (target) {
      "instagramStory" -> shareInstagramStory(uri)
      "whatsapp" -> shareWhatsApp(uri, caption)
      else -> throw IllegalArgumentException("Unsupported share target.")
    }
  }

  private fun shareInstagramStory(uri: Uri) {
    ensureInstalled(INSTAGRAM_PACKAGE, "Instagram")
    grantUriPermission(INSTAGRAM_PACKAGE, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
    val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
      setDataAndType(uri, "image/png")
      putExtra("background_asset_uri", uri)
      putExtra("top_background_color", "#030713")
      putExtra("bottom_background_color", "#51205C")
      clipData = ClipData.newRawUri("SoundConnect Collab", uri)
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      setPackage(INSTAGRAM_PACKAGE)
    }
    if (intent.resolveActivity(packageManager) == null) {
      throw AppNotInstalledException("Instagram Hikâyeleri bu cihazda kullanılamıyor.")
    }
    startActivity(intent)
  }

  private fun shareWhatsApp(uri: Uri, caption: String) {
    val targetPackage = when {
      isInstalled(WHATSAPP_PACKAGE) -> WHATSAPP_PACKAGE
      isInstalled(WHATSAPP_BUSINESS_PACKAGE) -> WHATSAPP_BUSINESS_PACKAGE
      else -> throw AppNotInstalledException("WhatsApp bu cihazda yüklü değil.")
    }
    grantUriPermission(targetPackage, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
    val intent = Intent(Intent.ACTION_SEND).apply {
      type = "image/png"
      putExtra(Intent.EXTRA_STREAM, uri)
      putExtra(Intent.EXTRA_TEXT, caption)
      clipData = ClipData.newRawUri("SoundConnect Collab", uri)
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      setPackage(targetPackage)
    }
    if (intent.resolveActivity(packageManager) == null) {
      throw AppNotInstalledException("WhatsApp paylaşımı bu cihazda kullanılamıyor.")
    }
    startActivity(intent)
  }

  private fun ensureInstalled(packageName: String, label: String) {
    if (!isInstalled(packageName)) {
      throw AppNotInstalledException("$label bu cihazda yüklü değil.")
    }
  }

  @Suppress("DEPRECATION")
  private fun isInstalled(targetPackage: String): Boolean = try {
    packageManager.getPackageInfo(targetPackage, 0)
    true
  } catch (_: Exception) {
    false
  }

  private class AppNotInstalledException(message: String) : Exception(message)
}
