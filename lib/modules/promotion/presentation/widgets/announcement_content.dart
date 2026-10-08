import 'package:flutter/material.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../domain/entities/announcement.dart';
import 'announcement_media.dart';

/// Shared content for the real feed card, directory, detail and admin preview.
class AnnouncementContent extends StatelessWidget {
  const AnnouncementContent({
    super.key,
    required this.announcement,
    this.expanded = false,
    this.showDirectory = true,
    this.onOpen,
    this.onPlay,
    this.showOpenButton = true,
    this.showIdentity = true,
  });
  final Announcement announcement;
  final bool expanded;
  final bool showDirectory;
  final VoidCallback? onOpen;
  final VoidCallback? onPlay;
  final bool showOpenButton;

  /// The feed already identifies SoundConnect in its disclosure row.
  final bool showIdentity;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showIdentity) ...[
        const Row(
          children: [
            BrandGradientIcon(Icons.campaign_rounded, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'SoundConnect',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      Text(
        announcement.title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        announcement.body,
        maxLines: expanded ? null : 4,
        overflow: expanded ? null : TextOverflow.ellipsis,
        style: const TextStyle(height: 1.5),
      ),
      if (announcement.media case final media?) ...[
        const SizedBox(height: 14),
        AnnouncementMediaView(media: media, onPlay: onPlay ?? onOpen),
      ],
      if (!expanded && showOpenButton && onOpen != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: onOpen,
            child: const Text('Duyuruyu aç'),
          ),
        ),
      if (showDirectory)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.announcements),
            icon: const Icon(Icons.view_list_outlined, size: 18),
            label: const Text('Tüm duyurular'),
          ),
        ),
    ],
  );
}
