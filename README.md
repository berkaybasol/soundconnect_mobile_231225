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

If `SOUNDCONNECT_BASE_URL` is not provided, the app falls back to the local
development default defined in `lib/core/network/network_config.dart`.

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

## Current Technical Notes

- The largest maintenance surface is `lib/modules/profile/presentation/screens`.
- Dependency wiring is centralized in `lib/core/di/service_locator.dart`.
- API access is funneled through `lib/core/network/dio_api_client.dart`.
