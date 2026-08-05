part of 'studio_profile_screen.dart';

class _StudioRoomsPanel extends StatefulWidget {
  final String profileId;
  final bool canReserve;
  final bool ownerMode;
  final String timeZone;
  final int contentRevision;

  const _StudioRoomsPanel({
    required this.profileId,
    required this.timeZone,
    required this.contentRevision,
    this.canReserve = false,
    this.ownerMode = false,
  });

  @override
  State<_StudioRoomsPanel> createState() => _StudioRoomsPanelState();
}

class _StudioRoomsPanelState extends State<_StudioRoomsPanel> {
  final StudioRoomRepository _repository =
      serviceLocator<StudioRoomRepository>();
  List<_StudioRoomItem> _rooms = const [];
  bool _loading = true;
  String? _errorMessage;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void didUpdateWidget(covariant _StudioRoomsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId ||
        oldWidget.ownerMode != widget.ownerMode ||
        oldWidget.timeZone != widget.timeZone ||
        oldWidget.contentRevision != widget.contentRevision) {
      _loadRooms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _StudioPanel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Stüdyo Odaları',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _StudioRoomLimitPill(count: _rooms.length),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  'Prova, kayıt ve vokal çalışmaları için uygun alanlar',
                  style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                _StudioRoomsErrorState(
                  message: _errorMessage!,
                  onRetry: _loadRooms,
                )
              else if (_rooms.isEmpty)
                _StudioRoomsEmptyState(
                  ownerMode: widget.ownerMode,
                  ownerTabMode: widget.ownerMode,
                  onCreateRoom: widget.ownerMode ? _createRoom : null,
                )
              else
                ..._rooms.map(
                  (room) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StudioRoomCard(
                      room: room,
                      profileId: widget.profileId,
                      canReserve: widget.canReserve,
                      ownerMode: widget.ownerMode,
                      onRoomUpdated: (_) => _reloadRoomsAndProfile(),
                      onRoomDeleted: _reloadRoomsAndProfile,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadRooms() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    final result = widget.ownerMode
        ? await _repository.listOwnerRooms(size: _maximumStudioRoomCount)
        : await _repository.listPublicRooms(
            widget.profileId,
            size: _maximumStudioRoomCount,
          );
    if (!mounted || generation != _loadGeneration) return;
    final page = result.data;
    if (!result.isSuccess || page == null) {
      setState(() {
        _loading = false;
        _errorMessage = result.error?.message ?? 'Odalar getirilemedi.';
      });
      return;
    }
    setState(() {
      _rooms = page.items
          .map(
            (room) =>
                _StudioRoomItem.fromDomain(room, timeZone: widget.timeZone),
          )
          .toList(growable: false);
      _loading = false;
      _errorMessage = null;
    });
  }

  Future<void> _createRoom() async {
    if (_rooms.length >= _maximumStudioRoomCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En fazla 10 oda oluşturabilirsin.')),
      );
      return;
    }
    final room = await showModalBottomSheet<_StudioRoomItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewStudioRoomSheet(
        repository: _repository,
        studioProfileId: widget.profileId,
      ),
    );
    if (!mounted || room == null) return;
    await _reloadRoomsAndProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${room.name} oluşturuldu.')));
  }

  Future<void> _reloadRoomsAndProfile() async {
    await _loadRooms();
    if (!mounted || !widget.ownerMode) return;
    await context.read<StudioProfileCubit>().loadMyProfile();
  }
}

class _StudioRoomsErrorState extends StatelessWidget {
  const _StudioRoomsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFF9EA8B7)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB5BDCA), fontSize: 12),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomLimitPill extends StatelessWidget {
  final int count;

  const _StudioRoomLimitPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Text(
        '$count / 10',
        style: const TextStyle(
          color: Color(0xFFB5BDCA),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StudioRoomCard extends StatelessWidget {
  final _StudioRoomItem room;
  final String profileId;
  final bool canReserve;
  final bool ownerMode;
  final ValueChanged<_StudioRoomItem>? onRoomUpdated;
  final VoidCallback? onRoomDeleted;

  const _StudioRoomCard({
    required this.room,
    required this.profileId,
    required this.canReserve,
    required this.ownerMode,
    this.onRoomUpdated,
    this.onRoomDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => ownerMode ? _openSettings(context) : _openRoom(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF101722),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF202B3A)),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StudioRoomPhoto(room: room),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              room.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (ownerMode)
                            _StudioRoomReservationSummaryPill(
                              count: room.reservationCount,
                            )
                          else
                            _StudioRoomStatusPill(room: room),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (room.type.trim().isNotEmpty)
                        Text(
                          room.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFB5BDCA),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: _StudioRoomMeta(
                              icon: Icons.people_outline,
                              label: room.capacity,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StudioRoomMeta(
                              icon: Icons.payments_outlined,
                              label: room.price,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!ownerMode) ...[
              const SizedBox(height: 9),
              Align(
                alignment: Alignment.centerLeft,
                child: _StudioRoomApprovalStatusPill(
                  approvalRequired: room.reservationApprovalRequired,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final feature in room.features)
                    _StudioRoomFeatureChip(label: feature),
                ],
              ),
            ),
            if (ownerMode) ...[
              const SizedBox(height: 10),
              _StudioRoomSettingsButton(onTap: () => _openSettings(context)),
            ] else if (canReserve) ...[
              const SizedBox(height: 10),
              _StudioActionButton(
                icon: Icons.event_available_outlined,
                label: 'Rezervasyon Yap',
                outlined: true,
                onTap: () => _openRoom(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openRoom(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StudioRoomDetailScreen(
          room: room,
          studioProfileId: profileId,
          canReserve: canReserve,
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    final result = await Navigator.of(context).push<_StudioRoomSettingsResult>(
      MaterialPageRoute<_StudioRoomSettingsResult>(
        builder: (_) =>
            _StudioRoomSettingsScreen(room: room, studioProfileId: profileId),
      ),
    );
    if (result == null) return;
    if (result.deleted) {
      onRoomDeleted?.call();
      return;
    }
    final updatedRoom = result.updatedRoom;
    if (updatedRoom != null) onRoomUpdated?.call(updatedRoom);
  }
}

class _StudioRoomApprovalStatusPill extends StatelessWidget {
  const _StudioRoomApprovalStatusPill({required this.approvalRequired});

  final bool approvalRequired;

  @override
  Widget build(BuildContext context) {
    final color = approvalRequired
        ? const Color(0xFFE7B85C)
        : const Color(0xFF67D6A1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            approvalRequired ? Icons.approval_outlined : Icons.bolt_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            approvalRequired ? 'Stüdyo onayı gerekir' : 'Anında rezervasyon',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomSettingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StudioRoomSettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _StudioActionButton(
      icon: Icons.settings_outlined,
      label: 'Oda Ayarları',
      outlined: true,
      onTap: onTap,
    );
  }
}

class _StudioRoomPhoto extends StatelessWidget {
  final _StudioRoomItem room;

  const _StudioRoomPhoto({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 86,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: room.gradient,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2B3546)),
      ),
      child: Stack(
        children: [
          if (room.photoUrls.isNotEmpty)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: AppCachedNetworkImage(
                  imageUrl: room.photoUrls.first,
                  fit: BoxFit.cover,
                  cacheWidth: 276,
                  cacheHeight: 258,
                  errorBuilder: (_) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (room.photoUrls.isNotEmpty)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          Positioned(
            right: -18,
            bottom: -20,
            child: Icon(
              room.icon,
              size: 78,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Icon(room.icon, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomStatusPill extends StatelessWidget {
  final _StudioRoomItem room;

  const _StudioRoomStatusPill({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: room.statusColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: room.statusColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        room.status,
        style: TextStyle(
          color: room.statusColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StudioRoomReservationSummaryPill extends StatelessWidget {
  final int count;

  const _StudioRoomReservationSummaryPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final hasReservations = count > 0;
    final color = hasReservations
        ? const Color(0xFF67D6A1)
        : const Color(0xFF9AA4B2);
    return Container(
      constraints: const BoxConstraints(maxWidth: 142),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasReservations
                ? Icons.event_available_outlined
                : Icons.event_busy_outlined,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              hasReservations ? '$count rezervasyon' : 'Henüz rezervasyon yok',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StudioRoomMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StudioSocialGradientIcon(icon, size: 14),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD5DBE5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudioRoomFeatureChip extends StatelessWidget {
  final String label;

  const _StudioRoomFeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0A101A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFB5BDCA),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StudioRoomItem {
  final String id;
  final String studioProfileId;
  final int slotIndex;
  final String name;
  final String type;
  final int capacityCount;
  final int minimumCapacityCount;
  final int? hourlyPriceMinor;
  final String? currency;
  final String status;
  final Color statusColor;
  final IconData icon;
  final List<Color> gradient;
  final List<String> features;
  final List<StudioRoomPhoto> photos;
  final int reservationCount;
  final int reservedHours;
  final bool reservationApprovalRequired;
  final bool? pendingReservationApprovalRequired;
  final DateTime? reservationApprovalPolicyEffectiveAt;
  final DateTime todayLocalDate;
  final String timeZone;
  final int version;

  const _StudioRoomItem({
    required this.id,
    required this.studioProfileId,
    required this.slotIndex,
    required this.name,
    required this.type,
    required this.capacityCount,
    required this.minimumCapacityCount,
    required this.hourlyPriceMinor,
    required this.currency,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.gradient,
    required this.features,
    this.photos = const [],
    this.reservationCount = 0,
    this.reservedHours = 0,
    this.reservationApprovalRequired = true,
    this.pendingReservationApprovalRequired,
    this.reservationApprovalPolicyEffectiveAt,
    required this.todayLocalDate,
    required this.timeZone,
    required this.version,
  });

  factory _StudioRoomItem.fromDomain(
    StudioRoom room, {
    String timeZone = 'Europe/Istanbul',
  }) {
    final visual = _roomVisual(room.name, room.slotIndex);
    final (status, statusColor) = switch (room.todayAvailabilityStatus) {
      StudioRoomAvailabilityStatus.fullyBooked => (
        'Dolu',
        const Color(0xFFCF5E69),
      ),
      StudioRoomAvailabilityStatus.partiallyAvailable => (
        'Kısmen Müsait',
        const Color(0xFFB17400),
      ),
      StudioRoomAvailabilityStatus.available => (
        'Müsait',
        const Color(0xFF0E8F2F),
      ),
    };
    return _StudioRoomItem(
      id: room.id,
      studioProfileId: room.studioProfileId,
      slotIndex: room.slotIndex,
      name: room.name,
      type: room.shortDescription,
      capacityCount: room.capacity,
      minimumCapacityCount: room.minimumCapacity ?? room.capacity,
      hourlyPriceMinor: room.hourlyPriceMinor,
      currency: room.currency,
      status: status,
      statusColor: statusColor,
      icon: visual.$1,
      gradient: visual.$2,
      features: room.features,
      photos: room.photos,
      reservationCount: room.todayReservationCount,
      reservedHours: room.todayOccupiedHours,
      reservationApprovalRequired: room.reservationApprovalRequired,
      pendingReservationApprovalRequired:
          room.pendingReservationApprovalRequired,
      reservationApprovalPolicyEffectiveAt:
          room.reservationApprovalPolicyEffectiveAt,
      todayLocalDate: room.todayLocalDate,
      timeZone: timeZone,
      version: room.version,
    );
  }

  String get capacity => minimumCapacityCount == capacityCount
      ? '$capacityCount kişi'
      : '$minimumCapacityCount-$capacityCount kişi';

  String get price {
    final minor = hourlyPriceMinor;
    if (minor == null) return 'Fiyat belirtilmedi';
    final whole = minor ~/ 100;
    final fraction = minor.remainder(100);
    final grouped = whole.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final amount = fraction == 0
        ? grouped
        : '$grouped,${fraction.toString().padLeft(2, '0')}';
    final symbol = currency == 'TRY' || currency == null ? '₺' : '$currency ';
    return '$symbol$amount / saat';
  }

  List<String> get photoUrls => photos.map((photo) => photo.url).toList();

  List<String> get photoMediaIds => photos
      .map((photo) => photo.mediaAssetId?.trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

  static (IconData, List<Color>) _roomVisual(String name, int slotIndex) {
    final normalized = name.toLowerCase();
    final icon = normalized.contains('kayıt') || normalized.contains('kayit')
        ? Icons.graphic_eq
        : normalized.contains('vokal') || normalized.contains('podcast')
        ? Icons.mic_none_outlined
        : normalized.contains('prova')
        ? Icons.groups_2_outlined
        : Icons.meeting_room_outlined;
    const gradients = <List<Color>>[
      [Color(0xFF1C2B3F), Color(0xFF4B2D52)],
      [Color(0xFF172A3A), Color(0xFF3B2747)],
      [Color(0xFF1E2538), Color(0xFF563040)],
    ];
    return (icon, gradients[slotIndex.abs() % gradients.length]);
  }
}
