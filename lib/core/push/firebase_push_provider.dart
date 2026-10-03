import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'push_provider.dart';

/// Android rich DM data is rendered by the native MessagingStyle service.
/// Legacy/APNs alert payloads are rendered by the OS. This isolate deliberately
/// never reads credentials, marks messages read, or navigates.
@pragma('vm:entry-point')
Future<void> soundConnectPushBackgroundHandler(RemoteMessage message) async {
  // No background work is necessary: reconcile from the API on next resume.
}

class FirebasePushProvider
    implements
        PushProvider,
        PushRecipientBindingProvider,
        PushDeliveredProvider {
  static const _native = MethodChannel('com.soundconnect/push_delivery');
  final _opened = StreamController<PushTarget>.broadcast();
  StreamSubscription<RemoteMessage>? _legacyOpened;
  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<void> initialize() async {
    // Native google-services.json / GoogleService-Info.plist belong to the
    // selected environment. Missing configuration is handled by coordinator.
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    await _messaging.setAutoInitEnabled(false);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    FirebaseMessaging.onBackgroundMessage(soundConnectPushBackgroundHandler);
    _legacyOpened ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final target = PushTarget.parse(message.data);
      if (target != null) _opened.add(target);
    });
    if (platform == 'ANDROID') {
      _native.setMethodCallHandler((call) async {
        if (call.method == 'opened' && call.arguments is Map) {
          final target = PushTarget.parseNativeMetadata(
            Map<String, dynamic>.from(call.arguments as Map),
          );
          if (target != null) _opened.add(target);
        }
      });
    }
  }

  @override
  Future<void> bindRecipient(String? recipientId) async {
    if (platform == 'ANDROID') {
      await _native.invokeMethod<void>('bindRecipient', {
        'recipientId': recipientId,
      });
    }
  }

  @override
  Future<PushDeliveredSnapshot?> deliveredSnapshot(String recipientId) async {
    if (platform != 'ANDROID') return null;
    final data = await _native.invokeMapMethod<String, dynamic>(
      'deliveredSnapshot',
      {'recipientId': recipientId},
    );
    if (data == null) return null;
    final owner = data['recipientId'];
    final epoch = data['bindingEpoch'];
    final ids = data['notificationIds'];
    if (!PushTarget.isUuid(owner) ||
        !PushTarget.isUuid(epoch) ||
        ids is! List ||
        ids.length > 100 ||
        ids.any((id) => !PushTarget.isUuid(id))) {
      throw const FormatException('Invalid native delivery snapshot');
    }
    return PushDeliveredSnapshot(
      recipientId: (owner as String).toLowerCase(),
      bindingEpoch: (epoch as String).toLowerCase(),
      notificationIds: ids
          .cast<String>()
          .map((id) => id.toLowerCase())
          .toList(),
    );
  }

  @override
  Future<void> dismissDelivered(
    PushDeliveredSnapshot snapshot,
    List<String> notificationIds,
  ) async {
    if (platform != 'ANDROID' || notificationIds.isEmpty) return;
    await _native.invokeMethod<void>('dismissDelivered', {
      'recipientId': snapshot.recipientId,
      'bindingEpoch': snapshot.bindingEpoch,
      'notificationIds': notificationIds,
    });
  }

  @override
  Future<PushPermission> permission({bool request = false}) async {
    final settings = request
        ? await _messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
        : await _messaging.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => PushPermission.authorized,
      AuthorizationStatus.provisional => PushPermission.provisional,
      AuthorizationStatus.denied => PushPermission.denied,
      AuthorizationStatus.deniedPermanently => PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
    };
  }

  @override
  Future<String?> token() async {
    if (!(await permission()).canDeliver) return null;
    // APNs registration can lag permission acceptance. The coordinator retries
    // transient failures and every foreground resume without a permission loop.
    if (platform == 'IOS' && await _messaging.getAPNSToken() == null) {
      return null;
    }
    return _messaging.getToken();
  }

  @override
  Future<void> deleteToken() async {
    try {
      await const MethodChannel(
        'com.soundconnect/push',
      ).invokeMethod<void>('clearDelivered');
    } catch (_) {
      // Clearing an already displayed OS notification must never prevent token
      // invalidation (including a missing native channel in tests).
    }
    await _messaging.deleteToken();
  }

  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;
  @override
  Stream<PushTarget> get opened => _opened.stream;
  @override
  Stream<PushTarget> get foreground => _targets(FirebaseMessaging.onMessage);
  Stream<PushTarget> _targets(Stream<RemoteMessage> stream) => stream
      .map((message) => PushTarget.parse(message.data))
      .where((target) => target != null)
      .cast<PushTarget>();
  @override
  Future<PushTarget?> initialMessage() async {
    if (platform == 'ANDROID') {
      final data = await _native.invokeMapMethod<String, dynamic>(
        'initialMessage',
      );
      final target = data == null ? null : PushTarget.parseNativeMetadata(data);
      if (target != null) return target;
    }
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushTarget.parse(message.data);
  }
}
