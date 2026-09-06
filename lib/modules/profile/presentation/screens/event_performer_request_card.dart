import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/event_poster_fallback.dart';
import '../../domain/entities/event_performer_request.dart';
import 'event_performer_request_copy.dart';
import 'event_calendar_visibility_help.dart';

class EventPerformerRequestCard extends StatelessWidget {
  final EventPerformerRequest request;
  final bool processing;
  final bool showOnProfile;
  final ValueChanged<bool>? onShowOnProfileChanged;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool reconsider;
  final bool expired;
  final bool decisionAllowed;
  final bool interactionLocked;

  const EventPerformerRequestCard({
    super.key,
    required this.request,
    required this.processing,
    this.showOnProfile = false,
    this.onShowOnProfileChanged,
    required this.onAccept,
    required this.onReject,
    this.reconsider = false,
    this.expired = false,
    this.decisionAllowed = true,
    this.interactionLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final canInteract = !processing && !interactionLocked && decisionAllowed;
    final canAccept = canInteract && request.profileCalendarApproved != null;
    return Semantics(
      container: true,
      label:
          '${request.venueName}, ${request.eventTitle}, '
          '${request.targetType.label}, ${request.purposeLabel}, ${_scheduleLabel(request)}',
      child: Container(
        key: Key('event-approval-card-${request.requestId}'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.surfaceContainerHighest, scheme.surface],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RequestPoster(request: request),
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.brandGradient
                      .map((c) => c.withValues(alpha: 0.65))
                      .toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _VenueAvatar(request: request),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.venueName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              request.purposeLabel,
                              style: TextStyle(
                                color: muted,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RequestDateBadge(date: request.eventDate),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.eventTitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 23,
                                height: 1.18,
                                letterSpacing: -0.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 15,
                                  color: muted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _timeLabel(),
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${request.performerName} • ${request.targetType.label}',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandGradient[1].withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          reconsider
                              ? 'Reddedildi'
                              : expired
                              ? 'Süresi doldu'
                              : 'Onay bekliyor',
                          style: TextStyle(
                            color: AppColors.brandGradient[1],
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    key: Key('event-request-permissions-${request.requestId}'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RequestPermissionLine(
                          icon:
                              request.requestPurpose ==
                                  EventPerformerRequestPurpose.profileVisibility
                              ? Icons.visibility_outlined
                              : Icons.link_rounded,
                          text: !decisionAllowed
                              ? expired
                                    ? 'Etkinlik başladığı için bu davet artık yanıtlanamaz.'
                                    : 'Davetin güncel durumu doğrulanamadı. Listeyi yenile.'
                              : request.purposeExplanation,
                        ),
                        if (decisionAllowed &&
                            request.requestPurpose ==
                                EventPerformerRequestPurpose
                                    .performerConsent) ...[
                          const SizedBox(height: 12),
                          Material(
                            color: showOnProfile
                                ? AppColors.brandGradient.last.withValues(
                                    alpha: .08,
                                  )
                                : scheme.surfaceContainerHighest.withValues(
                                    alpha: .5,
                                  ),
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: CheckboxTheme(
                              data: CheckboxTheme.of(
                                context,
                              ).copyWith(visualDensity: VisualDensity.compact),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: CheckboxListTile(
                                      key: Key(
                                        'show-on-profile-event-request-${request.requestId}',
                                      ),
                                      value: showOnProfile,
                                      onChanged:
                                          !canAccept ||
                                              onShowOnProfileChanged == null
                                          ? null
                                          : (value) => onShowOnProfileChanged!(
                                              value == true,
                                            ),
                                      contentPadding: EdgeInsets.zero,
                                      minLeadingWidth: 0,
                                      horizontalTitleGap: 8,
                                      minTileHeight: 48,
                                      minVerticalPadding: 8,
                                      visualDensity: VisualDensity.standard,
                                      titleAlignment:
                                          ListTileTitleAlignment.center,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      activeColor: AppColors.brandGradient.last,
                                      checkColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      title: Text(
                                        request.targetType ==
                                                EventPerformerTargetType.band
                                            ? 'Bu etkinliği grubun profilinde de göster'
                                            : 'Bu etkinliği profilimde de göster',
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  EventCalendarVisibilityHelp(
                                    request: request,
                                    enabled: canInteract,
                                    iconOnly: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (decisionAllowed &&
                            request.requestPurpose ==
                                EventPerformerRequestPurpose
                                    .profileVisibility) ...[
                          const SizedBox(height: 4),
                          EventCalendarVisibilityHelp(
                            request: request,
                            enabled: canInteract,
                          ),
                        ],
                        if (request.profileCalendarApproved == null) ...[
                          const SizedBox(height: 10),
                          _RequestPermissionLine(
                            icon: Icons.info_outline_rounded,
                            text: request.incompatibleApprovalExplanation,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (decisionAllowed) ...[
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked =
                            constraints.maxWidth < 280 ||
                            MediaQuery.textScalerOf(context).scale(14) > 18;
                        final rejectButton = OutlinedButton(
                          key: Key('reject-event-request-${request.requestId}'),
                          onPressed: canInteract ? onReject : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: const Size(48, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Reddet'),
                        );
                        final acceptButton = Semantics(
                          button: true,
                          enabled: canAccept,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: GradientOutlineButton(
                              key: Key(
                                'accept-event-request-${request.requestId}',
                              ),
                              onPressed: canAccept ? onAccept : null,
                              label: 'Onayla',
                              loading: processing,
                              strokeWidth: 0.8,
                              horizontalPadding: 16,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        );
                        if (reconsider) return acceptButton;
                        if (stacked) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              acceptButton,
                              const SizedBox(height: 10),
                              rejectButton,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: rejectButton),
                            const SizedBox(width: 10),
                            Expanded(child: acceptButton),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel() {
    final start = _shortTime(request.startTime);
    final end = _shortTime(request.endTime);
    if (start == null) return 'Saat belirtilmedi';
    return end == null ? start : '$start – $end';
  }

  String _scheduleLabel(EventPerformerRequest request) {
    final date = request.eventDate;
    final dateLabel = date == null
        ? 'Tarih belirtilmedi'
        : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final start = _shortTime(request.startTime);
    final end = _shortTime(request.endTime);
    if (start == null) return dateLabel;
    return '$dateLabel • ${end == null ? start : '$start – $end'}';
  }

  String? _shortTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return value;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }
}

class _RequestPoster extends StatelessWidget {
  const _RequestPoster({required this.request});

  final EventPerformerRequest request;

  @override
  Widget build(BuildContext context) {
    final fallback = EventPosterFallback(title: request.eventTitle);
    final raw = request.posterImage?.trim() ?? '';
    final uri = Uri.tryParse(raw);
    final valid =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return Semantics(
      image: true,
      label: '${request.eventTitle} için etkinlik afişi',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = (constraints.maxWidth * 9 / 16).clamp(0.0, 200.0);
            final pixels =
                (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                    .round()
                    .clamp(1, 1024);
            return SizedBox(
              key: Key('event-request-poster-${request.requestId}'),
              height: height,
              child: !valid
                  ? fallback
                  : AppCachedNetworkImage(
                      imageUrl: raw,
                      width: constraints.maxWidth,
                      height: height,
                      fit: BoxFit.cover,
                      cacheWidth: pixels,
                      // A single decode dimension preserves portrait posters;
                      // BoxFit.cover crops the banner without stretching it.
                      placeholderBuilder: (_) => fallback,
                      errorBuilder: (_) => fallback,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _RequestDateBadge extends StatelessWidget {
  const _RequestDateBadge({required this.date});

  final DateTime? date;
  static const months = [
    'OCA',
    'ŞUB',
    'MAR',
    'NİS',
    'MAY',
    'HAZ',
    'TEM',
    'AĞU',
    'EYL',
    'EKİ',
    'KAS',
    'ARA',
  ];

  @override
  Widget build(BuildContext context) {
    final value = date;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: value == null
          ? Icon(Icons.event_outlined, color: scheme.onSurfaceVariant)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.day}',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  months[value.month - 1],
                  style: TextStyle(
                    color: AppColors.brandGradient[1],
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${value.year}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 9),
                ),
              ],
            ),
    );
  }
}

class _RequestPermissionLine extends StatelessWidget {
  const _RequestPermissionLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: AppColors.brandGradient.last),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _VenueAvatar extends StatelessWidget {
  final EventPerformerRequest request;

  const _VenueAvatar({required this.request});

  @override
  Widget build(BuildContext context) {
    final imageUrl = request.venueProfilePictureUrl?.trim() ?? '';
    return ClipOval(
      child: Container(
        width: 46,
        height: 46,
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: imageUrl.isEmpty
            ? Icon(Icons.storefront_outlined, color: AppColors.coralAlt)
            : AppCachedNetworkImage(
                imageUrl: imageUrl,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                cacheWidth: (46 * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_) =>
                    Icon(Icons.storefront_outlined, color: AppColors.coralAlt),
              ),
      ),
    );
  }
}
