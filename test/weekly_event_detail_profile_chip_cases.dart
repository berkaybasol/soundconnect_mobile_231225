part of 'weekly_event_detail_design_test.dart';

void _adaptiveProfileChipTests(_VenueRepository Function() venueRepository) {
  group('adaptive performer and venue chips', () {
    setUp(() => venueRepository().includePhoto = false);

    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('short names stay natural at $width dp / ${scale}x', (
          tester,
        ) async {
          await _openDetail(
            tester,
            _event(
              artistName: 'A',
              artistProfileId: 'musician-approved',
              performerType: 'MUSICIAN',
              venueName: 'B',
              venueId: 'venue-real-id',
            ),
            size: Size(width, 844),
            textScale: scale,
          );

          final (performer, venue) = _profileChipRects(tester, width);
          expect(performer.width, lessThan(128));
          expect(venue.width, lessThan(128));
          expect(performer.width, closeTo(venue.width, 1));
          expect(venue.right, lessThan(width - 24));
          for (final label in ['@A', '@B']) {
            expect(
              tester
                  .renderObject<RenderParagraph>(find.text(label))
                  .didExceedMaxLines,
              isFalse,
            );
          }
          _expectCenteredProfileChip(tester, performerChip: true);
          _expectCenteredProfileChip(tester, performerChip: false);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final type in ['BAND', 'MUSICIAN']) {
      testWidgets(
        '$type gives a longer name space without stretching short name',
        (tester) async {
          double? shortWidth;
          for (final name in ['Şahbaz', 'Dolu Kadehi Ters Tut']) {
            await _openDetail(
              tester,
              _event(
                artistName: name,
                artistProfileId: type == 'MUSICIAN'
                    ? 'musician-approved'
                    : null,
                bandProfileId: type == 'BAND' ? 'band-approved' : null,
                performerType: type,
                venueName: 'soundconnectankara',
                venueId: 'venue-real-id',
              ),
            );

            final (performer, venue) = _profileChipRects(tester, 390);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.text('@$name'),
            );
            if (name == 'Şahbaz') {
              shortWidth = performer.width;
              expect(paragraph.didExceedMaxLines, isFalse);
            } else {
              expect(performer.width, greaterThan(shortWidth!));
              expect(paragraph.didExceedMaxLines, isTrue);
              expect(
                (performer.width - venue.width).abs(),
                lessThanOrEqualTo(24),
              );
            }
            _expectCenteredProfileChip(tester, performerChip: true);
            _expectCenteredProfileChip(tester, performerChip: false);
            expect(_performerNameInkWell(tester, '@$name').onTap, isNotNull);
            expect(_performerInfoButton(), findsNothing);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }

    for (final size in [
      const Size(320, 844),
      const Size(390, 844),
      const Size(740, 360),
    ]) {
      for (final approved in [false, true]) {
        testWidgets(
          'dual long names keep balanced one-line chips at $size / 2x / approved=$approved',
          (tester) async {
            const artist = 'Dolu Kadehi Ters Tut ve Bütün Konuk Müzisyenler';
            const venue = 'soundconnectankarauzunmekankullaniciadi';
            await _openDetail(
              tester,
              _event(
                artistName: artist,
                bandProfileId: approved ? 'band-approved' : null,
                performerType: 'BAND',
                venueName: venue,
                venueId: 'venue-real-id',
              ),
              size: size,
              textScale: 2,
            );
            await tester.scrollUntilVisible(
              _performerChip(),
              180,
              scrollable: find.descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              ),
            );
            await tester.pumpAndSettle();
            final (artistRect, venueRect) = _profileChipRects(
              tester,
              size.width,
            );
            // Pending performers keep the additional 48 dp info target, but
            // neither identity is allowed to monopolize the row.
            expect(
              artistRect.width / venueRect.width,
              inInclusiveRange(.7, 1.45),
            );
            for (final label in [approved ? '@$artist' : artist, '@$venue']) {
              final text = tester.widget<Text>(find.text(label));
              expect(text.maxLines, 1);
              expect(text.overflow, TextOverflow.ellipsis);
              expect(
                tester
                    .renderObject<RenderParagraph>(find.text(label))
                    .didExceedMaxLines,
                isTrue,
              );
              expect(find.byTooltip(label), findsOneWidget);
            }
            expect(
              _performerNameInkWell(
                tester,
                approved ? '@$artist' : artist,
              ).onTap,
              approved ? isNotNull : isNull,
            );
            if (approved) {
              expect(_performerInfoButton(), findsNothing);
            } else {
              final infoSize = tester.getSize(_performerInfoButton());
              expect(infoSize.width, greaterThanOrEqualTo(48));
              expect(infoSize.height, greaterThanOrEqualTo(48));
              await tester.tap(_performerInfoButton());
              await tester.pumpAndSettle();
              expect(_performerInfoDialog(), findsOneWidget);
              await tester.ensureVisible(find.text('Anladım'));
              await tester.tap(find.text('Anladım'));
              await tester.pumpAndSettle();
              expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
    testWidgets(
      'generous width displays full names beyond the old 220 dp cap',
      (tester) async {
        const name = 'Dolu Kadehi Ters Tut';
        await _openDetail(
          tester,
          _event(
            artistName: name,
            bandProfileId: 'band-approved',
            performerType: 'BAND',
            venueName: 'soundconnectankara',
            venueId: 'venue-real-id',
          ),
          size: const Size(1024, 844),
        );
        _profileChipRects(tester, 1024);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('@$name'),
        );
        expect(paragraph.size.width, greaterThan(220));
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('@soundconnectankara'))
              .didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('late venue photo does not resize either identity chip', (
      tester,
    ) async {
      final gate = Completer<void>();
      venueRepository()
        ..includePhoto = true
        ..profileGate = gate;
      await _openDetail(
        tester,
        _event(
          artistName: 'Şahbaz',
          bandProfileId: 'band-approved',
          performerType: 'BAND',
          venueName: 'soundconnectankara',
          venueId: 'venue-real-id',
        ),
        settle: false,
      );
      final before = _profileChipRects(tester, 390);
      expect(
        find.descendant(
          of: _venueChip(),
          matching: find.byType(AppCachedNetworkImage),
        ),
        findsNothing,
      );
      gate.complete();
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump();
      }
      final after = _profileChipRects(tester, 390);
      expect(after, before);
      expect(
        find.descendant(
          of: _venueChip(),
          matching: find.byType(AppCachedNetworkImage),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets(
      'bold accessibility labels are measured with their actual weight',
      (tester) async {
        await _openDetail(
          tester,
          _event(
            artistName: 'A',
            bandProfileId: 'band-approved',
            performerType: 'BAND',
            venueName: 'B',
            venueId: 'venue-real-id',
          ),
          textScale: 2,
          boldText: true,
        );
        final (performer, venue) = _profileChipRects(tester, 390);
        expect(performer.width, closeTo(venue.width, 1));
        expect(performer.width, lessThan(128));
        for (final label in ['@A', '@B']) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.style!.fontWeight, FontWeight.bold);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
        }
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Finder _performerChip() =>
    find.byKey(const Key('event-performer-profile-chip'));

Finder _venueChip() => find.byKey(const Key('event-venue-profile-chip'));

(Rect, Rect) _profileChipRects(WidgetTester tester, double width) {
  final performer = tester.getRect(_performerChip());
  final venue = tester.getRect(_venueChip());
  expect(performer.top, closeTo(venue.top, .01));
  expect(performer.bottom, closeTo(venue.bottom, .01));
  expect(performer.height, greaterThanOrEqualTo(48));
  expect(venue.left - performer.right, closeTo(8, .01));
  expect(performer.left, greaterThanOrEqualTo(16));
  expect(venue.right, lessThanOrEqualTo(width - 16));
  return (performer, venue);
}

void _expectCenteredProfileChip(
  WidgetTester tester, {
  required bool performerChip,
}) {
  final chip = performerChip ? _performerChip() : _venueChip();
  final bounds = tester.getRect(chip);
  final leading = tester.getRect(
    find.descendant(
      of: chip,
      matching: find.byIcon(
        performerChip ? Icons.music_note_outlined : Icons.storefront_outlined,
      ),
    ),
  );
  final trailing = tester.getRect(
    find.descendant(
      of: chip,
      matching: find.byIcon(Icons.chevron_right_rounded),
    ),
  );
  // The leading glyph is 16 dp inside its stable 20 dp visual slot.
  expect(leading.left - bounds.left, closeTo(bounds.right - trailing.right, 3));
}
