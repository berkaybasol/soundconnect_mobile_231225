# Isolated Android preview

The user-facing app is **SoundConnect Önizleme**, package
`com.berkayb.soundconnect.soundconnect_23_12_25codx.preview`. Android gives it a
different UID and files/preferences/cache directory from the normal app. It has
its own launcher icon and `PreviewActivity`, no app links or background audio
service, and no INTERNET/network-state permissions. Fixture interactions belong
to this app; they cannot authenticate against or write to the ordinary backend.

Ordinary Android builds keep their existing application ID, manifest, entrypoint,
and source sets. Preview resources, native activity, and assets are included only
when `SOUNDCONNECT_PREVIEW=true` is paired with the exact preview entrypoint.
Release preview builds and mismatched flag/target combinations fail during
Gradle configuration, including a lifecycle task that indirectly selects release.

## Build or install the user preview

Use an existing Flutter/Android SDK. The helpers do not install or modify SDKs,
start infrastructure, run migrations, change ADB forwarding, or clear app data.
Pass the existing SDK's `aapt` executable explicitly:

```powershell
./tool/preview/preview_android.ps1 -Action Build -Aapt 'C:/path/to/build-tools/aapt.exe'
./tool/preview/preview_android.ps1 -Action Install -DeviceSerial 'DEVICE_SERIAL' `
  -Aapt 'C:/path/to/build-tools/aapt.exe' -Launch
```

`-Flutter` and `-Adb` accept existing executable paths if they are absent from
PATH. The helper builds `lib/main_preview.dart` in profile mode by default, with
`SOUNDCONNECT_PREVIEW=true` and
`SOUNDCONNECT_BASE_URL=https://preview.soundconnect.invalid`. `-Mode debug` is
also accepted for an offline install; Flutter VM debugging requires the QA mode
below. The helper validates the **compiled APK** before copying it to
`build/preview/soundconnect-preview-profile.apk` and again before installation.
Installation uses only that verified preview package and an explicit device.

## Device QA exception

Only `integration_test/feed_preview_device_test.dart` with the preview flag is
permitted to use a debug manifest containing INTERNET for Flutter VM tooling.
The runtime reports `previewQa=true`; Dart's preview bootstrap must reject a QA
package unless its explicit QA entrypoint was used and must keep its transport
guard enabled. This QA artifact is distinct from the final offline artifact.
The build/install helper intentionally never installs the QA artifact.

```powershell
flutter build apk --debug --target=integration_test/feed_preview_device_test.dart `
  --dart-define=SOUNDCONNECT_PREVIEW=true `
  --dart-define=SOUNDCONNECT_BASE_URL=https://preview.soundconnect.invalid
./tool/preview/verify_apk.ps1 -Apk build/app/outputs/flutter-apk/app-debug.apk `
  -Aapt 'C:/path/to/build-tools/aapt.exe' -Qa
flutter drive --driver=test_driver/feed_preview_device_driver.dart `
  --target=integration_test/feed_preview_device_test.dart -d DEVICE_SERIAL `
  --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk `
  --dart-define=SOUNDCONNECT_PREVIEW=true `
  --dart-define=SOUNDCONNECT_BASE_URL=https://preview.soundconnect.invalid
```

After QA, rebuild/install the ordinary offline preview. Do not distribute a QA
artifact as the user preview. Android network-security XML is not an egress
firewall; the user artifact's missing INTERNET permission is the OS boundary.

## Bootstrap and fixture contract

Channel `soundconnect/preview/isolation`, method `status`, returns actual native
`packageName`, `internetPermissionGranted`, and the immutable manifest `previewQa`
boolean. Dart checks all three before initializing the preview runtime.

The preview owns one `FlutterEngine` with automatic plugin registration disabled
in its constructor, before any activity attachment. It ignores cached-engine
intent extras and lets the activity delegate destroy that engine on teardown.
The channel also reports `registeredPluginNames`: `jni`, `jni_flutter`,
`audio_session`, `just_audio`, `better_player_plus`, `sqflite_android`,
`wakelock_plus`, and `video_player_android`; only the QA artifact adds
`integration_test`. The JNI pair supports the installed path-provider version.
The ordinary generated registrant is untouched. In particular, the preview never
registers `audio_service`, whose native activity attachment can create a second
engine even without Dart's `AudioService.init`. Flutter's built-in external text
processing actions are also disabled; ordinary copy/paste remains available.

The preview manifest removes the normal share and image-picker file providers,
the unused photo-picker module declaration, and the URL launcher's WebView
activity. AndroidX's internal startup provider and its lifecycle, WorkManager,
Room and profile-installation components remain. BetterPlayer obtains
WorkManager when constructing a player, so these internal components support
the reused native player; they do not expose the fixture files for sharing.

Place fixtures only at `android/app/src/preview/assets/preview/<name>`; they never
enter a normal APK via this source set. Channel method `readFixture` takes
`{'name': 'filename.ext'}` and returns `Uint8List` bytes. Only bounded ASCII bare
filenames are accepted; slash, backslash and `..` are rejected, and each read is
capped at 16 MiB. No native filesystem path is accepted. Use these asset/file
bytes for images and audio/video instead of a loopback HTTP server.

`generate_graphics.ps1` reproducibly draws the 18 original PNG illustrations with
Windows System.Drawing and writes the PNG-only `manifest.json` array. It requires
no downloads or user images and leaves audio/video untouched. The runtime loads
`audio.wav` and `video.mp4` separately. `missing.png` and `loading.png` are
intentionally absent because the catalogue uses them for controlled error/delay
states.

`generate_media.ps1 -Ffmpeg 'C:/path/to/ffmpeg.exe'` creates the eight-second
original soft chord WAV and animated illustration MP4. These are demonstration
media, not third-party recordings. Run the graphics generator first.

## Validation

`check_build_policy.ps1` explicitly exercises valid and invalid flag/target
combinations using offline Gradle configuration tasks. It requires already
available dependencies and does not build an APK. Per-case logs are retained in
`build/preview/policy-checks`. `verify_apk.ps1` checks the
actual application ID, label, launcher, QA metadata, permissions, fixture assets,
backup policy and absence of normal deep links/audio/share components.

Verify both artifacts after integration changes: the preview passes the helper,
while a normal build retains its original package/launcher and has no
`assets/preview/` files. Device QA must also confirm that the native status and
invalid fixture-name errors agree with the installed artifact.
