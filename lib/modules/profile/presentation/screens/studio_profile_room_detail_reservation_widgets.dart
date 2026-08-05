part of 'studio_profile_screen.dart';

class _StudioOwnerReservationTimeline extends StatelessWidget {
  final List<String> times;
  final List<_StudioOwnerReservation> reservations;
  final List<_StudioManualBusyRange> manualBusyRanges;
  final bool Function(String time) isTimeAvailable;
  final bool Function(String time) canEditTime;
  final ValueChanged<_StudioOwnerReservation> onReservationTap;
  final ValueChanged<int> onEmptyTimeTap;
  final ValueChanged<_StudioManualBusyRange> onManualBusyTap;

  const _StudioOwnerReservationTimeline({
    required this.times,
    required this.reservations,
    required this.manualBusyRanges,
    required this.isTimeAvailable,
    required this.canEditTime,
    required this.onReservationTap,
    required this.onEmptyTimeTap,
    required this.onManualBusyTap,
  });

  static const _columns = 4;
  static const _gap = 8.0;
  static const _tileHeight = 65.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - (_gap * 3)) / _columns;
        final rowCount = (times.length / _columns).ceil();
        final timelineHeight =
            (rowCount * _tileHeight) + ((rowCount - 1) * _gap);
        return SizedBox(
          height: timelineHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < times.length; index++)
                Positioned(
                  left: (index % _columns) * (tileWidth + _gap),
                  top: (index ~/ _columns) * (_tileHeight + _gap),
                  width: tileWidth,
                  height: _tileHeight,
                  child: Builder(
                    builder: (context) {
                      final matchingReservations = _reservationsAt(index);
                      final manualBusyRange = _manualBusyRangeAt(index);
                      if (manualBusyRange != null) {
                        final startLabel = _manualHourLabel(
                          manualBusyRange.startIndex,
                        ).substring(0, 2);
                        final endLabel = _manualHourLabel(
                          manualBusyRange.endIndex,
                        ).substring(0, 2);
                        return _StudioRoomTimeChip(
                          time: times[index],
                          available: false,
                          selected: false,
                          width: tileWidth,
                          verticalPadding: 0,
                          accentColor: _studioManualBusyColor,
                          statusLabel: 'Dolu · $startLabel–$endLabel',
                          statusColor: _studioManualBusyColor,
                          statusFontSize: 8,
                          onTap: () => onManualBusyTap(manualBusyRange),
                        );
                      }
                      final available =
                          matchingReservations.isEmpty &&
                          isTimeAvailable(times[index]);
                      final editable = available && canEditTime(times[index]);
                      return _StudioOwnerReservationTimeTile(
                        time: times[index],
                        available: available,
                        editable: editable,
                        width: tileWidth,
                        reservations: matchingReservations,
                        onTap: matchingReservations.isEmpty
                            ? editable
                                  ? () => onEmptyTimeTap(index)
                                  : null
                            : () => _openReservationsForTime(
                                context,
                                times[index],
                                matchingReservations,
                              ),
                      );
                    },
                  ),
                ),
              Positioned(
                left: 2 * (tileWidth + _gap),
                top: 3 * (_tileHeight + _gap),
                child: _StudioRoomBrandTile(width: (tileWidth * 2) + _gap),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_StudioOwnerReservation> _reservationsAt(int index) {
    return reservations
        .where(
          (reservation) =>
              index >= reservation.startIndex &&
              index < reservation.startIndex + reservation.durationHours,
        )
        .toList(growable: false);
  }

  _StudioManualBusyRange? _manualBusyRangeAt(int index) {
    for (final range in manualBusyRanges) {
      if (range.contains(index)) return range;
    }
    return null;
  }

  Future<void> _openReservationsForTime(
    BuildContext context,
    String time,
    List<_StudioOwnerReservation> matchingReservations,
  ) async {
    if (matchingReservations.length == 1) {
      onReservationTap(matchingReservations.first);
      return;
    }
    final selected = await showModalBottomSheet<_StudioOwnerReservation>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StudioReservationsAtTimeSheet(
        time: time,
        reservations: matchingReservations,
      ),
    );
    if (selected != null) onReservationTap(selected);
  }
}

class _StudioOwnerReservationTimeTile extends StatelessWidget {
  final String time;
  final bool available;
  final bool editable;
  final double width;
  final List<_StudioOwnerReservation> reservations;
  final VoidCallback? onTap;

  const _StudioOwnerReservationTimeTile({
    required this.time,
    required this.available,
    required this.editable,
    required this.width,
    required this.reservations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty && available && !editable) {
      return _StudioRoomTimeChip(
        time: time,
        available: false,
        selected: false,
        width: width,
        verticalPadding: 0,
        statusLabel: 'Geçti',
        statusColor: const Color(0xFF6F7A8B),
        onTap: null,
      );
    }
    final accentColor = reservations.isEmpty
        ? null
        : reservations.every((reservation) => reservation.approved)
        ? _studioReservationApprovedColor
        : reservations.every((reservation) => !reservation.approved)
        ? _studioReservationPendingColor
        : _studioReservationApprovedColor;
    final statusLabel = reservations.isEmpty
        ? null
        : reservations.length == 1
        ? '${_initials(reservations.first.userName)} · ${_range(reservations.first)}'
        : '${reservations.length} talep';
    return Stack(
      fit: StackFit.expand,
      children: [
        _StudioRoomTimeChip(
          time: time,
          available: available,
          selected: false,
          width: width,
          verticalPadding: 0,
          accentColor: accentColor,
          statusLabel: statusLabel,
          statusColor: accentColor,
          statusFontSize: reservations.length == 1 ? 8 : 9,
          onTap: onTap,
        ),
        if (reservations.length > 1) ...[
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF17202D),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF59677A)),
              ),
              child: Text(
                '${reservations.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: 5,
            height: 3,
            child: Row(
              children: [
                for (var index = 0; index < reservations.length; index++) ...[
                  if (index > 0) const SizedBox(width: 3),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: reservations[index].approved
                            ? _studioReservationApprovedColor
                            : _studioReservationPendingColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _range(_StudioOwnerReservation reservation) {
    final start = 9 + reservation.startIndex;
    final end = start + reservation.durationHours;
    return '${start.toString().padLeft(2, '0')}–${end.toString().padLeft(2, '0')}';
  }

  String _initials(String name) {
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
  }
}

Future<DmProfileTarget?> _resolveStudioReservationGuestTarget(
  _StudioOwnerReservation reservation,
) async {
  final userId = reservation.userId.trim();
  if (userId.isEmpty) return null;
  final targets = await serviceLocator<DmUserProfileResolver>().resolveByUserId(
    userId: userId,
    usernameHint: reservation.userName,
  );
  for (final target in targets) {
    if (dmProfileRouteFor(target) != null) return target;
  }
  return null;
}

class _StudioReservationsAtTimeSheet extends StatelessWidget {
  final String time;
  final List<_StudioOwnerReservation> reservations;

  const _StudioReservationsAtTimeSheet({
    required this.time,
    required this.reservations,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: const BoxDecoration(
          color: Color(0xFF0E1622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0xFF2A3546))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF465267),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '$time Saatindeki Rezervasyonlar',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${reservations.length} farklı rezervasyon bu saatle çakışıyor.',
              style: const TextStyle(color: Color(0xFF9EA8B7), fontSize: 11),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < reservations.length; index++) ...[
              _StudioReservationPickerTile(
                reservation: reservations[index],
                onTap: () => Navigator.of(context).pop(reservations[index]),
              ),
              if (index < reservations.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudioReservationPickerTile extends StatefulWidget {
  final _StudioOwnerReservation reservation;
  final VoidCallback onTap;

  const _StudioReservationPickerTile({
    required this.reservation,
    required this.onTap,
  });

  @override
  State<_StudioReservationPickerTile> createState() =>
      _StudioReservationPickerTileState();
}

class _StudioReservationPickerTileState
    extends State<_StudioReservationPickerTile> {
  late Future<DmProfileTarget?> _profileTarget;

  @override
  void initState() {
    super.initState();
    _profileTarget = _resolveProfileTarget();
  }

  @override
  void didUpdateWidget(covariant _StudioReservationPickerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reservation.userId != widget.reservation.userId) {
      _profileTarget = _resolveProfileTarget();
    }
  }

  Future<DmProfileTarget?> _resolveProfileTarget() =>
      _resolveStudioReservationGuestTarget(widget.reservation);

  @override
  Widget build(BuildContext context) {
    final reservation = widget.reservation;
    final color = reservation.approved
        ? _studioReservationApprovedColor
        : _studioReservationPendingColor;
    final startHour = 9 + reservation.startIndex;
    final endHour = startHour + reservation.durationHours;
    return Material(
      color: const Color(0xFF101A28),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.42)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: FutureBuilder<DmProfileTarget?>(
                  future: _profileTarget,
                  builder: (context, snapshot) => _StudioReservationAvatar(
                    reservation: reservation,
                    onTap: widget.onTap,
                    avatarUrlOverride: snapshot.data?.imageUrl,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${startHour.toString().padLeft(2, '0')}:00–${endHour.toString().padLeft(2, '0')}:00 • ${reservation.durationHours} saat',
                      style: const TextStyle(
                        color: Color(0xFF9EA8B7),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                reservation.approved ? 'Onaylı' : 'Bekliyor',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8F99A9),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioReservationAvatar extends StatelessWidget {
  final _StudioOwnerReservation reservation;
  final VoidCallback? onTap;
  final String? avatarUrlOverride;

  const _StudioReservationAvatar({
    required this.reservation,
    required this.onTap,
    this.avatarUrlOverride,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAvatarUrl = avatarUrlOverride?.trim().isNotEmpty == true
        ? avatarUrlOverride!.trim()
        : reservation.avatarUrl.trim();
    final capabilities = reservation.capabilities;
    final statusColor = capabilities.hasMutation
        ? reservation.approved
              ? _studioReservationApprovedColor
              : _studioReservationPendingColor
        : const Color(0xFF9EA8B7);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.28),
            blurRadius: 11,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF101722),
        shape: CircleBorder(
          side: BorderSide(color: statusColor.withValues(alpha: 0.9), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: resolvedAvatarUrl.isEmpty
                  ? _StudioReservationAvatarFallback(
                      userName: reservation.userName,
                    )
                  : AppCachedNetworkImage(
                      imageUrl: resolvedAvatarUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 156,
                      cacheHeight: 156,
                      errorBuilder: (_) => _StudioReservationAvatarFallback(
                        userName: reservation.userName,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioReservationAvatarFallback extends StatelessWidget {
  const _StudioReservationAvatarFallback({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final normalized = userName.trim();
    return ColoredBox(
      color: const Color(0xFF252E3D),
      child: Center(
        child: Text(
          normalized.isEmpty ? '?' : normalized.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StudioRoomTimeChip extends StatelessWidget {
  final String time;
  final bool available;
  final bool selected;
  final double width;
  final double verticalPadding;
  final Color? accentColor;
  final String? statusLabel;
  final Color? statusColor;
  final double statusFontSize;
  final VoidCallback? onTap;

  const _StudioRoomTimeChip({
    required this.time,
    required this.available,
    required this.selected,
    this.width = 72,
    this.verticalPadding = 10,
    this.accentColor,
    this.statusLabel,
    this.statusColor,
    this.statusFontSize = 9,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: width,
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2A172A)
              : available
              ? const Color(0xFF0A101A)
              : const Color(0xFF090D14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                accentColor?.withValues(alpha: 0.82) ??
                (selected
                    ? AppColors.socialPink
                    : available
                    ? const Color(0xFF263244)
                    : const Color(0xFF1A2230)),
          ),
          boxShadow: accentColor == null
              ? null
              : [
                  BoxShadow(
                    color: accentColor!.withValues(alpha: 0.16),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              time,
              style: TextStyle(
                color: accentColor != null
                    ? Colors.white
                    : available
                    ? Colors.white
                    : const Color(0xFF596271),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              statusLabel ?? (available ? 'Müsait' : 'Dolu'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    statusColor ??
                    (available
                        ? const Color(0xFF1EAF4D)
                        : const Color(0xFF7D4248)),
                fontSize: statusFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioRoomBrandTile extends StatelessWidget {
  final double width;

  const _StudioRoomBrandTile({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 65,
      decoration: BoxDecoration(
        color: const Color(0xFF090F18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRect(
            child: Image.asset(
              'assets/logotransparent.png',
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioManualBusySheet extends StatefulWidget {
  final String roomName;
  final DateTime date;
  final int startIndex;
  final List<int> endOptions;

  const _StudioManualBusySheet({
    required this.roomName,
    required this.date,
    required this.startIndex,
    required this.endOptions,
  });

  @override
  State<_StudioManualBusySheet> createState() => _StudioManualBusySheetState();
}

class _StudioManualBusySheetState extends State<_StudioManualBusySheet> {
  late int _selectedEndIndex;

  @override
  void initState() {
    super.initState();
    _selectedEndIndex = widget.endOptions.first;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: const BoxDecoration(
          color: Color(0xFF0E1622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0xFF2A3546))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF465267),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Dolu Olarak İşaretle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${widget.roomName} • ${_studioReservationDateLabel(widget.date)}',
              style: const TextStyle(color: Color(0xFF9EA8B7), fontSize: 11),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF101A28),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFF263244)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Başlangıç',
                    style: TextStyle(color: Color(0xFF8F99A9), fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    _manualHourLabel(widget.startIndex),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bitiş Saatini Seç',
              style: TextStyle(
                color: Color(0xFFCDD3DE),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final endIndex in widget.endOptions)
                  _StudioManualEndTimeChip(
                    label: _manualHourLabel(endIndex),
                    selected: _selectedEndIndex == endIndex,
                    onTap: () => setState(() => _selectedEndIndex = endIndex),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppColors.brandGradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(_selectedEndIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.block_outlined, size: 18),
                label: const Text(
                  'Dolu Olarak İşaretle',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
