import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/profile_contact_uri.dart';

typedef StudioWebsiteLauncher = Future<bool> Function(Uri uri);

class StudioProfileWebsiteLink extends StatelessWidget {
  const StudioProfileWebsiteLink({
    required this.website,
    this.launcher,
    super.key,
  });

  final String? website;
  final StudioWebsiteLauncher? launcher;

  @override
  Widget build(BuildContext context) {
    final uri = profileHttpUri(website);
    if (uri == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          key: const Key('studio-profile-website-link'),
          onTap: () => _open(context, uri),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.language_rounded,
                  size: 13,
                  color: Color(0xFF9EA8B7),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _displayText(uri),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB5BECC),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF778293),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 11,
                  color: Color(0xFF778293),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = launcher == null
          ? await launchUrl(uri, mode: LaunchMode.externalApplication)
          : await launcher!(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
    }
  }

  String _displayText(Uri uri) {
    final path = uri.path == '/' ? '' : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '${uri.host}$path$query';
  }
}
