package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.systemchannels.ProcessTextChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.text.ProcessTextPlugin
import java.io.ByteArrayOutputStream
import java.io.IOException

/** Compiled only into the isolated preview application, without audio or share activity hooks. */
class PreviewActivity : FlutterActivity() {
    private var previewEngine: FlutterEngine? = null
    private var isolationChannel: MethodChannel? = null
    private val registeredPluginNames = mutableListOf<String>()

    // An exported launcher intent must not select a cached engine with other plugins.
    override fun getCachedEngineId(): String? = null

    override fun getCachedEngineGroupId(): String? = null

    override fun shouldDestroyEngineWithHost(): Boolean = true

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        check(previewEngine == null) { "The preview activity already owns an engine." }
        // Constructor registration precedes activity attachment. Disabling it only in
        // configureFlutterEngine would be too late for audio_service's second engine.
        val engine = FlutterEngine(context, flutterShellArgs.toArray(), false, shouldRestoreAndSaveState())
        try {
            // Flutter installs ProcessTextPlugin independently of generated plugins.
            // Preserve normal copy/paste while disabling external text-processing apps.
            (engine.plugins.get(ProcessTextPlugin::class.java) as? ProcessTextPlugin)?.destroy()
            engine.plugins.remove(ProcessTextPlugin::class.java)
            engine.processTextChannel.setMethodHandler(object : ProcessTextChannel.ProcessTextMethodHandler {
                override fun queryTextActions(): Map<String, String> = emptyMap()

                override fun processTextAction(
                    id: String,
                    text: String,
                    readOnly: Boolean,
                    result: MethodChannel.Result
                ) {
                    result.error("preview_isolated", "External text actions are unavailable in preview.", null)
                }
            })

            // path_provider_android uses these JNI plugins for this package version.
            register(engine, "jni", com.github.dart_lang.jni.JniPlugin())
            register(engine, "jni_flutter", com.github.dart_lang.jni_flutter.JniFlutterPlugin())
            register(engine, "audio_session", com.ryanheise.audio_session.AudioSessionPlugin())
            register(engine, "just_audio", com.ryanheise.just_audio.JustAudioPlugin())
            register(engine, "better_player_plus", uz.shs.better_player_plus.BetterPlayerPlugin())
            register(engine, "sqflite_android", com.tekartik.sqflite.SqflitePlugin())
            register(engine, "wakelock_plus", dev.fluttercommunity.plus.wakelock.WakelockPlusPlugin())
            register(engine, "video_player_android", io.flutter.plugins.videoplayer.VideoPlayerPlugin())
            if (isPreviewQa()) {
                register(engine, "integration_test", dev.flutter.plugins.integration_test.IntegrationTestPlugin())
            }
            previewEngine = engine
            // The activity delegate starts the selected preview Dart entrypoint in onStart.
            return engine
        } catch (failure: Throwable) {
            engine.destroy()
            registeredPluginNames.clear()
            throw failure
        }
    }

    private fun register(engine: FlutterEngine, name: String, plugin: FlutterPlugin) {
        engine.plugins.add(plugin)
        registeredPluginNames.add(name)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        check(flutterEngine === previewEngine) { "Only the owned preview engine may be configured." }
        // Deliberately bypass the superclass's generated plugin registrant.
        isolationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "soundconnect/preview/isolation"
        )
        isolationChannel?.setMethodCallHandler { call, result ->
            if (call.method == "readFixture") {
                readFixture(call.argument<String>("name"), result)
                return@setMethodCallHandler
            }
            if (call.method != "status") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            result.success(
                mapOf(
                    "packageName" to packageName,
                    "internetPermissionGranted" to
                        (checkSelfPermission(Manifest.permission.INTERNET) == PackageManager.PERMISSION_GRANTED),
                    "previewQa" to isPreviewQa(),
                    "registeredPluginNames" to registeredPluginNames.toList()
                )
            )
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        isolationChannel?.setMethodCallHandler(null)
        isolationChannel = null
        flutterEngine.processTextChannel.setMethodHandler(null)
        registeredPluginNames.clear()
        previewEngine = null
        // FlutterActivity's delegate destroys this engine after plugin activity detachment.
    }

    @Suppress("DEPRECATION")
    private fun isPreviewQa(): Boolean {
        val metadata = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA).metaData
        return metadata?.getBoolean("com.soundconnect.preview.QA", false) ?: false
    }

    private fun readFixture(name: String?, result: MethodChannel.Result) {
        if (name == null || !name.matches(Regex("[A-Za-z0-9][A-Za-z0-9_.-]{0,100}")) || name.contains("..")) {
            result.error("invalid_fixture", "A bare preview fixture filename is required.", null)
            return
        }
        try {
            assets.open("preview/$name").use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (output.size() + count > 16 * 1024 * 1024) {
                        result.error("fixture_too_large", "Preview fixture exceeds its 16 MiB bound.", null)
                        return
                    }
                    output.write(buffer, 0, count)
                }
                result.success(output.toByteArray())
            }
        } catch (missing: IOException) {
            result.error("fixture_missing", "Preview fixture is unavailable.", null)
        }
    }
}
