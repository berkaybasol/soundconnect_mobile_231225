import 'package:flutter/material.dart';

import 'profile_public_bottom_bar.dart';
import '../../../../shared/theme/app_colors.dart';

part 'profile_venue_support_intro_screens.dart';
part 'profile_venue_support_bottom_bar.dart';

class VenueRequestPayload {
  final String venueId;
  final String message;

  const VenueRequestPayload({required this.venueId, required this.message});
}

class MusicianRequestPayload {
  final String musicianProfileId;
  final String message;

  const MusicianRequestPayload({
    required this.musicianProfileId,
    required this.message,
  });
}
