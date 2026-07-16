import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_public_bottom_bar.dart';
import '../../../../shared/theme/app_colors.dart';

part 'profile_venue_support_intro_screens.dart';
part 'profile_venue_support_bottom_bar.dart';

const _hideVenueConnectionIntroKey = 'hide_venue_connection_intro';

Future<bool> shouldShowVenueConnectionIntro() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_hideVenueConnectionIntroKey) != true;
}

Future<void> setVenueConnectionIntroHidden(bool hidden) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_hideVenueConnectionIntroKey, hidden);
}

class VenueRequestPayload {
  final String venueId;
  final String message;

  const VenueRequestPayload({required this.venueId, required this.message});
}

enum ConnectedArtistType { musician, band }

class ConnectedArtistRequestPayload {
  final ConnectedArtistType type;
  final String targetId;
  final String message;

  const ConnectedArtistRequestPayload({
    required this.type,
    required this.targetId,
    required this.message,
  });
}
