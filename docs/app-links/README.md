# SoundConnect verified app links

The mobile apps claim this permanent public URL contract:

```text
https://soundconnect.com.tr/is-birligi/ilan/{listingId}
```

Android is configured in `android/app/src/main/AndroidManifest.xml`. iOS is
configured through `ios/Runner/Runner.entitlements`. Both platforms delegate
link delivery to the `app_links` Flutter plugin, so Flutter's built-in deep-link
handler is explicitly disabled in the platform configuration.

The landing page may additionally use
`soundconnect://is-birligi/ilan/{listingId}` behind an explicit **Open in app**
button for embedded browsers that suppress verified HTTPS handoff. This custom
scheme is a fallback only; public and shareable links must always remain HTTPS.

## Values still required before deployment

- Android production SHA-256 signing certificate fingerprint. When Play App
  Signing is enabled, use the **App signing key certificate** fingerprint from
  Play Console, not the upload key. For non-Play distribution, use the release
  keystore certificate fingerprint.
- Apple Developer Team ID for the app identifier
  `com.berkayb.soundconnect.soundconnect231225codx`.
- The Associated Domains capability must be enabled for that App ID and be
  present in the production provisioning profile.

Do not put placeholder values on the public domain. Copy the templates in this
directory, replace their placeholders, then validate the resulting JSON.
The Apple template uses the `appIDs` / `components` contract. The application
deployment target is iOS 13 because `app_links` 7.0.0 requires iOS 13 or newer.

## Files to publish on `soundconnect.com.tr`

Publish the completed Android template as:

```text
https://soundconnect.com.tr/.well-known/assetlinks.json
```

Publish the completed Apple template, **without a file extension**, as:

```text
https://soundconnect.com.tr/.well-known/apple-app-site-association
```

Both endpoints must:

- return HTTPS `200` directly, without a redirect to `www` or another path;
- use a valid public TLS certificate;
- return `Content-Type: application/json`;
- be reachable without authentication, cookies, VPN, or an IP allowlist.

The listing URL itself must return a mobile-friendly web fallback when the app
is not installed. It may show the listing summary plus App Store / Play Store
actions; it must not return a blank page or `404`.

If `www.soundconnect.com.tr` is ever used in shared links, add that host to both
apps and publish both association files on that host too. Host matching is exact.

## Android verification

Install a build signed with a fingerprint present in the deployed
`assetlinks.json`, then run:

```shell
adb shell pm set-app-links --package com.berkayb.soundconnect.soundconnect_23_12_25codx 0 all
adb shell pm verify-app-links --re-verify com.berkayb.soundconnect.soundconnect_23_12_25codx
adb shell pm get-app-links com.berkayb.soundconnect.soundconnect_23_12_25codx
adb shell am start -W -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://soundconnect.com.tr/is-birligi/ilan/550e8400-e29b-41d4-a716-446655440000"
```

The domain state should be `verified`, and the final command should resolve to
SoundConnect without an app chooser. A debug build has a different signing
fingerprint; add that fingerprint temporarily only when verified debug testing
is necessary.

## iOS verification

After the AASA file is public, enable Associated Domains for the App ID, refresh
the provisioning profile, build a signed app, and reinstall it. Tap the HTTPS
link from Notes or Messages; typing or pasting it into Safari's address bar does
not exercise the normal universal-link handoff. The link should open
SoundConnect directly.

Apple may cache the AASA file. Reinstall the app after publishing a correction,
and allow time for Apple's associated-domain CDN to refresh.

For an archive, confirm the signed entitlement with:

```shell
codesign -d --entitlements :- Runner.app
```

The output must contain `applinks:soundconnect.com.tr`.
