import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/widgets/event_poster_fallback.dart';
import '../../domain/entities/venue_event_detail.dart';

/// The discovery card's visual language, sized for a listener's post. This is
/// intentionally independent of the geographic discovery screen and its state.
class ListenerEventPostCard extends StatelessWidget {
  const ListenerEventPostCard({
    super.key,
    required this.event,
    required this.username,
    required this.intentLabel,
    required this.onOpen,
    required this.onIntent,
    this.avatarUrl,
    this.note,
    this.owner = false,
    this.visibilityLabel,
    this.onShare,
    this.onComments,
    this.onLike,
    this.isLiked = false,
    this.likeBusy = false,
    this.isParticipating = false,
    this.intentBusy = false,
    this.likeCount,
    this.commentCount,
    this.onDelete,
    this.onChangeIntent,
    this.onEditNote,
    this.ended = false,
    this.noteEditor,
    this.actions,
  });

  final VenueEventDetail event;
  final String username;
  final String? avatarUrl;
  final String intentLabel;
  final String? note;
  final bool owner;

  final bool ended;
  final String? visibilityLabel;
  final VoidCallback? onOpen;
  final VoidCallback? onIntent;
  final VoidCallback? onShare;
  final VoidCallback? onComments;
  final VoidCallback? onLike;
  final bool isLiked;
  final bool likeBusy;
  final bool isParticipating;
  final bool intentBusy;

  /// Null represents an unread count, rather than an empty interaction list.
  final int? likeCount;
  final int? commentCount;
  final VoidCallback? onDelete;
  final VoidCallback? onChangeIntent;
  final VoidCallback? onEditNote;

  /// Draft-only slots; published cards keep their existing note and actions.
  final Widget? noteEditor;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final location = [event.venueDistrict, event.venueCity]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' · ');
    final title = event.title?.trim() ?? '';
    final performer = event.performerName?.trim() ?? '';
    final message = note?.trim() ?? '';
    final isDraft = noteEditor != null || actions != null;
    final showLike = onLike != null || likeBusy || likeCount != null || isLiked;
    final handle = username.trim().replaceFirst(RegExp(r'^@+'), '');
    final status = isDraft
        ? intentLabel
        : _participationLabel(intentLabel, ended: ended);
    return Container(
      key: ValueKey('listener-event-post-${event.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipOval(
                child: AppCachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  errorBuilder: (_) => Container(
                    width: 38,
                    height: 38,
                    color: const Color(0xFF202238),
                    child: const Icon(Icons.person_outline_rounded, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDraft || handle.isEmpty ? username : '@$handle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        status,
                        if (visibilityLabel != null) visibilityLabel!,
                      ].join(' · '),
                      style: const TextStyle(
                        color: Color(0xFFA0A9B6),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (owner &&
                  !isDraft &&
                  (onDelete != null ||
                      onChangeIntent != null ||
                      onEditNote != null))
                PopupMenuButton<String>(
                  key: ValueKey('listener-event-menu-${event.id}'),
                  tooltip: 'Paylaşım seçenekleri',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 180),
                  icon: const Icon(Icons.more_horiz_rounded, size: 19),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    maximumSize: const Size(48, 48),
                    foregroundColor: const Color(0xFFA0A9B6),
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case 'intent':
                        onChangeIntent?.call();
                      case 'note':
                        onEditNote?.call();
                      case 'delete':
                        onDelete?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    if (onChangeIntent != null)
                      PopupMenuItem(
                        value: 'intent',
                        child: Text(
                          intentLabel == 'Düşünüyorum'
                              ? 'Gidiyorum olarak değiştir'
                              : 'Düşünüyorum olarak değiştir',
                        ),
                      ),
                    if (onEditNote != null)
                      const PopupMenuItem(
                        value: 'note',
                        child: Text('Açıklamayı düzenle'),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Paylaşımı sil'),
                      ),
                  ],
                ),
            ],
          ),
          if (noteEditor != null) ...[
            const SizedBox(height: 12),
            noteEditor!,
          ] else if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PostNote(note: message),
          ],
          const SizedBox(height: 12),
          Material(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('listener-event-open-${event.id}'),
              onTap: onOpen,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: textScale > 1.4 ? 122 : 102,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppCachedNetworkImage(
                            imageUrl: event.posterImage,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                            errorBuilder: (_) =>
                                EventPosterFallback(title: title),
                          ),
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 9,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.navBlueDeep.withValues(
                                    alpha: .94,
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  _scheduleLabel(event),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title.isEmpty ? 'Etkinlik' : title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (onOpen != null) ...[
                                const SizedBox(width: 8),
                                const ExcludeSemantics(
                                  child: BrandGradientIcon.social(
                                    Icons.chevron_right_rounded,
                                    size: 22,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          _MetadataLine(
                            icon: Icons.music_note_rounded,
                            label: performer.isEmpty
                                ? 'Belirtilmemiş'
                                : performer,
                          ),
                          const SizedBox(height: 8),
                          _MetadataLine(
                            icon: Icons.location_on_outlined,
                            label: event.venueName?.trim().isNotEmpty == true
                                ? event.venueName!.trim()
                                : 'Mekan bilgisi paylaşılmadı',
                          ),
                          if (location.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 23),
                              child: Text(
                                location,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFA0A9B6),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height:
                !owner && (onIntent != null || intentBusy) && actions == null
                ? 2
                : 8,
          ),
          actions ??
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (owner)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            ended
                                ? Icons.history_rounded
                                : intentLabel == 'Gidiyorum'
                                ? Icons.check_circle_outline_rounded
                                : Icons.event_outlined,
                            color: AppColors.socialPink,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _ownerParticipationLabel(intentLabel, ended),
                              key: ValueKey(
                                'listener-event-owner-status-${event.id}',
                              ),
                              style: const TextStyle(
                                color: Color(0xFFA0A9B6),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (onIntent != null || intentBusy)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _PostAction(
                        key: ValueKey('listener-event-intent-${event.id}'),
                        onPressed: onIntent,
                        foregroundColor: AppColors.socialPink,
                        icon: isParticipating
                            ? Icons.check_circle_outline_rounded
                            : Icons.event_available_outlined,
                        label: isParticipating
                            ? 'Bu etkinliğe katılıyorsun!'
                            : 'Ben de gidiyorum',
                        compact: true,
                      ),
                    ),
                  if (showLike || onComments != null || onShare != null) ...[
                    const Divider(color: Color(0xFF202B3A), height: 1),
                    _PostEngagementActions(
                      like: showLike
                          ? _PostCountAction(
                              key: ValueKey('listener-event-like-${event.id}'),
                              icon: isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              label: isLiked ? 'Beğenmekten vazgeç' : 'Beğen',
                              count: likeCount,
                              countLabel: 'beğeni',
                              selected: isLiked,
                              color: isLiked ? AppColors.socialPink : null,
                              onPressed: likeBusy ? null : onLike,
                            )
                          : null,
                      comments: onComments == null
                          ? null
                          : _PostCountAction(
                              key: ValueKey(
                                'listener-event-comments-${event.id}',
                              ),
                              icon: Icons.chat_bubble_outline_rounded,
                              label: 'Yorumlar',
                              count: commentCount,
                              countLabel: 'yorum',
                              onPressed: onComments,
                            ),
                      share: onShare == null
                          ? null
                          : _PostIconAction(
                              key: ValueKey('listener-event-share-${event.id}'),
                              icon: Icons.send_outlined,
                              label: 'Paylaş',
                              onPressed: onShare!,
                            ),
                    ),
                  ],
                ],
              ),
        ],
      ),
    );
  }
}

class _PostEngagementActions extends StatelessWidget {
  const _PostEngagementActions({this.like, this.comments, this.share});

  final Widget? like;
  final Widget? comments;
  final Widget? share;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final counters = [
        if (like != null) like!,
        if (comments != null) comments!,
      ];
      if (MediaQuery.textScalerOf(context).scale(1) > 1.35 ||
          constraints.maxWidth < 300) {
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 18,
          children: [...counters, if (share != null) share!],
        );
      }
      final counterWidth =
          (constraints.maxWidth -
              (share == null ? 0 : 48) -
              (counters.length > 1 ? 18 : 0)) /
          (counters.isEmpty ? 1 : counters.length);
      return Row(
        children: [
          for (var index = 0; index < counters.length; index++) ...[
            if (index > 0) const SizedBox(width: 18),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: counterWidth),
              child: counters[index],
            ),
          ],
          const Spacer(),
          if (share != null) share!,
        ],
      );
    },
  );
}

class _PostCountAction extends StatelessWidget {
  const _PostCountAction({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.countLabel,
    required this.onPressed,
    this.selected,
    this.color,
  });

  final IconData icon;
  final String label;
  final int? count;
  final String countLabel;
  final VoidCallback? onPressed;
  final bool? selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? const Color(0xFFA0A9B6);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: label,
      value: count == null ? null : '$count $countLabel',
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: resolvedColor, size: 18),
                      if (count != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '$count',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: resolvedColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostIconAction extends StatelessWidget {
  const _PostIconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    icon: Icon(icon, color: const Color(0xFFA0A9B6), size: 19),
  );
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.foregroundColor = const Color(0xFFCED4DF),
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final bool compact;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: Size(48, compact ? 32 : 48),
      tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 6,
        vertical: compact ? 4 : 10,
      ),
      foregroundColor: foregroundColor,
      textStyle: compact
          ? Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12)
          : null,
    ),
    child: Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: compact ? 16 : 18),
        SizedBox(width: compact ? 6 : 7),
        Flexible(
          child: Text(
            label,
            textAlign: compact ? TextAlign.left : TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

String _participationLabel(String intentLabel, {required bool ended}) =>
    switch (intentLabel) {
      'Gidiyorum' =>
        ended ? 'Bu etkinliğe gitmeyi planlamıştı.' : 'Bu etkinliğe gidiyor.',
      'Düşünüyorum' =>
        ended
            ? 'Bu etkinliğe katılmayı düşünüyordu.'
            : 'Bu etkinliğe katılmayı düşünüyor.',
      _ => ended ? 'Geçmiş plan · $intentLabel' : intentLabel,
    };

String _ownerParticipationLabel(String intentLabel, bool ended) =>
    switch (intentLabel) {
      'Gidiyorum' =>
        ended
            ? 'Bu etkinliğe katılmayı planlamıştın.'
            : 'Bu etkinliğe katılıyorsun!',
      'Düşünüyorum' =>
        ended
            ? 'Bu etkinliğe katılmayı düşünüyordun.'
            : 'Bu etkinliğe katılmayı düşünüyorsun.',
      _ => ended ? 'Geçmiş planın' : intentLabel,
    };

class _PostNote extends StatefulWidget {
  const _PostNote({required this.note});
  final String note;

  @override
  State<_PostNote> createState() => _PostNoteState();
}

class _PostNoteState extends State<_PostNote> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _PostNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note != widget.note) _expanded = false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = DefaultTextStyle.of(
        context,
      ).style.copyWith(color: Colors.white, fontSize: 14, height: 1.6);
      final painter = TextPainter(
        text: TextSpan(text: widget.note, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 3,
      )..layout(maxWidth: constraints.maxWidth);
      final needsExpansion = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.note,
            style: style,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (needsExpansion)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('listener-event-note-expand'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  foregroundColor: const Color(0xFFA0A9B6),
                  textStyle: style.copyWith(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Daha az göster' : 'Notun tamamını oku',
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BrandGradientIcon.social(icon, size: 16),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

String _scheduleLabel(VenueEventDetail event) {
  final date = event.eventDate;
  final dateLabel = date == null
      ? ''
      : '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.${date.year}';
  String time(String? value) {
    final match = RegExp(r'^\d{2}:\d{2}').firstMatch(value ?? '');
    return match?.group(0) ?? '';
  }

  final times = [
    time(event.startTime),
    time(event.endTime),
  ].where((value) => value.isNotEmpty).join(' – ');
  return [dateLabel, times].where((value) => value.isNotEmpty).join(' · ');
}
