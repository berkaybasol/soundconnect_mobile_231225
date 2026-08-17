import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../domain/entities/collab_listing.dart';
import 'collab_share_card.dart';
import 'collab_share_service.dart';

Future<CollabShareTarget?> showCollabShareSheet(
  BuildContext context,
  CollabListing listing,
) => showModalBottomSheet<CollabShareTarget>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => _CollabShareSheet(
    listing: listing,
    supportsDirectTargets: defaultTargetPlatform == TargetPlatform.android,
  ),
);

class _CollabShareSheet extends StatelessWidget {
  const _CollabShareSheet({
    required this.listing,
    required this.supportsDirectTargets,
  });

  final CollabListing listing;
  final bool supportsDirectTargets;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'İlanı paylaş',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          'İlanın, SoundConnect çerçeveli paylaşım kartına dönüştürülecek.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 17),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 126,
              height: 224,
              child: FittedBox(
                fit: BoxFit.cover,
                child: CollabShareCard(
                  listing: listing,
                  publisherAvatar: _networkAvatar(listing.publisher.avatarUrl),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (!supportsDirectTargets)
          SizedBox(
            width: double.infinity,
            child: _ShareChoice(
              key: const Key('collab-share-generic'),
              label: 'Paylaş',
              icon: const Icon(
                Icons.ios_share_rounded,
                size: 20,
                color: Colors.white,
              ),
              colors: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              onTap: () => Navigator.pop(context, CollabShareTarget.other),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _ShareChoice(
                  key: const Key('collab-share-instagram'),
                  label: 'Instagram\nHikâyesi',
                  icon: const FaIcon(
                    FontAwesomeIcons.instagram,
                    size: 19,
                    color: Colors.white,
                  ),
                  colors: const [
                    Color(0xFFF58529),
                    Color(0xFFDD2A7B),
                    Color(0xFF8134AF),
                  ],
                  onTap: () =>
                      Navigator.pop(context, CollabShareTarget.instagramStory),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShareChoice(
                  key: const Key('collab-share-whatsapp'),
                  label: 'WhatsApp',
                  icon: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    size: 19,
                    color: Colors.white,
                  ),
                  colors: const [Color(0xFF25D366), Color(0xFF128C7E)],
                  onTap: () =>
                      Navigator.pop(context, CollabShareTarget.whatsapp),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShareChoice(
                  key: const Key('collab-share-other'),
                  label: 'Diğer',
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  colors: const [Color(0xFF596579), Color(0xFF343D4D)],
                  onTap: () => Navigator.pop(context, CollabShareTarget.other),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

ImageProvider? _networkAvatar(String? url) {
  final normalized = url?.trim();
  return normalized == null || normalized.isEmpty
      ? null
      : NetworkImage(normalized);
}

class _ShareChoice extends StatelessWidget {
  const _ShareChoice({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
    super.key,
  });

  final String label;
  final Widget icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: colors),
            ),
            child: icon,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}
