import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_message.dart';

void main() {
  for (final platform in TargetPlatform.values) {
    test('$platform uses only the matching store placeholder', () {
      final message = EventShareMessage.forPlatform(platform);
      final destination = switch (platform) {
        TargetPlatform.android => '[Google Play URL’si buraya eklenecek]',
        TargetPlatform.iOS => '[App Store URL’si buraya eklenecek]',
        _ => '[Uygulama indirme URL’si buraya eklenecek]',
      };
      expect(message, 'Etkinlik detayları için:\n$destination');
      expect(message.split('\n'), hasLength(2));
      expect(message, isNot(contains('https://')));
    });
  }
}
