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

- `auth`: login, register, OTP verify, venue and Studio applications
- `profile`: musician, venue, and Studio owner/public profile experiences
- `studio`: rooms, reservations, schedules, backline inventory, availability,
  and catalog-review requests
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

For Android emulator use `http://10.0.2.2:8080`, or keep the debug default
`http://127.0.0.1:8080` after running `adb reverse tcp:8080 tcp:8080`.
For physical devices use your computer LAN IP (for example
`http://192.168.1.50:8080`).

Debug builds can fall back to the local development default in
`lib/core/network/network_config.dart`. Non-debug builds require
`SOUNDCONNECT_BASE_URL` and enforce HTTPS.

## Realtime STOMP Contract

Broker subscriptions use RabbitMQ-compatible `/topic/...` destinations. In
particular, notifications subscribe to `/topic/notifications.{userId}` (and
its `.badge` child), while table-group chat subscribes to
`/topic/table-group.{tableGroupId}`. Slash-based `/notifications/...` and
`/table_group/...` destinations are invalid with the production broker relay.

TableGroup chat writes use the acknowledged REST endpoint in the first release;
its STOMP topic is receive-only. Reviewed Pulse `/app` commands remain
application destinations and must not be rewritten as broker topics. Keep
destination construction centralized in `lib/core/realtime/stomp_destinations.dart`
and cover any contract change with the corresponding realtime-client tests.

## Android Release Signing

Release signing auto-loads `android/key.properties`. Release builds fail fast
when the file or any required value is missing; debug signing is never used for
a release artifact.

Before the first Play Store upload, replace the temporary Android
`applicationId` in `android/app/build.gradle.kts` with the reviewed permanent
package identifier. Treat that identifier as immutable after publication.

Example `android/key.properties`:

```properties
storeFile=../keystore/release.jks
storePassword=your_store_password
keyAlias=your_key_alias
keyPassword=your_key_password
```

Build the production artifacts only with the real HTTPS API origin:

```bash
flutter build appbundle --release \
  --dart-define=SOUNDCONNECT_BASE_URL=https://api.soundconnect.example
flutter build apk --release \
  --dart-define=SOUNDCONNECT_BASE_URL=https://api.soundconnect.example
```

Keep `key.properties` and the keystore outside version control; back up the
upload key through the organization's controlled secret-management process.

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

- changed Dart files are formatted (`dart format --set-exit-if-changed`)
- static analysis (`flutter analyze`)
- tests with coverage (`flutter test --coverage`)
- no temporary `//eklendi` comments
- no increase in `ignore_for_file` debt
- a 1,200-line limit for new Dart files
- no growth in explicitly recorded legacy oversized files
- no regression in baseline line coverage

The legacy list is a monotonic ratchet, not a permanent exemption: each
recorded file may shrink but may not grow. Any reduction must lower the
recorded baseline in the same change, and the entry is removed after the file
drops below the global limit. When a baseline improvement is reviewed, update
it explicitly:

```bash
dart run tool/quality_gate.dart --update-baseline
```

To run only the incremental format check (without Flutter tooling):

```bash
dart run tool/quality_gate.dart --format-only
```

The Studio screens have been split below the enforced size limit and no longer
need a format/analyzer legacy exception. The gate permits no `lib/` Dart
analyzer exclusions; future Studio changes must pass the same rules as the rest
of the application.

## Current Technical Notes

- The largest maintenance surface is `lib/modules/profile/presentation/screens`.
- Dependency wiring is centralized in `lib/core/di/service_locator.dart`.
- API access is funneled through `lib/core/network/dio_api_client.dart`.
