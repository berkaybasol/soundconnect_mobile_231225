# SoundConnect mobile push — client behavior and setup

> Bu teknik belgenin sürüm ve davranış bilgileri bu belge temizliği sırasında kaynak kodla yeniden doğrulanmadı; güncel kurulum veya kabul sonucu değildir.


## Client behavior

- `SOUNDCONNECT_PUSH_ENABLED=true` enables the mobile integration. Desktop/web and
  offline preview are not supported push targets in this stage.
  In an Android APK built without this opt-in, both FCM receiver routes and
  messaging services are disabled, and the same native resource gates persisted
  notification work. Launching that disabled APK clears the previous account
  binding/cards; its native bridge cannot bind a new recipient. This also fences
  an old token that survived an enabled-to-disabled APK upgrade. Duplicate or
  non-Boolean push defines fail the build. This is a property of the installed
  APK, not a remote switch for older enabled installations: use the backend push
  delivery switch/account preferences for operational shutdown across devices.
- Permission is requested only from **Ayarlar → Bildirim ayarları**. A denial does
  not affect the durable in-app inbox. The screen also exposes the account-wide
  push switch. Existing disabled categories are preserved on updates.
- The device installation UUID survives logout in native storage excluded from
  device backups, so restoring onto another phone creates a distinct installation.
  Native storage also supplies a persisted monotonic `clientRevision`; the
  server ignores delayed older registration/revocation mutations. Android
  advertises `presentationVersion=ANDROID_DM_V1` for the native DM renderer.
  Registration requests are fenced
  to the captured account and bearer. Register, rotate, revoke, and subsequent
  account registration are serialized. No token or bearer is logged.
- Logout hides authenticated UI immediately. Cleanup uses the old captured bearer
  on an independent, time-bounded DELETE request; it never adopts a new account's
  credential. It also deletes the FCM token. If that fails, a persisted reset flag
  blocks reuse until token deletion succeeds. Startup repairs interrupted cleanup
  and stale ownership after token expiry. Network/provider rejection remains a
  possible failure, so no implementation should promise immediate revocation of
  notifications already accepted or displayed by the OS.
- Android channel `soundconnect_notifications` is separate from the existing
  audio playback channel. Logout clears displayed push notifications without
  cancelling audio playback. Foreground pushes reconcile the authoritative inbox
  and DM counter; they do not display an additional OS banner or mark a DM read.
- The background Dart handler does not use application credentials or mutate read
  state. Capable Android builds receive data-only DM and render native
  `MessagingStyle` with a `Person` avatar. The notification appears immediately
  with an initial fallback; WorkManager enriches the avatar from the configured
  HTTPS public CDN, without redirects or arbitrary URL access. Avatar failure
  does not delay the notification. Current recipient binding is stored outside
  backups and checked again at the final post/update. Logout clears that binding.
  Generic notification+data remains the compatibility path for older builds/iOS.
- Android conversation shortcuts are scoped to the recipient and native session
  epoch. Shortcut publication and cleanup run outside the recipient binding lock;
  delayed cleanup preserves the current epoch. Shortcut taps receive a fresh
  navigation event ID, while actual notification taps retain their notification ID.
  A navigation event is not a server read acknowledgement.
- A bounded, durable SQLite ledger reserves recipient/notification IDs before
  posting and keeps them across process restarts and logout/login until expiry.
  Corruption fails closed. A process crash between reservation and posting can
  omit an OS alert; the durable inbox remains the authoritative record.
- Lock-screen public presentation remains generic when Android hides private
  notification content. Device settings determine the final lock-screen layout.
  Android 26+ uses notification timeout; Android 24-25 uses best-effort scheduled
  expiry cleanup. A force-stopped application cannot promise background delivery.
- Background and terminated taps validate UUID identifiers and the current
  recipient. A tap before login waits for the matching account. DM navigation
  resolves a fresh, authenticated conversation projection, including ghost/deleted
  identities. Other types or inaccessible conversations open the inbox. Duplicate
  taps are suppressed for the current process/session.
- Resume, WebSocket reconnect, and foreground push reconcile unread counts. Only
  a resumed, topmost DM route acknowledges incoming messages. Local inbox read
  projection follows successful **per-message** ACKs; failed ACKs remain unread
  and expose a retryable error. Merely opening a hidden route never reads a DM.
- Warm resume and successful per-message ACK also reconcile delivered Android
  alerts. The client snapshots at most 100 owned notification IDs with the
  current native recipient/epoch, compares them through the authenticated,
  read-only `/api/v1/user/notifications/delivery-state` endpoint, and dismisses
  only the confirmed subset. Unread alerts remain. This comparison does not ACK
  messages and runs independently of FCM token registration. Errors preserve the
  tray; account/token changes and stale native epochs prevent late dismissal.
  Native cancellation and avatar updates share a lock, and a durable dismissed
  ledger entry is written before OS cancellation to block delayed avatar reposts.
  Cold startup still clears all delivered push alerts. Immediate remote OS
  cancellation while the other app remains closed/backgrounded is not implemented.

## Environment setup

**User scheduling decision, 2026-09-23:** Proceed with Android/backend now.
Defer iOS integration until general application development is complete.
The shared Flutter code and preliminary iOS changes do not prove a working iOS
integration. Analytics waits for all notification work to finish; the wizard
setting does not establish app integration. See [the Analytics decision](google-analytics-plan.md).

The user approved `tr.com.soundconnect.app` as the permanent Android package;
preview uses the separate `tr.com.soundconnect.app.preview` ID and must not use
the main Firebase config. See [the Android identity record](android-identity-20260923.md).
The selected Firebase project is `soundconnect-fa50e`. Before real users are
onboarded, development/test projects, credentials and data must be separated
from the live environment. The project choice does not authorize deployment.

The native Android client configuration belongs at `android/app/google-services.json`
and remains Git-ignored. The Gradle plugin is applied only for push-enabled builds
and rejects a missing file. Installing this file does not establish backend sender
authorization or prove device delivery. Do not copy the client API key into documentation
or logs. Never include server service-account JSON, APNs `.p8`, or private keys in
Flutter assets, Dart defines, the client repository, chat, or logs.

Launch a development build with:

```powershell
flutter run --dart-define=SOUNDCONNECT_PUSH_ENABLED=true
```

Set `SOUNDCONNECT_BASE_URL` as appropriate for the development backend. On a USB
Android device, the existing local workflow is `adb reverse tcp:8080 tcp:8080`
while the backend listens on port 8080. FCM needs internet access, but the backend
does not need to be published to receive test notifications. Backend configuration
must refer to the same Firebase project.

The deferred iOS setup requires the app's actual bundle ID, `GoogleService-Info.plist`
in the Runner target, Apple/APNs configuration and signing on macOS. Do not hardcode
production signing into development. Existing audio background mode must be preserved.
Preliminary configuration is not physical iPhone or release acceptance.
