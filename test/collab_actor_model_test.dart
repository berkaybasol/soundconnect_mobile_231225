import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/models/collab_api_models.dart';

void main() {
  test('Collab actor parser reads contactUsername when present', () {
    final actor = CollabActorModel.fromJson(
      _actorJson(contactUsername: '  @deniz  '),
    );

    expect(actor.contactUsername, '@deniz');
  });

  test('Collab actor parser defaults a missing contactUsername to empty', () {
    final actor = CollabActorModel.fromJson(_actorJson());

    expect(actor.contactUsername, isEmpty);
  });

  test('profile availability is independent of the historical contact', () {
    final accountDeleted = _actorJson()
      ..['profileType'] = 'MUSICIAN'
      ..['contactUserId'] = null
      ..['profileAvailable'] = false;
    expect(CollabActorModel.fromJson(accountDeleted).canOpenProfile, isFalse);

    final continuingBand = _actorJson()
      ..['contactUserId'] = null
      ..['profileAvailable'] = true;
    final band = CollabActorModel.fromJson(continuingBand);
    expect(band.canOpenProfile, isTrue);
    expect(band.contactUserId, isEmpty);

    final oldReview = _actorJson()
      ..['profileType'] = 'MUSICIAN'
      ..remove('contactUserId');
    expect(CollabActorModel.fromJson(oldReview).canOpenProfile, isTrue);
  });
}

Map<String, dynamic> _actorJson({String? contactUsername}) => <String, dynamic>{
  'actorId': 'actor-band',
  'profileType': 'BAND',
  'sourceProfileId': 'band-profile-1',
  'contactUserId': 'user-band',
  if (contactUsername != null) 'contactUsername': contactUsername,
  'displayName': 'Acoustic Route',
  'avatarUrl': 'https://cdn.example.com/band.jpg',
  'rating': 4.7,
  'reviewCount': 9,
  'completedJobCount': 21,
};
