import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import '../domain/analytics_observation.dart';
import 'analytics_tracker.dart';

enum ConsentChoice { undecided, granted, denied }

class AnalyticsPreference {
  const AnalyticsPreference(
    this.choice, {
    this.identity,
    this.guestLiveId,
    this.revision = 0,
  });
  static const policy = '2026-11-26-r3';
  static const _originalPolicy = '2026-11-26';
  final ConsentChoice choice;
  final String? identity;
  final String? guestLiveId;
  final int revision;

  static AnalyticsPreference decode(Object? data) {
    if (data is! Map || data['revision'] is! int || data['revision'] < 0) {
      throw const FormatException('Invalid analytics preference');
    }
    final revision = data['revision'] as int;
    final identity = data['analyticsUserId'];
    if (data['policyVersion'] == _originalPolicy ||
        data['policyVersion'] == '2026-11-26-r2') {
      // Neither earlier notice covered first-party live activity.
      // A prior refusal still disables measurement during a rolling upgrade.
      return switch (data['decision']) {
        'DENIED' when identity == null => AnalyticsPreference(
          ConsentChoice.denied,
          revision: revision,
        ),
        'UNDECIDED' when identity == null => AnalyticsPreference(
          ConsentChoice.undecided,
          revision: revision,
        ),
        'GRANTED' when identity is String && isAnalyticsUuid(identity) =>
          AnalyticsPreference(ConsentChoice.undecided, revision: revision),
        _ => throw const FormatException('Invalid legacy analytics preference'),
      };
    }
    if (data['policyVersion'] != policy) {
      throw const FormatException('Unsupported analytics policy');
    }
    return switch (data['decision']) {
      'GRANTED' when identity is String && isAnalyticsUuid(identity) =>
        AnalyticsPreference(
          ConsentChoice.granted,
          identity: identity,
          revision: revision,
        ),
      'DENIED' when identity == null => AnalyticsPreference(
        ConsentChoice.denied,
        revision: revision,
      ),
      'UNDECIDED' when identity == null => AnalyticsPreference(
        ConsentChoice.undecided,
        revision: revision,
      ),
      _ => throw const FormatException('Invalid analytics decision'),
    };
  }
}

class AnalyticsConsentStore {
  AnalyticsConsentStore(this.api, {required this.environment});
  final ApiClient api;
  static const _device = FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'sc_analytics_choices'),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  final String environment;
  static const _path = '/api/v1/users/me/analytics-preference';
  String get _guestKey =>
      'analytics_guest_${AnalyticsPreference._originalPolicy}_$environment';
  String _denialKey(String account) =>
      'analytics_pending_denial_$environment${sha256.convert(utf8.encode(account))}';

  Future<void> clearLegacyObservations() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      AnalyticsTracker.queueKey,
      AnalyticsTracker.installationKey,
    ]) {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
  }

  Future<AnalyticsPreference> guest({bool? allow}) async {
    final previous = await _device.read(key: _guestKey);
    if (allow == false) {
      await _device.write(key: _guestKey, value: 'denied');
      return const AnalyticsPreference(ConsentChoice.denied);
    }
    // The old key is retained so replacing one record retires both identities
    // atomically and an existing refusal continues to apply on upgrade.
    if (previous != null && previous.startsWith('{')) {
      try {
        final data = jsonDecode(previous);
        if (data is Map &&
            data['policy'] == AnalyticsPreference.policy &&
            data['ga4'] is String &&
            isAnalyticsUuid(data['ga4']) &&
            data['live'] is String &&
            isAnalyticsUuid(data['live']) &&
            data['ga4'] != data['live']) {
          return AnalyticsPreference(
            ConsentChoice.granted,
            identity: data['ga4'],
            guestLiveId: data['live'],
          );
        }
      } on FormatException {
        // Corrupt data grants nothing. A new explicit choice can replace it.
      }
    }
    if (allow == null) {
      return AnalyticsPreference(
        previous == 'denied' ? ConsentChoice.denied : ConsentChoice.undecided,
      );
    }
    final ga4 = const Uuid().v4();
    final live = const Uuid().v4();
    await _device.write(
      key: _guestKey,
      value: jsonEncode({
        'policy': AnalyticsPreference.policy,
        'ga4': ga4,
        'live': live,
      }),
    );
    return AnalyticsPreference(
      ConsentChoice.granted,
      identity: ga4,
      guestLiveId: live,
    );
  }

  Future<AnalyticsPreference> member(
    AuthSession session,
    int credentialRevision, {
    bool? allow,
    int? revision,
  }) {
    return api.request(
      allow == null ? ApiHttpMethod.get : ApiHttpMethod.put,
      _path,
      requestContext: ApiRequestContext(
        expectedSessionKey: session.userId,
        expectedToken: session.token,
        expectedCredentialRevision: credentialRevision,
      ),
      body: allow == null
          ? null
          : {
              'decision': allow ? 'GRANTED' : 'DENIED',
              'policyVersion': AnalyticsPreference.policy,
              'expectedRevision': revision!,
            },
      decoder: AnalyticsPreference.decode,
    );
  }

  Future<int?> pendingDenial(String account) async {
    final stored = await _device.read(key: _denialKey(account));
    return stored == null ? null : int.parse(stored);
  }

  Future<void> setPendingDenial(String account, int? revision) async {
    final key = _denialKey(account);
    if (revision == null) {
      await _device.delete(key: key);
    } else {
      await _device.write(key: key, value: revision.toString());
    }
  }
}
