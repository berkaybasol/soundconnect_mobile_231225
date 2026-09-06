import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_data.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_service.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_sheet.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
);

void main() {
  test(
    'public pending identity stays plain without a share consent notice',
    () {
      final data = EventShareData.fromDetail(_detail());
      expect(data.performerLabel, 'bugrasahin');
      expect(
        data.accessibilityDescription,
        isNot(contains('katılımını henüz doğrulamadı')),
      );
      expect(data.accessibilityDescription, isNot(contains('@bugrasahin')));
      expect(data.dateLabel, '06 Eylül 2026');
      expect(data.weekdayLabel, 'Pazar');
      expect(data.timeLabel, '20:00 – 22:00');
      expect(data.location, 'Çankaya · Ankara');
    },
  );

  for (final type in ['MUSICIAN', 'BAND']) {
    test('$type links use public identity only', () {
      final data = EventShareData.fromDetail(
        _detail(
          type: type,
          musicianId: type == 'MUSICIAN' ? 'm1' : null,
          bandId: type == 'BAND' ? 'b1' : null,
        ),
      );
      expect(data.performerLabel, '@bugrasahin');
    });
  }

  for (final type in ['MANUAL', 'BAND', 'MUSICIAN', 'UNKNOWN']) {
    test('ambiguous $type identity never implies consent', () {
      final data = EventShareData.fromDetail(
        _detail(type: type, musicianId: 'm1', bandId: 'b1'),
      );
      expect(data.performerLinked, isFalse);
    });
  }

  for (final name in ['', '-', 'Yakında açıklanacak', '  @ @ Performer  ']) {
    test('placeholder $name is not a pending artist', () {
      final data = EventShareData.fromDetail(_detail(name: name));
      expect(data.hasPerformer, isFalse);
      expect(data.performerLabel, 'Belirtilmemiş');
    });
  }

  test(
    'no fabricated times, dates, location or links for sparse public data',
    () {
      final data = EventShareData.fromDetail(
        const VenueEventDetail(
          id: 'e',
          shareUrl: null,
          posterImage: null,
          performerName: null,
          musicianProfileId: null,
          startTime: '99:45:00',
          endTime: '22:00',
          venueCity: '-',
          venueDistrict: ' ',
        ),
      );
      expect(data.title, 'Etkinlik');
      expect(data.timeLabel, isEmpty);
      expect(data.eventDate, isNull);
      expect(data.location, isEmpty);
      expect(data.safeShareUrl, isNull);
      expect(data.accessibilityDescription, isNot(contains('MANUAL')));
    },
  );

  for (final entry in <String, String?>{
    'null': null,
    'empty': '',
    'whitespace': '  \r\n\t  ',
  }.entries) {
    test('${entry.key} event description does not fabricate share copy', () {
      final data = EventShareData.fromDetail(_detail(description: entry.value));
      expect(data.description, isEmpty);
      expect(
        data.accessibilityDescription,
        'M-T1 — Katıl, gösterme\n'
        '06 Eylül 2026 · 20:00 – 22:00\n'
        'bugrasahin\n'
        '@soundconnectankara\n'
        'Çankaya · Ankara',
      );
      expect(data.accessibilityDescription, isNot(contains('MANUAL')));
    });
  }

  test(
    'event description is trimmed and retained in full in preview accessibility text',
    () {
      final fullDescription = [
        'Ankara’da müzik dolu bir akşam.',
        '',
        'Kapılar 19.30’da açılır.',
        ...List.filled(12, 'Bu açıklamayı mekan bu etkinlik için yazdı.'),
      ].join('\n');
      final data = EventShareData.fromDetail(
        _detail(
          description: '  \n$fullDescription\n\t ',
          shareUrl: 'https://soundconnect.com.tr/events/e1',
        ),
      );
      expect(data.description, fullDescription);
      expect(
        data.accessibilityDescription,
        'M-T1 — Katıl, gösterme\n'
        '$fullDescription\n'
        '06 Eylül 2026 · 20:00 – 22:00\n'
        'bugrasahin\n'
        '@soundconnectankara\n'
        'Çankaya · Ankara\n'
        'https://soundconnect.com.tr/events/e1',
      );
      expect(data.accessibilityDescription, isNot(contains('doğrulanmadı')));
      expect(data.accessibilityDescription, isNot(contains('doğrulamadı')));
    },
  );

  test('authored description is not mistaken for an old fallback', () {
    final data = EventShareData.fromDetail(
      _detail(description: '  MANUAL performansı  '),
    );
    expect(data.description, 'MANUAL performansı');
    expect(data.accessibilityDescription, contains('\nMANUAL performansı\n'));
  });

  for (final url in [
    'javascript:alert(1)',
    'file:///event',
    'https://u:p@host/event',
    'http://host/event',
    '/events/1',
  ]) {
    test('unsafe or relative share link is omitted: $url', () {
      final data = EventShareData.fromDetail(_detail(shareUrl: url));
      expect(data.safeShareUrl, isNull);
      expect(data.accessibilityDescription, isNot(contains(url)));
    });
  }
  test('preserves the actual HTTPS event URL', () {
    final data = EventShareData.fromDetail(
      _detail(shareUrl: 'https://soundconnect.com.tr/events/e1'),
    );
    expect(data.safeShareUrl, 'https://soundconnect.com.tr/events/e1');
    expect(data.accessibilityDescription, endsWith(data.safeShareUrl!));
  });

  for (final approved in [false, true]) {
    for (final withPoster in [false, true]) {
      for (final description in <String, String?>{
        'absent': null,
        'blank': ' \n\t ',
        'long': List.filled(
          18,
          'Müzik ve dostlarla Ankara’da unutulmaz bir akşam.',
        ).join(' '),
        'multiline': List.generate(
          8,
          (index) => 'Etkinlik açıklaması ${index + 1}: Ankara’da buluşuyoruz.',
        ).join('\n\n'),
      }.entries) {
        testWidgets(
          'fixed card approved=$approved poster=$withPoster description=${description.key}',
          (tester) async {
            tester.view.physicalSize = const Size(800, 1000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final data = EventShareData.fromDetail(
              _detail(
                name: 'Çok Uzun Sanatçı ve Grup Adı & Konuk Müzisyenler',
                title: 'Ankara’da\nMüzik ve\nDostlarla',
                description: description.value,
                type: approved ? 'MUSICIAN' : 'MANUAL',
                musicianId: approved ? 'm1' : null,
              ),
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.navy,
                home: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(3)),
                  child: Center(
                    child: EventShareCard(
                      data: data,
                      posterImage: withPoster ? MemoryImage(_pixel) : null,
                      venueAvatar: withPoster ? MemoryImage(_pixel) : null,
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(
              tester.getSize(find.byType(EventShareCard)),
              const Size(360, 640),
            );
            expect(find.text(data.performerLabel), findsOneWidget);
            final cardRect = tester.getRect(find.byType(EventShareCard));
            final titleRect = tester.getRect(find.text(data.title));
            final performerRect = tester.getRect(
              find.text(data.performerLabel),
            );
            final venueRect = tester.getRect(find.text(data.venueLabel));
            final descriptionFinder = find.byKey(
              const Key('event-share-description'),
            );
            expect(tester.widget<Text>(find.text(data.title)).maxLines, 3);
            if (data.description.isEmpty) {
              expect(descriptionFinder, findsNothing);
            } else {
              expect(descriptionFinder, findsOneWidget);
              final descriptionText = tester.widget<Text>(descriptionFinder);
              final descriptionRect = tester.getRect(descriptionFinder);
              expect(descriptionText.data, data.description);
              expect(descriptionText.maxLines, inInclusiveRange(1, 4));
              expect(descriptionText.overflow, TextOverflow.ellipsis);
              expect(descriptionRect.height, greaterThan(0));
              expect(descriptionRect.top, greaterThan(titleRect.bottom));
              expect(descriptionRect.bottom, lessThan(performerRect.top));
              expect(descriptionRect.left, greaterThanOrEqualTo(cardRect.left));
              expect(descriptionRect.right, lessThanOrEqualTo(cardRect.right));
            }
            expect(venueRect.top, greaterThan(performerRect.bottom));
            expect(venueRect.bottom, lessThan(cardRect.bottom));
            expect(venueRect.left, greaterThanOrEqualTo(cardRect.left));
            expect(venueRect.right, lessThanOrEqualTo(cardRect.right));
            expect(find.text('Katılım henüz doğrulanmadı'), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final size in [const Size(320, 568), const Size(640, 320)]) {
    testWidgets('share choices remain reachable at $size / 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      EventShareTarget? selected;
      final prepared = PreparedEventShare(
        bytes: _pixel,
        data: EventShareData.fromDetail(_detail()),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  selected = await showEventShareSheet(context, prepared);
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Image>(find.byKey(const Key('event-share-preview')))
            .semanticLabel,
        prepared.data.accessibilityDescription,
      );
      final target = find.byKey(const Key('event-share-target-other'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      final instagram = find.byKey(
        const Key('event-share-target-instagramStory'),
      );
      if (instagram.evaluate().isNotEmpty) {
        expect(tester.getSize(instagram).height, tester.getSize(target).height);
        expect(tester.getRect(instagram).top, tester.getRect(target).top);
      }
      expect(tester.takeException(), isNull);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(selected, EventShareTarget.other);
      expect(find.byType(EventShareSheet), findsNothing);
    });
  }
}

VenueEventDetail _detail({
  String name = ' @ @bugrasahin ',
  String type = 'MANUAL',
  String? musicianId,
  String? bandId,
  String title = 'M-T1 — Katıl, gösterme',
  String? description,
  String? shareUrl,
}) => VenueEventDetail(
  id: 'e1',
  shareUrl: shareUrl,
  posterImage: null,
  performerName: name,
  musicianProfileId: musicianId,
  bandId: bandId,
  performerType: type,
  title: title,
  description: description,
  eventDate: DateTime(2026, 9, 6),
  startTime: '20:00:00',
  endTime: '22:00:00',
  venueName: 'soundconnectankara',
  venueCity: 'Ankara',
  venueDistrict: 'Çankaya',
);
