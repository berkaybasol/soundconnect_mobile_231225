import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';

void main() {
  test('legacy BOS_ADAM role uses a professional member label', () {
    const member = BandMemberSummary(
      userId: 'user-1',
      profileId: 'profile-1',
      username: 'deniz',
      profilePictureUrl: null,
      role: 'BOS_ADAM',
      status: 'ACTIVE',
    );

    expect(member.localizedRoleLabel, 'Ekip üyesi');
  });
}
