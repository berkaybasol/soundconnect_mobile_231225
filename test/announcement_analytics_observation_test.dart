import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/domain/analytics_observation.dart';

const _id = '00000000-0000-4000-8000-000000000001';
const _announcement = '00000000-0000-4000-8000-000000000002';
const _playback = '00000000-0000-4000-8000-000000000003';

void main() {
  for (final type in AnalyticsObservationType.values.where(
    (type) => type.isAnnouncement,
  )) {
    for (final source in ['FEED', 'DIRECTORY']) {
      test('${type.wireValue} $source round trips an immutable receipt', () {
        final observation = AnalyticsObservation(
          id: _id,
          type: type,
          observedAt: DateTime.utc(2026, 9, 13),
          announcementId: _announcement,
          source: source,
          playbackId: type.isAnnouncementVideo ? _playback : null,
          impressionToken: source == 'FEED' ? 'scoped-delivery-proof' : null,
        );
        expect(observation.isValid, isTrue);
        expect(
          AnalyticsObservation.fromJson(observation.toJson()).toJson(),
          observation.toJson(),
        );
        expect(observation.toJson().containsKey('eventId'), isFalse);
        expect(observation.toJson().containsKey('deliveryId'), isFalse);
      });
    }
  }

  final valid = AnalyticsObservation(
    id: _id,
    type: AnalyticsObservationType.announcementImpression,
    observedAt: DateTime.utc(2026, 9, 13),
    announcementId: _announcement,
    source: 'FEED',
    impressionToken: 'proof',
  ).toJson();
  for (final change in <Map<String, dynamic>>[
    {'announcementId': null},
    {'announcementId': 'invalid'},
    {'announcementId': '00000000-0000-0000-0000-000000000000'},
    {'source': null},
    {'source': 'ADMIN_PREVIEW'},
    {'source': 'DIRECTORY'},
    {'impressionToken': null},
    {'impressionToken': ''},
    {'impressionToken': ' '},
    {'impressionToken': List.filled(4097, 'x').join()},
    {'eventId': _announcement},
    {'venueId': _announcement},
    {'sourceEventId': _announcement},
    {'playbackId': _playback},
    {'type': 'ANNOUNCEMENT_VIDEO_START'},
    {'type': 'EVENT_IMPRESSION', 'eventId': _announcement},
  ]) {
    test(
      'invalid announcement context is rejected: ${change.keys.join(',')} ${change.values.first.toString().length}',
      () {
        expect(
          () => AnalyticsObservation.fromJson({...valid, ...change}),
          throwsA(isA<FormatException>()),
        );
      },
    );
  }
}
