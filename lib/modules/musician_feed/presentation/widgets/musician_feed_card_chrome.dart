import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../domain/musician_feed_models.dart';
import 'musician_feed_card_registry.dart';

class MusicianFeedSurface extends StatelessWidget {
  const MusicianFeedSurface({
    super.key,
    required this.item,
    required this.actions,
    required this.child,
    this.onTap,
    this.showAuthor = true,
    this.contentPadding = const EdgeInsets.fromLTRB(14, 13, 14, 10),
  });

  final MusicianFeedItem item;
  final MusicianFeedCardActions actions;
  final Widget child;
  final VoidCallback? onTap;
  final bool showAuthor;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MusicianFeedReasonRow(
            item: item,
            actions: actions,
            showOverflow: !showAuthor,
          ),
          Padding(
            padding: contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showAuthor && item.author != null) ...[
                  MusicianFeedAuthorHeader(
                    author: item.author!,
                    occurredAt: item.occurredAt,
                    onTap: () => actions.openAuthor(item, item.author!),
                    onOverflow: () => showMusicianFeedActions(
                      context,
                      item: item,
                      actions: actions,
                    ),
                  ),
                  const SizedBox(height: 13),
                ],
                child,
                if (item.engagement != null) ...[
                  const SizedBox(height: 12),
                  MusicianFeedEngagementBar(item: item, actions: actions),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return surface;
    return Semantics(
      button: true,
      label: _semanticLabel(item),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: surface),
      ),
    );
  }

  String _semanticLabel(MusicianFeedItem item) {
    final author = item.author?.displayName;
    final disclosure = item.promotion == null
        ? null
        : musicianFeedPromotionDisclosureLabel(item.promotion!.disclosure);
    final kind = switch (item.type) {
      MusicianFeedItemType.track => 'müzik kaydı',
      MusicianFeedItemType.profileMedia => 'medya paylaşımı',
      MusicianFeedItemType.collab => 'Collab ilanı',
      MusicianFeedItemType.event ||
      MusicianFeedItemType.eventProfileShare => 'etkinlik',
      MusicianFeedItemType.overthinkingProfileShare =>
        'Overthinking profil paylaşımı',
      MusicianFeedItemType.tableGroupProfileShare => 'masa profil paylaşımı',
      MusicianFeedItemType.profile => 'profil önerisi',
      MusicianFeedItemType.profileCompletion => 'profil tamamlama önerisi',
      MusicianFeedItemType.sponsored => 'sponsorlu içerik',
      _ => 'sosyal aktivite',
    };
    final content = author == null ? kind : '$author tarafından $kind';
    return disclosure == null ? content : '$disclosure, $content';
  }
}

class MusicianFeedReasonRow extends StatelessWidget {
  const MusicianFeedReasonRow({
    super.key,
    required this.item,
    required this.actions,
    this.showOverflow = false,
  });

  final MusicianFeedItem item;
  final MusicianFeedCardActions actions;
  final bool showOverflow;

  @override
  Widget build(BuildContext context) {
    final promotion = item.promotion;
    final label = promotion == null
        ? musicianFeedReasonLabel(item.reason)
        : musicianFeedPromotionDisclosureLabel(promotion.disclosure);
    final icon = promotion == null
        ? _reasonIcon(item.reason.code)
        : _promotionDisclosureIcon(promotion.disclosure);
    final canHide = item.feedbackCapabilities.contains(
      MusicianFeedFeedbackAction.hide,
    );
    final hasMenu =
        showOverflow &&
        (item.feedbackCapabilities.contains(
              MusicianFeedFeedbackAction.showLess,
            ) ||
            item.feedbackCapabilities.contains(
              MusicianFeedFeedbackAction.report,
            ) ||
            musicianFeedAuthorProfileIdentity(item.author) != null);
    if (label == null && !canHide && !hasMenu) {
      return const SizedBox.shrink();
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: .72),
          ),
        ),
      ),
      child: Row(
        children: [
          if (label != null) ...[
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (hasMenu)
            IconButton(
              onPressed: () => showMusicianFeedActions(
                context,
                item: item,
                actions: actions,
              ),
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              tooltip: 'Kart seçenekleri',
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
            ),
          if (canHide)
            IconButton(
              onPressed: () =>
                  actions.feedback(item, MusicianFeedFeedbackAction.hide),
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Bu kartı gizle',
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

class MusicianFeedAuthorHeader extends StatelessWidget {
  const MusicianFeedAuthorHeader({
    super.key,
    required this.author,
    required this.occurredAt,
    required this.onTap,
    required this.onOverflow,
  });

  final MusicianFeedActor author;
  final DateTime occurredAt;
  final VoidCallback onTap;
  final VoidCallback onOverflow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: '${author.displayName} profilini aç',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.navBlueSoft,
              child: ClipOval(
                child: AppCachedNetworkImage(
                  imageUrl: author.avatarUrl,
                  width: 44,
                  height: 44,
                  cacheWidth: 132,
                  cacheHeight: 132,
                  placeholderBuilder: (_) => _AuthorFallback(author: author),
                  errorBuilder: (_) => _AuthorFallback(author: author),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_profileTypeLabel(author.profileType)} · ${musicianFeedRelativeTime(occurredAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onOverflow,
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'Kart seçenekleri',
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        ),
      ],
    );
  }
}

class MusicianFeedEngagementBar extends StatelessWidget {
  const MusicianFeedEngagementBar({
    super.key,
    required this.item,
    required this.actions,
  });

  final MusicianFeedItem item;
  final MusicianFeedCardActions actions;

  @override
  Widget build(BuildContext context) {
    final engagement = item.engagement!;
    return Column(
      children: [
        if (engagement.likeCount > 0 || engagement.commentCount > 0) ...[
          Row(
            children: [
              if (engagement.likeCount > 0) ...[
                Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: AppColors.likeHeart,
                ),
                const SizedBox(width: 5),
                Text('${engagement.likeCount}', style: _metadataStyle(context)),
              ],
              const Spacer(),
              if (engagement.commentCount > 0)
                Text(
                  '${engagement.commentCount} yorum',
                  style: _metadataStyle(context),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          const SizedBox(height: 2),
        ],
        Row(
          children: [
            if (engagement.likable)
              Expanded(
                child: _FeedActionButton(
                  icon: engagement.likedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: engagement.likedByMe ? 'Beğendin' : 'Beğen',
                  color: engagement.likedByMe ? AppColors.likeHeart : null,
                  onPressed: () => actions.toggleLike(item),
                ),
              ),
            if (engagement.commentable)
              Expanded(
                child: _FeedActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Yorum',
                  onPressed: () => actions.openComments(item),
                ),
              ),
            Expanded(
              child: _FeedActionButton(
                icon: Icons.open_in_new_rounded,
                label: 'Aç',
                onPressed: () => actions.openItem(item),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle _metadataStyle(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
  );
}

class _FeedActionButton extends StatelessWidget {
  const _FeedActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    return SizedBox(
      height: stacked ? 68 : 44,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: stacked ? 2 : 6),
        ),
        child: stacked
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19, color: foreground),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19, color: foreground),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

Future<void> showMusicianFeedActions(
  BuildContext context, {
  required MusicianFeedItem item,
  required MusicianFeedCardActions actions,
}) async {
  final author = item.author;
  final selected = await showModalBottomSheet<_FeedMenuAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.navBlue,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.feedbackCapabilities.contains(
              MusicianFeedFeedbackAction.showLess,
            ))
              ListTile(
                minTileHeight: 48,
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Bunun gibi daha az göster'),
                onTap: () =>
                    Navigator.pop(sheetContext, _FeedMenuAction.showLess),
              ),
            if (musicianFeedAuthorProfileIdentity(author) != null)
              ListTile(
                minTileHeight: 48,
                leading: const Icon(Icons.volume_off_outlined),
                title: Text('${author!.displayName} paylaşımlarını sessize al'),
                onTap: () => Navigator.pop(sheetContext, _FeedMenuAction.mute),
              ),
            if (item.feedbackCapabilities.contains(
              MusicianFeedFeedbackAction.report,
            ))
              ListTile(
                minTileHeight: 48,
                leading: Icon(
                  Icons.flag_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Bildir'),
                onTap: () =>
                    Navigator.pop(sheetContext, _FeedMenuAction.report),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || selected == null) return;
  switch (selected) {
    case _FeedMenuAction.showLess:
      actions.feedback(item, MusicianFeedFeedbackAction.showLess);
      break;
    case _FeedMenuAction.mute:
      if (author != null) actions.muteAuthor(item, author);
      break;
    case _FeedMenuAction.report:
      actions.feedback(item, MusicianFeedFeedbackAction.report);
      break;
  }
}

String? musicianFeedReasonLabel(MusicianFeedReason reason) {
  final actor = reason.actors.isEmpty ? null : reason.actors.first.displayName;
  final others = reason.secondaryActorCount;
  final actorWithOthers = actor == null
      ? null
      : others > 0
      ? '$actor ve $others kişi daha'
      : actor;
  return switch (reason.code) {
    'FOLLOWING_PUBLICATION' => 'Takip ettiğin bir profil paylaştı',
    'FOLLOWED_USER_COMMENTED' || 'FOLLOWING_COMMENTED' =>
      '${actorWithOthers ?? 'Takip ettiğin biri'} yorum yaptı',
    'FOLLOWED_USER_LIKED' || 'FOLLOWING_LIKED' =>
      '${actorWithOthers ?? 'Takip ettiğin biri'} bunu beğendi',
    'FOLLOWED_USER_FOLLOWED' || 'FOLLOWING_FOLLOWED' =>
      '${actorWithOthers ?? 'Takip ettiğin biri'} bu profili takip ediyor',
    'CITY_AND_INSTRUMENT_MATCH' => 'Şehrin ve enstrümanınla eşleşiyor',
    'CITY_MATCH' => 'Fırsat görmek istediğin şehirde',
    'INSTRUMENT_MATCH' => 'Enstrümanınla eşleşiyor',
    'DISCOVERY' => 'Senin için keşfedildi',
    'PROFILE_INCOMPLETE' ||
    'PROFILE_COMPLETION' => 'Akışını sana göre şekillendir',
    'SPONSORED' => 'Sponsorlu',
    'FEATURED' => 'Öne Çıkan',
    'PLATFORM_ANNOUNCEMENT' => 'SoundConnect duyurusu',
    _ => null,
  };
}

String musicianFeedPromotionDisclosureLabel(String disclosure) {
  return switch (disclosure.trim().toUpperCase()) {
    'FEATURED' => 'Öne Çıkan',
    'PLATFORM_ANNOUNCEMENT' => 'SoundConnect duyurusu',
    'SPONSORED' => 'Sponsorlu',
    // Promotion metadata is authoritative. Unknown additive disclosure types
    // must remain visibly disclosed instead of falling back to a native
    // discovery/following reason.
    _ => 'Sponsorlu',
  };
}

String musicianFeedRelativeTime(DateTime value, {DateTime? now}) {
  final difference = (now ?? DateTime.now().toUtc()).difference(value.toUtc());
  if (difference.isNegative || difference.inSeconds < 45) return 'şimdi';
  if (difference.inMinutes < 60) return '${difference.inMinutes} dk';
  if (difference.inHours < 24) return '${difference.inHours} sa';
  if (difference.inDays < 7) return '${difference.inDays} gün';
  if (difference.inDays < 30) return '${difference.inDays ~/ 7} hf';
  if (difference.inDays < 365) return '${difference.inDays ~/ 30} ay';
  return '${difference.inDays ~/ 365} yıl';
}

IconData _reasonIcon(String code) => switch (code) {
  'FOLLOWED_USER_COMMENTED' ||
  'FOLLOWING_COMMENTED' => Icons.chat_bubble_outline_rounded,
  'FOLLOWED_USER_LIKED' || 'FOLLOWING_LIKED' => Icons.favorite_border_rounded,
  'FOLLOWED_USER_FOLLOWED' ||
  'FOLLOWING_FOLLOWED' => Icons.person_add_alt_1_rounded,
  'CITY_AND_INSTRUMENT_MATCH' || 'CITY_MATCH' => Icons.location_on_outlined,
  'INSTRUMENT_MATCH' => Icons.music_note_rounded,
  'PROFILE_INCOMPLETE' || 'PROFILE_COMPLETION' => Icons.auto_awesome_rounded,
  'SPONSORED' => Icons.campaign_outlined,
  'FEATURED' => Icons.workspace_premium_outlined,
  _ => Icons.people_alt_outlined,
};

IconData _promotionDisclosureIcon(String disclosure) =>
    switch (disclosure.trim().toUpperCase()) {
      'FEATURED' => Icons.workspace_premium_outlined,
      'PLATFORM_ANNOUNCEMENT' => Icons.notifications_active_outlined,
      _ => Icons.campaign_outlined,
    };

String _profileTypeLabel(String value) => switch (value.toUpperCase()) {
  'MUSICIAN' => 'Müzisyen',
  'BAND' => 'Grup',
  'VENUE' => 'Mekân',
  'STUDIO' => 'Stüdyo',
  'LISTENER' => 'Dinleyici',
  _ => 'SoundConnect',
};

class _AuthorFallback extends StatelessWidget {
  const _AuthorFallback({required this.author});
  final MusicianFeedActor author;

  @override
  Widget build(BuildContext context) {
    final initial = author.displayName.trim().isEmpty
        ? null
        : author.displayName.trim().characters.first.toUpperCase();
    return ColoredBox(
      color: AppColors.navBlueSoft,
      child: Center(
        child: initial == null
            ? const BrandGradientIcon.social(Icons.person_outline_rounded)
            : Text(
                initial,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
      ),
    );
  }
}

enum _FeedMenuAction { showLess, mute, report }
