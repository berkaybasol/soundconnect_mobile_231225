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
    final status = ended ? 'Geçmiş plan · $intentLabel' : intentLabel;
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
            children: [
              ClipOval(
                child: AppCachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_) => Container(
                    width: 32,
                    height: 32,
                    color: const Color(0xFF202238),
                    child: const Icon(Icons.person_outline_rounded, size: 19),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
                      ),
                    ),
                  ],
                ),
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
          const SizedBox(height: 4),
          actions ??
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (onIntent != null)
                    TextButton.icon(
                      key: ValueKey('listener-event-intent-${event.id}'),
                      onPressed: onIntent,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        foregroundColor: AppColors.socialPink,
                      ),
                      icon: Icon(
                        owner
                            ? Icons.tune_rounded
                            : Icons.event_available_outlined,
                        size: 18,
                      ),
                      label: Text(
                        owner ? 'Planımı düzenle' : 'Ben de gidiyorum',
                      ),
                    ),
                  if (onOpen != null)
                    IconButton(
                      key: ValueKey('listener-event-comments-${event.id}'),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: onOpen,
                      tooltip: 'Etkinlik yorumları',
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 19,
                      ),
                    ),
                  if (onShare != null)
                    IconButton(
                      key: ValueKey('listener-event-share-${event.id}'),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: onShare,
                      tooltip: 'Etkinliği paylaş',
                      icon: const Icon(Icons.send_outlined, size: 19),
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

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
      const style = TextStyle(fontSize: 12, height: 1.4);
      final painter = TextPainter(
        text: TextSpan(
          text: widget.note,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
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
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('listener-event-note-expand'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
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
