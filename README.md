# SoundConnect Mobile

Flutter mobile client for SoundConnect. The current product surface is centered
on musician and venue profile flows, media publishing, Spotify track linking,
engagement actions, and auth/onboarding.

## Stack

- Flutter
- flutter_bloc
- get_it
- dio
- audio_service + just_audio
- better_player_plus

## Project Structure

```text
lib/
  app/        App bootstrap, shell, router
  core/       Network, auth, DI, audio, shared primitives
  modules/    Feature modules such as auth, profile, follow, engagement
  shared/     Theme and reusable UI widgets
```

## Main Feature Areas

- `auth`: login, register, OTP verify, venue application
- `profile`: musician and venue owner/public profile experiences
- `artist_venue`: venue-musician connection flows
- `follow`: follow state and follow/unfollow actions
- `engagement`: likes and comments
- `spotify`: track search and preview data
- `location`, `instrument`: lookup data used by forms and filters

## Run Locally

1. Install Flutter and platform toolchains.
2. Fetch dependencies:

```bash
flutter pub get
```

3. Start the app with an explicit backend URL when needed:

```bash
flutter run --dart-define=SOUNDCONNECT_BASE_URL=http://localhost:8080
```

For Android emulator use `http://10.0.2.2:8080`.
For physical devices use your computer LAN IP (for example
`http://192.168.1.50:8080`).

Debug builds can fall back to the local development default in
`lib/core/network/network_config.dart`. Non-debug builds require
`SOUNDCONNECT_BASE_URL` and enforce HTTPS.

## Android Release Signing

Release signing now auto-loads `android/key.properties` when present. If this
file is missing, local release builds continue with debug signing.

Example `android/key.properties`:

```properties
storeFile=../keystore/release.jks
storePassword=your_store_password
keyAlias=your_key_alias
keyPassword=your_key_password
```

## Quality Checks

```bash
flutter analyze
flutter test
```

## Development Quality Gate

Use a single command before opening a PR:

```bash
dart run tool/quality_gate.dart
```

This gate enforces:

- formatted Dart files (`dart format --set-exit-if-changed`)
- static analysis (`flutter analyze`)
- tests with coverage (`flutter test --coverage`)
- no temporary `//eklendi` comments
- no increase in `ignore_for_file` debt
- no regression in maximum Dart file size baseline
- no regression in baseline line coverage

When a baseline increase is intentional, update it explicitly:

```bash
dart run tool/quality_gate.dart --update-baseline
```

## Current Technical Notes

- The largest maintenance surface is `lib/modules/profile/presentation/screens`.
- Dependency wiring is centralized in `lib/core/di/service_locator.dart`.
- API access is funneled through `lib/core/network/dio_api_client.dart`.
