package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.ClipData
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
  companion object {
    private const val COLLAB_SHARE_CHANNEL = "com.soundconnect/collab_share"
    private const val INSTAGRAM_PACKAGE = "com.instagram.android"
    private const val WHATSAPP_PACKAGE = "com.whatsapp"
    private const val WHATSAPP_BUSINESS_PACKAGE = "com.whatsapp.w4b"
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
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
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
