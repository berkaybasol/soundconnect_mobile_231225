import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_common_widgets.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_track_delete_menu.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets('owner audio title stays centered at text scale $textScale', (
      tester,
    ) async {
      var openedDetail = false;
      const cardKey = ValueKey('audio-card');
      const waveformKey = ValueKey('waveform');
      const title = 'Uzun bir ses kaydının profil kartında gösterilen adı';
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: ProfileAudioPreviewCard(
                    key: cardKey,
                    title: title,
                    onTap: () => openedDetail = true,
                    waveform: const SizedBox(
                      key: waveformKey,
                      width: double.infinity,
                      height: 92,
                    ),
                    trailing: ProfileTrackDeleteMenu(
                      ownerType: 'MUSICIAN_PROFILE',
                      ownerId: 'owner',
                      trackId: 'track',
                      onDeleted: () async {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final card = tester.getRect(find.byKey(cardKey));
      final titleRect = tester.getRect(find.text(title));
      final menu = tester.getRect(find.byType(ProfileTrackDeleteMenu));
      final waveform = tester.getRect(find.byKey(waveformKey));
      expect(titleRect.center.dx, closeTo(card.center.dx, 0.01));
      expect(titleRect.right, lessThanOrEqualTo(menu.left));
      expect(menu.top, card.top);
      expect(menu.right, card.right);
      expect(menu.size, const Size(48, 48));
      expect(menu.bottom, lessThanOrEqualTo(waveform.top));
      expect(tester.widget<Icon>(find.byIcon(Icons.more_vert)).size, 18);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Ses seçenekleri'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Sil'), findsOneWidget);
      expect(openedDetail, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
