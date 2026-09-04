import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../spotify/domain/spotify_playlist_uri.dart';

Future<void> launchSpotifyPlaylist(
  BuildContext context,
  String spotifyUrl,
) async {
  final uri = spotifyPlaylistUri(spotifyUrl);
  if (uri == null) {
    _showLaunchError(context, 'Spotify bağlantısı geçersiz.');
    return;
  }
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showLaunchError(context, 'Spotify açılamadı.');
    }
  } catch (_) {
    if (context.mounted) _showLaunchError(context, 'Spotify açılamadı.');
  }
}

void _showLaunchError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
