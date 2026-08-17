import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const host = 'soundconnect.com.tr';
  const listingPathPrefix = '/is-birligi/ilan/';

  test('Android claims only the verified Collab listing URL surface', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:host="$host"'));
    expect(manifest, contains('android:pathPrefix="$listingPathPrefix"'));
    expect(manifest, contains('android:scheme="soundconnect"'));
    expect(manifest, contains('android:host="is-birligi"'));
    expect(manifest, contains('android:pathPrefix="/ilan/"'));
    expect(
      manifest,
      contains(
        RegExp(
          r'<meta-data\s+android:name="flutter_deeplinking_enabled"\s+'
          r'android:value="false"\s*/>',
        ),
      ),
    );
  });

  test('iOS enables the associated domain for app_links', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final frameworkInfo = File(
      'ios/Flutter/AppFrameworkInfo.plist',
    ).readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();

    expect(
      infoPlist,
      contains(RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>')),
    );
    expect(entitlements, contains('<string>applinks:$host</string>'));
    expect(
      infoPlist,
      contains(
        RegExp(
          r'<key>CFBundleURLSchemes</key>\s*<array>\s*'
          r'<string>soundconnect</string>',
        ),
      ),
    );
    expect(
      project,
      contains(
        RegExp(r'com\.apple\.AssociatedDomains\s*=\s*\{\s*enabled\s*=\s*1;'),
      ),
    );
    expect(
      RegExp(
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner\\.entitlements;',
      ).allMatches(project),
      hasLength(3),
    );
    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 13\.0;').allMatches(project),
      hasLength(3),
    );
    expect(frameworkInfo, contains('<string>13.0</string>'));
    expect(podfile, contains("platform :ios, '13.0'"));
  });

  test('deployment templates match the application identifiers and path', () {
    final assetLinks =
        jsonDecode(
              File(
                'docs/app-links/assetlinks.json.template',
              ).readAsStringSync(),
            )
            as List<dynamic>;
    final androidTarget =
        (assetLinks.single as Map<String, dynamic>)['target']
            as Map<String, dynamic>;

    expect(
      androidTarget['package_name'],
      'com.berkayb.soundconnect.soundconnect_23_12_25codx',
    );
    expect(
      androidTarget['sha256_cert_fingerprints'],
      contains('REPLACE_WITH_PLAY_APP_SIGNING_OR_RELEASE_CERT_SHA256'),
    );

    final appleAssociation =
        jsonDecode(
              File(
                'docs/app-links/apple-app-site-association.template',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final appleLinks = appleAssociation['applinks'] as Map<String, dynamic>;
    final detail =
        (appleLinks['details'] as List<dynamic>).single as Map<String, dynamic>;

    expect(
      detail['appIDs'],
      contains(
        'REPLACE_WITH_APPLE_TEAM_ID.'
        'com.berkayb.soundconnect.soundconnect231225codx',
      ),
    );
    final components = detail['components'] as List<dynamic>;
    expect(
      (components.single as Map<String, dynamic>)['/'],
      '$listingPathPrefix*',
    );
  });
}
