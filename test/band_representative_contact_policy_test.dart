import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_representative_contact_policy.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';

void main() {
  group('BandRepresentativeContactPolicy', () {
    test('returns null when there is no eligible founder', () {
      expect(BandRepresentativeContactPolicy.resolve(const []), isNull);
      expect(
        BandRepresentativeContactPolicy.resolve(const [
          _inactiveFounder,
          _founderWithoutUserId,
        ]),
        isNull,
      );
    });

    test('returns the only active founder with a user id', () {
      final representative = BandRepresentativeContactPolicy.resolve(const [
        _activeMember,
        _activeFounder,
      ]);

      expect(representative, same(_activeFounder));
    });

    test('fails closed when two eligible founders exist', () {
      final representative = BandRepresentativeContactPolicy.resolve(const [
        _activeFounder,
        _secondActiveFounder,
      ]);

      expect(representative, isNull);
    });

    test('never falls back to an active regular member', () {
      final representative = BandRepresentativeContactPolicy.resolve(const [
        _activeMember,
      ]);

      expect(representative, isNull);
    });
  });
}

const _activeFounder = BandMemberSummary(
  userId: 'founder-1',
  profileId: 'musician-1',
  username: 'deniz',
  profilePictureUrl: 'founder.jpg',
  role: 'FOUNDER',
  status: 'ACTIVE',
);

const _secondActiveFounder = BandMemberSummary(
  userId: 'founder-2',
  profileId: 'musician-2',
  username: 'ece',
  profilePictureUrl: 'founder-2.jpg',
  role: ' founder ',
  status: ' active ',
);

const _inactiveFounder = BandMemberSummary(
  userId: 'founder-inactive',
  profileId: null,
  username: 'inactive',
  profilePictureUrl: null,
  role: 'FOUNDER',
  status: 'LEFT',
);

const _founderWithoutUserId = BandMemberSummary(
  userId: ' ',
  profileId: null,
  username: 'missing-id',
  profilePictureUrl: null,
  role: 'FOUNDER',
  status: 'ACTIVE',
);

const _activeMember = BandMemberSummary(
  userId: 'member-1',
  profileId: 'musician-member',
  username: 'member',
  profilePictureUrl: 'member.jpg',
  role: 'MEMBER',
  status: 'ACTIVE',
);
