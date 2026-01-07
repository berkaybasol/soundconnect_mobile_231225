package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.os.Bundle
import android.content.pm.ApplicationInfo
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
}
