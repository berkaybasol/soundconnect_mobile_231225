import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// An opt-in package boundary, without adding flavors or changing ordinary builds.
val previewDefines = providers.gradleProperty("dart-defines").orNull.orEmpty()
    .split(',').filter { it.isNotBlank() }.map { encoded ->
        try {
            String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
        } catch (invalid: IllegalArgumentException) {
            throw GradleException("Invalid encoded Dart define.", invalid)
        }
    }.filter { it.substringBefore('=') == "SOUNDCONNECT_PREVIEW" }
if (previewDefines.size > 1) {
    throw GradleException("SOUNDCONNECT_PREVIEW must be specified exactly once for preview builds.")
}
val previewValue = previewDefines.singleOrNull()?.substringAfter('=', "")
if (previewValue != null && previewValue !in setOf("true", "false")) {
    throw GradleException("SOUNDCONNECT_PREVIEW accepts only true or false.")
}
val isPreview = previewValue == "true"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.berkayb.soundconnect.soundconnect_23_12_25codx"
        if (isPreview) {
            applicationId = "com.berkayb.soundconnect.soundconnect_23_12_25codx.preview"
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
