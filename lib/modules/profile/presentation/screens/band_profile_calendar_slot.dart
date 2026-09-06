import 'package:flutter/material.dart';

import '../../data/band_calendar_repository_factory.dart';
import 'band_calendar_repository_scope.dart';
import 'musician_profile_calendar_slot.dart';

class BandProfileCalendarSlot extends StatelessWidget {
  const BandProfileCalendarSlot({
    super.key,
    required this.bandId,
    this.refreshToken,
    this.compactTitle = false,
    this.factory,
  });

  final String bandId;
  final Object? refreshToken;
  final bool compactTitle;
  final BandCalendarRepositoryFactory? factory;

  @override
  Widget build(BuildContext context) => BandCalendarRepositoryScope(
    bandId: bandId,
    factory: factory,
    builder: (repository) => MusicianProfileCalendarSlot(
      profileId: bandId,
      refreshToken: refreshToken,
      compactTitle: compactTitle,
      repository: repository,
    ),
  );
}
