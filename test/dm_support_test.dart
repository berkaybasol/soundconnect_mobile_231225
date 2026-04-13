import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_auth_support.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/models/dm_conversation_preview_model.dart';

void main() {
  group('dm auth support', () {
    test(
      'resolveCurrentUserId reads non-uuid user id from token payload',
      () async {
        final token = _buildJwt(<String, dynamic>{'sub': 'user_42'});
        final tokenStore = _InMemoryTokenStore(token);

        final userId = await resolveCurrentUserId(tokenStore);

        expect(userId, 'user_42');
      },
    );

    test('resolveCurrentUserId returns null for malformed token', () async {
      final tokenStore = _InMemoryTokenStore('invalid.token');

      final userId = await resolveCurrentUserId(tokenStore);

      expect(userId, isNull);
    });
  });

  group('dm conversation preview model', () {
    test('parses lastMessageRead from string and number forms', () {
      final asString = DmConversationPreviewModel.fromJson(<String, dynamic>{
        'conversationId': 'c1',
        'otherUserId': 'u2',
        'otherUsername': 'a',
        'lastMessageRead': 'true',
      });
      final asNumber = DmConversationPreviewModel.fromJson(<String, dynamic>{
        'conversationId': 'c2',
        'otherUserId': 'u2',
        'otherUsername': 'a',
        'lastMessageRead': 0,
      });

      expect(asString.lastMessageRead, isTrue);
      expect(asNumber.lastMessageRead, isFalse);
    });
  });
}

String _buildJwt(Map<String, dynamic> payload) {
  final header = _base64UrlEncode(<String, dynamic>{
    'alg': 'none',
    'typ': 'JWT',
  });
  final body = _base64UrlEncode(payload);
  return '$header.$body.signature';
}

String _base64UrlEncode(Map<String, dynamic> jsonMap) {
  return base64Url.encode(utf8.encode(jsonEncode(jsonMap))).replaceAll('=', '');
}

class _InMemoryTokenStore implements TokenStore {
  _InMemoryTokenStore(this._value);

  String? _value;

  @override
  Future<void> clear() async {
    _value = null;
  }

  @override
  Future<String?> readToken() async => _value;

  @override
  Future<void> writeToken(String token) async {
    _value = token;
  }
}
