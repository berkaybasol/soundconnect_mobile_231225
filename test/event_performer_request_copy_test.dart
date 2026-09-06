import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_request_copy.dart';

void main() {
  for (final target in EventPerformerTargetType.values) {
    final isBand = target == EventPerformerTargetType.band;
    group('${target.name} invitation copy', () {
      test('consent explains discovery without repeating the name', () {
        final request = _request(target);

        expect(
          request.purposeExplanation,
          isBand
              ? 'Onaylarsan mekan etkinliğinde grubunun profil bağlantısı '
                    'açılır. Bu özellik grubunu SoundConnect’te daha görünür kılar.'
              : 'Onaylarsan mekan etkinliğinde profil bağlantın açılır. '
                    'Bu özellik seni SoundConnect’te daha görünür kılar.',
        );
        expect(
          request.purposeExplanation,
          isNot(contains(request.performerName)),
        );
      });

      test('calendar summary stays short and has no comma after event', () {
        final request = _request(target);

        expect(
          request.calendarVisibilityExplanation,
          isBand
              ? 'Seçtiğin etkinlik grup profilinde görünür. Sonradan gizleyebilirsin.'
              : 'Seçtiğin etkinlik profilinde görünür. Sonradan gizleyebilirsin.',
        );
        expect(request.calendarVisibilityExplanation, isNot(contains(',')));
      });

      test('consent help distinguishes linking from optional publication', () {
        final help = _request(target).calendarVisibilityHelpParagraphs.first;

        expect(
          help,
          contains(
            isBand
                ? '“Bu etkinliği grubun profilinde de göster”'
                : '“Bu etkinliği profilimde de göster”',
          ),
        );
        expect(help, contains('İşaretlemeden onaylarsan'));
        expect(help, contains('profil bağlantı'));
        expect(
          help,
          contains(
            isBand
                ? 'Etkinlik grup profilinde görünmez'
                : 'Etkinlik kendi profilinde görünmez',
          ),
        );
      });

      test('connected help preserves the link even on rejection', () {
        final request = _request(
          target,
          purpose: EventPerformerRequestPurpose.profileVisibility,
        );
        final help = request.calendarVisibilityHelpParagraphs.first;

        expect(help, contains('Reddetsen de'));
        expect(help, contains('korunur'));
        expect(help, isNot(contains('bağlantısı açılır')));
        expect(help, isNot(contains('bağlantın açılır')));
        expect(help, isNot(contains('seçeneğini')));
        expect(request.purposeExplanation, contains('bu karardan etkilenmez'));
      });

      for (final purpose in EventPerformerRequestPurpose.values) {
        test('${purpose.name} help documents per-event show and hide', () {
          final request = _request(target, purpose: purpose);
          final help = request.calendarVisibilityHelpParagraphs.join('\n');

          expect(
            request.calendarVisibilityHelpTitle,
            'Profilde nasıl görünür?',
          );
          expect(help, contains('“Etkinliklerim” bölümünden'));
          expect(
            help,
            contains('“Etkinliklerim” bölümünden değiştirebilirsin.'),
          );
          expect(
            help,
            contains(
              isBand
                  ? 'etkinliklerin grup profilinde görünüp görünmeyeceğini'
                  : 'etkinliklerin profilinde görünüp görünmeyeceğini',
            ),
          );
          expect(help, isNot(contains('Haftalık Takvim')));
          expect(help, isNot(contains('ayar')));
          expect(
            request.calendarVisibilityHelpParagraphs,
            hasLength(isBand ? 3 : 2),
          );
          if (isBand) {
            expect(help, contains('üyelerin kişisel profillerini değiştirmez'));
            expect(help, contains('Aktif üyeler'));
            expect(help, contains('ayrı ayrı karar verir'));
          } else {
            expect(help, isNot(contains('grup')));
          }
        });

        test('${purpose.name} uses preference language, not switch jargon', () {
          final request = _request(target, purpose: purpose);
          final copy = [
            request.purposeExplanation,
            request.calendarVisibilityExplanation,
            request.calendarVisibilityHelpTitle,
            ...request.calendarVisibilityHelpParagraphs,
            request.decisionSuccessMessage(accept: false),
            request.decisionSuccessMessage(accept: true),
            request.decisionSuccessMessage(accept: true, showOnProfile: true),
          ].join('\n');

          expect(copy.toLowerCase(), isNot(contains('anahtar')));
          expect(copy.toLowerCase(), isNot(contains('mekân')));
          expect(copy, isNot(contains(';')));
          expect(
            request.decisionSuccessMessage(accept: true, showOnProfile: true),
            contains('Etkinlik profil takvimine eklendi.'),
          );
        });
      }
    });
  }
}

EventPerformerRequest _request(
  EventPerformerTargetType target, {
  EventPerformerRequestPurpose purpose =
      EventPerformerRequestPurpose.performerConsent,
}) {
  final isBand = target == EventPerformerTargetType.band;
  return EventPerformerRequest(
    requestId: 'request-1',
    eventId: 'event-1',
    eventTitle: 'Test etkinliği',
    eventDate: DateTime(2026, 9, 6),
    startTime: '20:00',
    endTime: '22:00',
    venueId: 'venue-1',
    venueName: 'soundconnectankara',
    venueProfilePictureUrl: null,
    targetType: target,
    targetId: 'performer-1',
    musicianProfileId: isBand ? null : 'performer-1',
    bandId: isBand ? 'performer-1' : null,
    performerName: isBand ? 'Şahbaz' : 'bugrasahin',
    status: EventPerformerRequestStatus.pending,
    requestPurpose: purpose,
    profileCalendarApproved: false,
    createdAt: DateTime(2026, 9, 5),
    decidedAt: null,
  );
}
