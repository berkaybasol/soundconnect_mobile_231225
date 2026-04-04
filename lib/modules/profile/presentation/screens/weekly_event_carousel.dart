import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/entities/venue_event_detail.dart';
import '../../domain/venue_event_repository.dart';
import 'weekly_event_detail_screen.dart';

bool _isNetworkImage(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return false;
  final uri = Uri.tryParse(raw);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

bool _isAssetImage(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return false;
  return raw.startsWith('assets/');
}

class WeeklyEventCarousel extends StatelessWidget {
  final List<WeeklyCalendarEvent> items;
  final EdgeInsetsGeometry padding;
  final bool compactTitle;

  const WeeklyEventCarousel({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.compactTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 88,
          child: Center(
            child: Text(
              'Bu hafta icin etkinlik bulunamadi.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: compactTitle ? 244 : 256,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final event = items[index];
          return _WeeklyEventCard(
            event: event,
            compactTitle: compactTitle,
          );
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navBlueSoft, AppColors.inputFill],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
    );
  }
}

class _WeeklyEventCard extends StatefulWidget {
  final WeeklyCalendarEvent event;
  final bool compactTitle;

  const _WeeklyEventCard({
    required this.event,
    required this.compactTitle,
  });

  @override
  State<_WeeklyEventCard> createState() => _WeeklyEventCardState();
}

class _WeeklyEventCardState extends State<_WeeklyEventCard> {
  static final Map<String, String?> _resolvedPosterCache = <String, String?>{};
  static final Map<String, String?> _resolvedArtistCache = <String, String?>{};
  static final Map<String, VenueEventDetail> _eventPayloadCache =
      <String, VenueEventDetail>{};

  Future<String?>? _posterFuture;
  Future<String>? _artistFuture;

  @override
  void initState() {
    super.initState();
    _posterFuture = _resolvePosterImage();
    _artistFuture = _resolveArtistName();
  }

  Future<String?> _resolvePosterImage() async {
    final raw = widget.event.imageAssetPath?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (_isNetworkImage(raw) || _isAssetImage(raw)) return raw;

    final cached = _resolvedPosterCache[widget.event.id];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    try {
      final payload = await _loadEventPayload();
      final poster = payload.posterImage?.trim();
      if (poster == null || poster.isEmpty) return null;
      _resolvedPosterCache[widget.event.id] = poster;
      return poster;
    } catch (_) {
      return null;
    }
  }

  String _fallbackArtistName() {
    final raw = widget.event.artistName.trim();
    if (raw.isEmpty) return 'Sanatci';
    final normalized = raw.toLowerCase();
    if (normalized == 'performer') return 'Sanatci';
    return raw;
  }

  String _displayTimeLabel() {
    final raw = widget.event.startTime.trim();
    if (raw.isEmpty) return '-';
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final hour = parts[0].padLeft(2, '0');
      final minute = parts[1].padLeft(2, '0');
      return '$hour:$minute';
    }
    return raw;
  }

  Future<String> _resolveArtistName() async {
    final fallback = _fallbackArtistName();
    String? profileId = widget.event.artistProfileId?.trim();

    VenueEventDetail? payload;
    if (profileId == null || profileId.isEmpty || fallback == 'Sanatci') {
      try {
        payload = await _loadEventPayload();
        final payloadProfileId = payload.musicianProfileId?.trim();
        if (payloadProfileId != null && payloadProfileId.isNotEmpty) {
          profileId = payloadProfileId;
        }
      } catch (_) {
        // Payload fallback sessizce yoksayilir.
      }
    }

    if (profileId == null || profileId.isEmpty) {
      final payloadPerformer = payload?.performerName?.trim();
      if (payloadPerformer != null &&
          payloadPerformer.isNotEmpty &&
          payloadPerformer.toLowerCase() != 'performer') {
        return payloadPerformer;
      }
      return fallback;
    }

    final cached = _resolvedArtistCache[profileId];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    try {
      final repository = serviceLocator<MusicianProfileRepository>();
      final result = await repository.getPublicProfileByProfileId(profileId);
      final username = result.data?.username?.trim();
      if (username != null && username.isNotEmpty) {
        final resolved = username;
        _resolvedArtistCache[profileId] = resolved;
        return resolved;
      }
    } catch (_) {
      // Fallback mevcut event ismine donecek.
    }

    final payloadPerformer = payload?.performerName?.trim();
    if (payloadPerformer != null &&
        payloadPerformer.isNotEmpty &&
        payloadPerformer.toLowerCase() != 'performer') {
      return payloadPerformer;
    }

    return fallback;
  }

  Future<VenueEventDetail> _loadEventPayload() async {
    final cached = _eventPayloadCache[widget.event.id];
    if (cached != null) {
      return cached;
    }

    final repository = serviceLocator<VenueEventRepository>();
    final result = await repository.getDetail(widget.event.id);
    final payload =
        result.data ??
        VenueEventDetail(
          id: widget.event.id,
          shareUrl: null,
          posterImage: null,
          performerName: null,
          musicianProfileId: null,
        );
    _eventPayloadCache[widget.event.id] = payload;
    return payload;
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final compactTitle = widget.compactTitle;
    final timeLabel = _displayTimeLabel();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      splashColor: AppColors.coral.withValues(alpha: 0.22),
      highlightColor: Colors.white.withValues(alpha: 0.05),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WeeklyEventDetailScreen(event: event),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: compactTitle ? 162 : 174,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            color: AppColors.inputFill,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: compactTitle ? 118 : 128,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: FutureBuilder<String?>(
                        future: _posterFuture,
                        builder: (context, snapshot) {
                          final resolved = snapshot.data?.trim();
                          if (resolved == null || resolved.isEmpty) {
                            return WeeklyEventCarousel(
                              items: const [],
                            )._placeholder();
                          }
                          if (_isNetworkImage(resolved)) {
                            return Image.network(
                              resolved,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  WeeklyEventCarousel(
                                    items: const [],
                                  )._placeholder(),
                            );
                          }
                          if (_isAssetImage(resolved)) {
                            return Image.asset(
                              resolved,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  WeeklyEventCarousel(
                                    items: const [],
                                  )._placeholder(),
                            );
                          }
                          return WeeklyEventCarousel(
                            items: const [],
                          )._placeholder();
                        },
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.navBlueDeep.withValues(alpha: 0.86),
                              AppColors.navBlueDeep.withValues(alpha: 0.54),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          event.eventDate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compactTitle ? 10 : 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compactTitle ? 10 : 12,
                  compactTitle ? 8 : 9,
                  compactTitle ? 10 : 12,
                  compactTitle ? 8 : 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: compactTitle ? 13 : 14,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: compactTitle ? 5 : 7),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: compactTitle ? 10 : 12,
                        vertical: compactTitle ? 6 : 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navBlueSoft.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: FutureBuilder<String>(
                              future: _artistFuture,
                              builder: (context, snapshot) {
                                final artistName =
                                    snapshot.data?.trim().isNotEmpty == true
                                    ? snapshot.data!.trim()
                                    : _fallbackArtistName();
                                return Text(
                                  artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: compactTitle ? 11 : 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compactTitle ? 6 : 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compactTitle ? 10 : 12,
                        vertical: compactTitle ? 5 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              return const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: AppColors.brandGradient,
                              ).createShader(bounds);
                            },
                            child: const Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              timeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: compactTitle ? 11 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
