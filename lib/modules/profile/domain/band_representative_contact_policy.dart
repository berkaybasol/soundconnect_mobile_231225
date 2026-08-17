import 'entities/band_member_summary.dart';

class BandRepresentativeContactPolicy {
  const BandRepresentativeContactPolicy._();

  static BandMemberSummary? resolve(Iterable<BandMemberSummary> members) {
    BandMemberSummary? representative;

    for (final member in members) {
      final isEligible =
          member.status.trim().toUpperCase() == 'ACTIVE' &&
          member.isFounder &&
          member.userId.trim().isNotEmpty;
      if (!isEligible) continue;

      if (representative != null) return null;
      representative = member;
    }

    return representative;
  }
}
