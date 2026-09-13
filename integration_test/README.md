# Musician feed device performance check

This is a test entry point using the production feed view, Cubit, card registry,
theme, image cache and image decoder. It does not run `main.dart`, initialize
secure storage, load a real account, call the backend, or start media services.
The populated feed exists only in RAM. The transport override blocks external
hosts and redirects a reserved fixture host to the device's loopback image server.
The production HTTPS policy is unchanged. Only this run's fixture cache entries
are removed at teardown.

Run on a physical Android device, with the normal app run detached first:

```powershell
flutter pub get
flutter analyze --no-pub integration_test test_driver
flutter drive --profile --no-pub --no-dds -d DEVICE_SERIAL --dart-define=SOUNDCONNECT_BASE_URL=https://feed-profile.invalid --driver=test_driver/musician_feed_profile_driver.dart --target=integration_test/musician_feed_profile_test.dart
```

The profile build retains the application's required HTTPS API configuration.
The harness checks the exact reserved fixture endpoint before creating widgets
or sockets; an omitted define or a real API endpoint fails preflight.

The default retains uploaded-image fixtures for every event, matching the
original before/after benchmark. For additional default-design coverage, append
`--dart-define=FEED_PROFILE_MIXED_EVENT_POSTERS=true`: alternate event cards then
have no poster URL and use the production `EventPosterFallback`. That mode
reports and asserts both uploaded and default event variants. Compare raster
results only between runs with the same scenario mode.

The driver saves `tmp/musician_feed_performance/phone_profile_report.json` on
success **or failure**. Archive it before another run. It includes a VM timeline,
three repeated scroll / paginate / refresh cycles, actual display-rate frame
budgets, p50/p95/p99/max build and raster duration, slow frame counts/ratios,
image decode and seven-card-family coverage, RSS and image-cache samples.
Warm-up and the first measured pass are distinct from the warmed passes.
The warmed acceptance limits are p95 within the display budget and at most 5%
slow frames per build/raster stage. Functional, image and pagination assertions
prevent a fallback-only or idle-only false pass.

`--no-dds` lets the on-device integration binding connect directly to its VM
service for timeline capture; a host-side DDS endpoint is not device loopback.

Record device/OS, active refresh rate, temperature, battery, mirroring/recording
overhead, and whether the phone was otherwise idle. ADB `dumpsys meminfo` can
supplement the in-process RSS samples. Do not infer a leak from a single RSS
increase; compare the repeated equivalent-work cycle samples and cache size.
On this Android device, `ProcessInfo.maxRss` sometimes reports less than
`currentRss`. Keep the raw field for diagnostics but do not use it as a reliable
peak. Report the current-RSS/cache trajectory; the short run establishes neither
a reliable peak-memory value nor a long-session leak guarantee.

The screen must remain awake and unlocked throughout the measurement. Flutter
test gestures do not substitute for Android user activity. Check device power
and keyguard state before a run, especially after stopping screen mirroring.
An asleep/locked run is invalid even if the driver connected successfully.
Record and restore any temporary USB stay-awake setting; never request or
automate a device password. Compare mirroring on/off with the same saved APK
before attributing a difference to application code.

Limits: synthetic data and 120ms repository delay are not backend measurements;
the bundled logo/poster images exercise decoding/rendering but not photographic
diversity; TLS/CDN/mobile network cost and audio/video playback are excluded.
The short run does not establish long-session memory stability. Restore the
ordinary app APK when finished; its existing account credentials are preserved.

Verification decision on 2026-09-13: the original production icon and waveform
drawing passed the unchanged all-uploaded-poster gates with screen mirroring
disabled on the Vivo V2206 at 60 Hz. Warmed build p95 was 8.567 / 7.560 ms and
raster p95 was 12.698 / 11.359 ms, with each build/raster slow-frame ratio below
5%. Seven card families, 60 delivered items, pagination, refresh and real image
decoding were observed without image/external-request errors. See
`../../.local-verification/feed_performance_20260913/phone-profile-original-no-mirror.json`.
The retained-icon boundary and waveform batching experiments are inactive and
discarded from production; no benefit is claimed for them. Earlier mirrored
runs had different time/battery/temperature conditions, so avoid assigning the
entire difference to mirroring.

The separate mixed/default-poster run also passed, observing both event designs,
seven card families, 40 distinct delivered items, three pagination loads and four
initial/refresh loads. Warmed build p95 was 7.624 / 8.198 ms and raster p95 was
11.248 / 12.003 ms. Build slow-frame ratios were 2.478% / 2.390%; raster ratios
were 1.053% / 1.532%. Real image coverage included 41 requests and seven decoded
images, with no image/external-request errors. Its RSS trajectory was
245.05 → 239.39 → 242.76 MiB and its image cache was
14,781,412 → 14,781,412 → 14,875,444 bytes; the final cache increase was 94,032
bytes, so it was not exactly constant. See
`../../.local-verification/feed_performance_20260913/phone-profile-original-mixed-posters.json`.
Both scenarios used the original production drawing. Their different fixtures
are separate acceptance coverage, not evidence of an optimization benefit.
