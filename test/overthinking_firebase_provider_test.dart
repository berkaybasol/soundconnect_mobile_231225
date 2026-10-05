// Test the production provider entry points, not a replacement parser adapter.
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/push/firebase_push_provider.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';

class _Messaging extends FirebaseMessagingPlatform {
  RemoteMessage? initial;
  @override
  FirebaseMessagingPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
  @override
  Future<void> setAutoInitEnabled(bool enabled) async {}
  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async {}
  @override
  void registerBackgroundMessageHandler(BackgroundMessageHandler handler) {}
  @override
  Future<RemoteMessage?> getInitialMessage() async => initial;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messaging = _Messaging();
  final provider = FirebasePushProvider();
  Map<String, dynamic>? nativeInitial;
  const channel = MethodChannel('com.soundconnect/push_delivery');
  setUpAll(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseMessagingPlatform.instance = messaging;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'initialMessage') return nativeInitial;
      return null;
    });
    await provider.initialize();
  });
  tearDownAll(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  setUp(() {
    nativeInitial = null;
    messaging.initial = null;
  });
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  Future<void> nativeOpen(Map<String, dynamic> data) async {
    final done = Completer<void>();
    binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('opened', data)),
      (_) => done.complete(),
    );
    await done.future;
    await flush();
  }

  for (final type in PushTarget.overthinkingTypes) {
    Map<String, dynamic> identity() => {
      'notificationId': '50000000-0000-4000-8000-000000000001',
      'recipientId': '70000000-0000-4000-8000-000000000001',
      'type': type,
    };
    Map<String, dynamic> wire() {
      final now = DateTime.now().millisecondsSinceEpoch;
      return {
        ...identity(),
        'presentationVersion': 'ANDROID_OVERTHINKING_V1',
        'sentAt': '$now',
        'expiresAt': '${now + 60000}',
      };
    }

    test(
      '$type raw foreground/warm/cold reject incomplete invalid and expired envelopes',
      () async {
        final fg = <PushTarget>[], opened = <PushTarget>[];
        final s1 = provider.foreground.listen(fg.add),
            s2 = provider.opened.listen(opened.add);
        addTearDown(s1.cancel);
        addTearDown(s2.cancel);
        final valid = wire(), now = DateTime.now().millisecondsSinceEpoch;
        final invalid = <Map<String, dynamic>>[
          identity(),
          for (final key in valid.keys) {...valid}..remove(key),
          {...valid, 'extra': 'private'},
          {...valid, 'sent_at': valid['sentAt']}..remove('sentAt'),
          {...valid, 'presentationVersion': 'ANDROID_OVERTHINKING_V0'},
          {...valid, 'presentationVersion': 'ANDROID_OVERTHINKING_V2'},
          {...valid, 'presentationVersion': 'ANDROID_COLLAB_V1'},
          {...valid, 'notificationId': 'broken'},
          {...valid, 'recipientId': 'broken'},
          {...valid, 'sentAt': now},
          {...valid, 'sentAt': ' $now'},
          {...valid, 'sentAt': '+$now'},
          {...valid, 'sentAt': '0$now'},
          {...valid, 'sentAt': '9223372036854775808'},
          {...valid, 'sentAt': '${now + 60000}'},
          {...valid, 'expiresAt': '${now - 1000}'},
          {
            ...valid,
            'expiresAt': '${now + const Duration(days: 29).inMilliseconds}',
          },
        ];
        for (final data in invalid) {
          final msg = RemoteMessage(data: data);
          FirebaseMessagingPlatform.onMessage.add(msg);
          FirebaseMessagingPlatform.onMessageOpenedApp.add(msg);
          messaging.initial = msg;
          expect(await provider.initialMessage(), isNull, reason: '$data');
          await flush();
          expect(fg, isEmpty, reason: 'raw foreground $data');
          expect(opened, isEmpty, reason: 'raw warm $data');
        }
        final msg = RemoteMessage(data: wire());
        FirebaseMessagingPlatform.onMessage.add(msg);
        FirebaseMessagingPlatform.onMessageOpenedApp.add(msg);
        messaging.initial = msg;
        expect((await provider.initialMessage())?.type, type);
        await flush();
        expect(fg.single.type, type);
        expect(opened.single.type, type);
      },
    );

    test(
      '$type native validated minimal metadata remains valid warm and cold',
      () async {
        final opened = <PushTarget>[];
        final subscription = provider.opened.listen(opened.add);
        addTearDown(subscription.cancel);
        await nativeOpen(identity());
        expect(opened.single.type, type);
        nativeInitial = identity();
        expect((await provider.initialMessage())?.type, type);
        for (final invalid in [
          {...identity(), 'authorId': 'private'},
          {...identity()}..remove('recipientId'),
          {...identity(), 'notificationId': 'invalid'},
          {...identity(), 'recipientId': 'invalid'},
          {...identity(), 'type': 'OVERTHINKING_UNKNOWN'},
        ]) {
          await nativeOpen(invalid);
          nativeInitial = invalid;
          expect(await provider.initialMessage(), isNull);
        }
        expect(opened, hasLength(1));
      },
    );
  }
}
