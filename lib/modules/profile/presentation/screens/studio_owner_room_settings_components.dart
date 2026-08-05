part of 'studio_profile_screen.dart';

class _StudioRoomDeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StudioRoomDeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF7B88),
          side: const BorderSide(color: Color(0xFF7D3541)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.delete_outline_rounded, size: 19),
        label: const Text(
          'Odayı Sil',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}

class _StudioRoomSettingsPhotoSection extends StatefulWidget {
  final _StudioRoomItem? room;
  final List<StudioRoomPhoto> photos;
  final bool uploading;
  final Future<void> Function(int? replaceIndex) onPickPhoto;
  final ValueChanged<int> onDeletePhoto;
  final void Function(int fromIndex, int toIndex) onMovePhoto;

  const _StudioRoomSettingsPhotoSection({
    this.room,
    required this.photos,
    required this.uploading,
    required this.onPickPhoto,
    required this.onDeletePhoto,
    required this.onMovePhoto,
  });

  @override
  State<_StudioRoomSettingsPhotoSection> createState() =>
      _StudioRoomSettingsPhotoSectionState();
}

class _StudioRoomSettingsPhotoSectionState
    extends State<_StudioRoomSettingsPhotoSection> {
  static const _maximumPhotoCount = 10;
  final _pageController = PageController();
  int _activePhotoIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos.take(_maximumPhotoCount).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1622),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Oda Fotoğrafları',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${photos.length} / $_maximumPhotoCount',
                style: const TextStyle(
                  color: Color(0xFF9EA8B7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 16 / 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _maximumPhotoCount,
                    onPageChanged: (index) =>
                        setState(() => _activePhotoIndex = index),
                    itemBuilder: (_, index) => index < photos.length
                        ? _StudioRoomPhotoSlot(
                            imageUrl: photos[index].url,
                            room: widget.room,
                            onChangePhoto: () => widget.onPickPhoto(index),
                            onDeletePhoto: () =>
                                _deletePhoto(index, photos.length),
                            photoIndex: index,
                            photoCount: photos.length,
                            orderingEnabled: !widget.uploading,
                            onMovePhoto: (targetIndex) =>
                                _movePhoto(index, targetIndex, photos.length),
                            onOpenPhoto: () => _openFullScreenGallery(
                              context,
                              photos: photos
                                  .map((photo) => photo.url)
                                  .toList(growable: false),
                              initialIndex: index,
                            ),
                          )
                        : _EmptyStudioRoomPhotoSlot(
                            slotNumber: index + 1,
                            uploading: widget.uploading,
                            onAddPhoto: () => widget.onPickPhoto(null),
                          ),
                  ),
                  if (widget.uploading) const _StudioRoomPhotoUploadOverlay(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _maximumPhotoCount,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: index == _activePhotoIndex ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _activePhotoIndex
                      ? const Color(0xFFE87587)
                      : index < photos.length
                      ? const Color(0xFF69758A)
                      : const Color(0xFF344052),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullScreenGallery(
    BuildContext context, {
    required List<String> photos,
    required int initialIndex,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => _StudioRoomFullScreenGallery(
          photos: photos,
          room: widget.room,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  void _deletePhoto(int index, int photoCount) {
    widget.onDeletePhoto(index);
    final lastRemainingIndex = photoCount - 2;
    final targetIndex = lastRemainingIndex < 0
        ? 0
        : index > lastRemainingIndex
        ? lastRemainingIndex
        : index;
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _movePhoto(int fromIndex, int toIndex, int photoCount) {
    if (widget.uploading ||
        fromIndex < 0 ||
        fromIndex >= photoCount ||
        toIndex < 0 ||
        toIndex >= photoCount ||
        fromIndex == toIndex) {
      return;
    }
    widget.onMovePhoto(fromIndex, toIndex);
    setState(() => _activePhotoIndex = toIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageController.hasClients) return;
      _pageController.animateToPage(
        toIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}

class _StudioRoomPhotoSlot extends StatelessWidget {
  final String imageUrl;
  final _StudioRoomItem? room;
  final VoidCallback onChangePhoto;
  final VoidCallback onDeletePhoto;
  final VoidCallback onOpenPhoto;
  final int photoIndex;
  final int photoCount;
  final bool orderingEnabled;
  final ValueChanged<int> onMovePhoto;

  const _StudioRoomPhotoSlot({
    required this.imageUrl,
    required this.room,
    required this.onChangePhoto,
    required this.onDeletePhoto,
    required this.onOpenPhoto,
    required this.photoIndex,
    required this.photoCount,
    required this.orderingEnabled,
    required this.onMovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: onOpenPhoto,
          behavior: HitTestBehavior.opaque,
          child: AppCachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            cacheWidth: 960,
            errorBuilder: (_) => room == null
                ? const _StudioRoomGenericPhotoPlaceholder()
                : _StudioRoomPhotoPlaceholder(room: room!),
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: _StudioPhotoOverlayIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Fotoğrafı kaldır',
            color: const Color(0xFFFF8792),
            onPressed: onDeletePhoto,
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: _StudioPhotoOverlayIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Fotoğrafı değiştir',
            onPressed: onChangePhoto,
          ),
        ),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Center(
            child: StudioRoomPhotoOrderControls(
              index: photoIndex,
              itemCount: photoCount,
              enabled: orderingEnabled,
              onMoveTo: onMovePhoto,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudioPhotoOverlayIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _StudioPhotoOverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD90A111B),
      shape: const CircleBorder(side: BorderSide(color: Color(0x667E8CA2))),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: color, size: 19),
      ),
    );
  }
}

class _StudioRoomFullScreenGallery extends StatefulWidget {
  final List<String> photos;
  final _StudioRoomItem? room;
  final int initialIndex;

  const _StudioRoomFullScreenGallery({
    required this.photos,
    required this.room,
    required this.initialIndex,
  });

  @override
  State<_StudioRoomFullScreenGallery> createState() =>
      _StudioRoomFullScreenGalleryState();
}

class _StudioRoomFullScreenGalleryState
    extends State<_StudioRoomFullScreenGallery> {
  late final PageController _pageController;
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) => setState(() => _activeIndex = index),
              itemBuilder: (_, index) => Center(
                child: AppCachedNetworkImage(
                  imageUrl: widget.photos[index],
                  width: double.infinity,
                  fit: BoxFit.contain,
                  cacheProfile: AppImageCacheProfile.original,
                  cacheWidth: 1600,
                  errorBuilder: (_) => widget.room == null
                      ? const _StudioRoomGenericPhotoPlaceholder()
                      : _StudioRoomPhotoPlaceholder(room: widget.room!),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _StudioGalleryOverlayButton(
                tooltip: 'Kapat',
                icon: Icons.close_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xB30A0E15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x667E8CA2)),
                ),
                child: Text(
                  '${_activeIndex + 1} / ${widget.photos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioGalleryOverlayButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _StudioGalleryOverlayButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB30A0E15),
      shape: const CircleBorder(side: BorderSide(color: Color(0x667E8CA2))),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _EmptyStudioRoomPhotoSlot extends StatelessWidget {
  final int slotNumber;
  final bool uploading;
  final VoidCallback onAddPhoto;

  const _EmptyStudioRoomPhotoSlot({
    required this.slotNumber,
    this.uploading = false,
    required this.onAddPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111B29),
      child: InkWell(
        onTap: uploading ? null : onAddPhoto,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF172336),
                  border: Border.all(color: const Color(0xFF3B4A60)),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '$slotNumber. fotoğrafı ekle',
                style: const TextStyle(
                  color: Color(0xFFAAB3C2),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioRoomPhotoUploadOverlay extends StatelessWidget {
  const _StudioRoomPhotoUploadOverlay();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xD90A111B),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFFE87587),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Fotoğraf yükleniyor...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioRoomGenericPhotoPlaceholder extends StatelessWidget {
  const _StudioRoomGenericPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF111B29),
      child: Center(
        child: Icon(
          Icons.meeting_room_outlined,
          color: Color(0xFF9EA8B7),
          size: 48,
        ),
      ),
    );
  }
}

class _StudioRoomApprovalPolicyCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final DateTime? effectiveLocalDate;

  const _StudioRoomApprovalPolicyCard({
    required this.value,
    required this.onChanged,
    this.effectiveLocalDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.approval_outlined,
            color: _roomFormIconColor,
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rezervasyonlar onay gerektirsin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  effectiveLocalDate == null
                      ? value
                            ? 'Yeni talepler onayına düşer.'
                            : 'Müsait saatler otomatik onaylanır.'
                      : 'Planlanan değişiklik ${_effectiveDateLabel(effectiveLocalDate!)} '
                            '00:00’da devreye girer.',
                  style: const TextStyle(
                    color: Color(0xFF98A2B1),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('studio-room-approval-policy-switch'),
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFFF7F87),
          ),
        ],
      ),
    );
  }

  static String _effectiveDateLabel(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.${value.year}';
  }
}

class _StudioRoomOnlinePaymentCard extends StatelessWidget {
  const _StudioRoomOnlinePaymentCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: _roomFormIconColor,
            size: 21,
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Online ödemeleri kabul et',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(width: 7),
                    _StudioComingSoonBadge(),
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  'Online ödemelerde %15 platform hizmet bedeli uygulanır.',
                  style: TextStyle(
                    color: Color(0xFF98A2B1),
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Switch(
            key: Key('studio-room-online-payment-switch'),
            value: false,
            onChanged: null,
          ),
        ],
      ),
    );
  }
}

class _StudioComingSoonBadge extends StatelessWidget {
  const _StudioComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7F87).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFF7F87).withValues(alpha: 0.55),
        ),
      ),
      child: const Text(
        'Yakında',
        style: TextStyle(
          color: Color(0xFFFFA0A6),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
