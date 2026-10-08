part of 'guest_event_home_screen.dart';

class _EventCard extends StatelessWidget {
  final DiscoveryEvent item;

  const _EventCard({required this.item});

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatTime(TimeOfDay time) =>
      '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';

  String _timeLabel() {
    final start = item.startTime == null ? null : _formatTime(item.startTime!);
    final end = item.endTime == null ? null : _formatTime(item.endTime!);
    if (start == null && end == null) return '--:--';
    if (start != null && end == null) return start;
    if (start == null && end != null) return end;
    return '$start - $end';
  }

  bool _isNetworkImage(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String _dateLabel() {
    final date = item.eventDate;
    if (date == null) {
      return '-';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final location = [
      item.venueDistrict ?? '',
      item.venueNeighborhood ?? '',
    ].where((e) => e.trim().isNotEmpty).join(' / ');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      // DiscoveryEvent exposes only a consent-safe linked performer identity.
      onTap: () => _openDetail(context),
      child: Container(
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0x40F07A5E), Color(0x20E062A9), Color(0x409A58F4)],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer,
                    backgroundImage: _isNetworkImage(item.venueImageUrl)
                        ? NetworkImage(item.venueImageUrl!)
                        : null,
                    child: _isNetworkImage(item.venueImageUrl)
                        ? null
                        : Text(
                            item.venueName.trim().isEmpty
                                ? '?'
                                : item.venueName.trim()[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.venueName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          location.isEmpty ? '-' : location,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: AppColors.decorativeGradient,
                      ),
                    ),
                    child: Text(
                      _timeLabel(),
                      style: TextStyle(
                        color: AppColors.decorativeForeground,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer,
                    backgroundImage: _isNetworkImage(item.performerImageUrl)
                        ? NetworkImage(item.performerImageUrl!)
                        : null,
                    child: _isNetworkImage(item.performerImageUrl)
                        ? null
                        : Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.performerName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'Detaylar için tıkla',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (item.description.trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
              if (item.bandMembers.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.bandMembers
                      .map(
                        (member) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Text(
                            member,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestEmptyState extends StatelessWidget {
  const _GuestEmptyState();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_off,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                'Bu filtrede etkinlik yok.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Farklı şehir, ilçe, mahalle veya mekan seçerek tekrar dene.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchFirstState extends StatelessWidget {
  const _SearchFirstState();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                'Henüz bir konum seçmedin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Yakındaki canlı müzik mekanlarını görmek için konumunu seçip arama yap.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredLoadingState extends StatelessWidget {
  const _CenteredLoadingState();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _ErrorState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestLockFooter extends StatelessWidget {
  _GuestLockFooter();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.navBlueDeep,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.login);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side: BorderSide(color: Theme.of(context).dividerColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Giriş Yap'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GuestAccessActionButton(
              label: 'Üye Ol',
              backgroundColor: AppColors.navBlueDeep,
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.register);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestTableAccessFab extends StatefulWidget {
  final Future<void> Function() onTap;
  final ValueChanged<Offset> onDragDelta;
  final bool showHint;
  final String hintText;

  const _GuestTableAccessFab({
    required this.onTap,
    required this.onDragDelta,
    this.showHint = true,
    this.hintText = 'Masa açmak için\ndokunun',
  });

  @override
  State<_GuestTableAccessFab> createState() => _GuestTableAccessFabState();
}

class _GuestTableAccessFabState extends State<_GuestTableAccessFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final bool _disablePulseForTest;

  @override
  void initState() {
    super.initState();
    _disablePulseForTest = Platform.environment.containsKey('FLUTTER_TEST');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    if (_disablePulseForTest) {
      _scale = const AlwaysStoppedAnimation<double>(1.0);
    } else {
      _scale = Tween<double>(
        begin: 0.98,
        end: 1.03,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: (details) => widget.onDragDelta(details.delta),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showHint)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.pureBlack.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.hintText,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            GradientOutline(
              enabled: AppColors.isLight,
              radius: 999,
              child: Container(
                width: 72,
                height: 72,
                decoration: AppColors.isLight
                    ? BoxDecoration(
                        color: AppColors.navBlue,
                        shape: BoxShape.circle,
                      )
                    : BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppColors.decorativeGradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.decorativeGradient.last.withValues(
                              alpha: 0.42,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                child: Icon(
                  Icons.groups_2_rounded,
                  color: AppColors.decorativeForeground,
                  size: 34,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
