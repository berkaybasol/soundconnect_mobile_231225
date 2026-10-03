import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// An opt-in package boundary, without adding flavors or changing ordinary builds.
val decodedDartDefines = providers.gradleProperty("dart-defines").orNull.orEmpty()
    .split(',').filter { it.isNotBlank() }.map { encoded ->
        try {
            String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
        } catch (invalid: IllegalArgumentException) {
            throw GradleException("Invalid encoded Dart define.", invalid)
        }
    }
val previewDefines = decodedDartDefines.filter { it.substringBefore('=') == "SOUNDCONNECT_PREVIEW" }
if (previewDefines.size > 1) {
    throw GradleException("SOUNDCONNECT_PREVIEW must be specified exactly once for preview builds.")
}
val previewValue = previewDefines.singleOrNull()?.substringAfter('=', "")
if (previewValue != null && previewValue !in setOf("true", "false")) {
    throw GradleException("SOUNDCONNECT_PREVIEW accepts only true or false.")
}
val isPreview = previewValue == "true"
val pushDefines = decodedDartDefines.filter { it.substringBefore('=') == "SOUNDCONNECT_PUSH_ENABLED" }
if (pushDefines.size > 1) {
    throw GradleException("SOUNDCONNECT_PUSH_ENABLED must be specified at most once.")
}
val pushValue = pushDefines.singleOrNull()?.substringAfter('=', "")
if (pushValue != null && pushValue !in setOf("true", "false")) {
    throw GradleException("SOUNDCONNECT_PUSH_ENABLED accepts only true or false.")
}
val pushEnabled = pushValue == "true"
if (pushEnabled && isPreview) {
    throw GradleException("Push is unavailable in offline preview builds.")
}
if (pushEnabled) {
    if (!file("google-services.json").isFile) {
        throw GradleException("Push requires android/app/google-services.json for this Firebase environment.")
    }
    apply(plugin = "com.google.gms.google-services")
}
val flutterProject = rootProject.projectDir.parentFile.canonicalFile
val requestedTarget = providers.gradleProperty("target").orElse("lib/main.dart").get()
val targetFile = flutterProject.resolve(requestedTarget).canonicalFile
val previewMainTarget = flutterProject.resolve("lib/main_preview.dart").canonicalFile
val previewQaTarget = flutterProject.resolve("integration_test/feed_preview_device_test.dart").canonicalFile
val isPreviewTarget = targetFile == previewMainTarget || targetFile == previewQaTarget
val isPreviewQa = targetFile == previewQaTarget
if (isPreview != isPreviewTarget) {
    throw GradleException(
        "Preview requires both --dart-define=SOUNDCONNECT_PREVIEW=true and " +
            "--target=lib/main_preview.dart (or the explicitly allowed feed_preview_device_test.dart QA target)."
    )
}
val requestedReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (isPreview && requestedReleaseBuild) {
    throw GradleException("SoundConnect preview release builds are forbidden; use profile or debug.")
}
if (isPreviewQa && gradle.startParameter.taskNames.any { it.contains("profile", ignoreCase = true) }) {
    throw GradleException("The preview device QA target is debug-only; user preview uses lib/main_preview.dart.")
}
if (isPreview) {
    // Also reject lifecycle tasks (for example assemble/build) that indirectly select release.
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.project == project && it.name.contains("release", ignoreCase = true) }) {
            throw GradleException("SoundConnect preview release builds are forbidden; use profile or debug.")
        }
        if (isPreviewQa && allTasks.any { it.project == project && it.name.contains("profile", ignoreCase = true) }) {
            throw GradleException("The preview device QA target is debug-only.")
        }
    }
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}
val hasReleaseSigning = keystorePropertiesFile.exists() &&
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
        !keystoreProperties.getProperty(it).isNullOrBlank()
    }
if (requestedReleaseBuild && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is not configured. Add android/key.properties with " +
            "storeFile, storePassword, keyAlias and keyPassword."
    )
}

android {
    namespace = "com.berkayb.soundconnect.soundconnect_23_12_25codx"
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // Dart, native receivers and persisted notification work share one opt-in.
        manifestPlaceholders["soundconnectPushEnabled"] = pushEnabled.toString()
        resValue("bool", "soundconnect_push_enabled", pushEnabled.toString())
        // Match the backend's public CDN. No arbitrary avatar URL is fetched by native push.
        manifestPlaceholders["pushAvatarHost"] = providers.gradleProperty("dart-defines").orNull.orEmpty()
            .split(',').filter { it.isNotBlank() }.map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
            .firstOrNull { it.startsWith("SOUNDCONNECT_PUSH_AVATAR_HOST=") }
            ?.substringAfter('=') ?: "du3pguch18ell.cloudfront.net"
        // Permanent Android distribution identity approved on 2026-09-23.
        applicationId = "tr.com.soundconnect.app"
        if (isPreview) {
            applicationId = "tr.com.soundconnect.app.preview"
            manifestPlaceholders["previewQa"] = isPreviewQa.toString()
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    if (isPreview) {
        sourceSets.getByName("main") {
            manifest.srcFile("src/preview/AndroidManifest.xml")
            java.srcDir("src/preview/kotlin")
            res.srcDir("src/preview/res")
            assets.srcDir("src/preview/assets")
        }
        // Higher-priority overlays also remove permissions contributed by plugin manifests.
        sourceSets.getByName("debug").manifest.srcFile(
            if (isPreviewQa) "src/preview/AndroidManifest-qa.xml"
            else "src/preview/AndroidManifest-offline.xml"
        )
        sourceSets.getByName("profile").manifest.srcFile("src/preview/AndroidManifest-offline.xml")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}

// I452fc fixes cancellation of an already-rescheduled network-constrained worker.
// Stable 2.12.0 includes the previously validated release-candidate fix;
// see docs/dm-notification-readiness-20260923.md for acceptance and remaining limits.
val workManagerVersion = "2.12.0"
if (providers.gradleProperty("soundconnectWorkManagerCandidate").isPresent) {
    throw GradleException(
        "The WorkManager comparison flag is retired. Omit soundconnectWorkManagerCandidate; " +
            "all variants now use the pinned $workManagerVersion."
    )
}

dependencies {
    // Native DM renderer uses the same Firebase BOM as the locked FlutterFire SDK.
    implementation(platform("com.google.firebase:firebase-bom:${rootProject.project(":firebase_core").property("FirebaseSDKVersion")}"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("androidx.core:core:1.17.0")
    implementation("androidx.work:work-runtime:$workManagerVersion") {
        version { strictly(workManagerVersion) }
    }
    testImplementation("junit:junit:4.13.2")
    // Align Flutter integration_test's debug runtime with the device test runner.
    debugImplementation("androidx.test:runner:1.7.0")
    debugImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}
