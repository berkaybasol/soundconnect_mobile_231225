part of 'weekly_event_carousel.dart';

class _WeeklyEventCard extends StatefulWidget {
  final WeeklyCalendarEvent event;
  final bool compactTitle;

  _WeeklyEventCard({required this.event, required this.compactTitle});

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

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final compactTitle = widget.compactTitle;
    final timeLabel = _displayTimeLabel();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      splashColor: AppColors.coral.withValues(alpha: 0.22),
      highlightColor: AppColors.white.withValues(alpha: 0.05),
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
            border: Border.all(color: Theme.of(context).dividerColor),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            boxShadow: [
              BoxShadow(
                color: AppColors.pureBlack.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: Offset(0, 8),
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
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: FutureBuilder<String?>(
                        future: _posterFuture,
                        builder: (context, snapshot) {
                          final resolved = snapshot.data?.trim();
                          if (resolved == null || resolved.isEmpty) {
                            return WeeklyEventCarousel(
                              items: [],
                            )._placeholder(context);
                          }
                          if (_isNetworkImage(resolved)) {
                            return AppCachedNetworkImage(
                              imageUrl: resolved,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context) => WeeklyEventCarousel(
                                items: [],
                              )._placeholder(context),
                            );
                          }
                          if (_isAssetImage(resolved)) {
                            return Image.asset(
                              resolved,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => WeeklyEventCarousel(
                                items: [],
                              )._placeholder(context),
                            );
                          }
                          return WeeklyEventCarousel(
                            items: [],
                          )._placeholder(context);
                        },
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.pureBlack.withValues(alpha: 0.08),
                            AppColors.pureBlack.withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                            color: AppColors.white,
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
                        color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainer.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.7),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
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
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: AppColors.brandGradient,
                              ).createShader(bounds);
                            },
                            child: Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: AppColors.white,
                            ),
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              timeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
