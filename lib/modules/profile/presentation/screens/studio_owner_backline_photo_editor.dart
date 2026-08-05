part of 'studio_profile_screen.dart';

class _BacklineInventoryPhotosEditor extends StatefulWidget {
  final List<String> photoPaths;
  final Future<void> Function() onAddPhotos;
  final Future<void> Function(int index) onReplacePhoto;
  final ValueChanged<int> onDeletePhoto;
  final void Function(int fromIndex, int toIndex) onMovePhoto;

  const _BacklineInventoryPhotosEditor({
    required this.photoPaths,
    required this.onAddPhotos,
    required this.onReplacePhoto,
    required this.onDeletePhoto,
    required this.onMovePhoto,
  });

  @override
  State<_BacklineInventoryPhotosEditor> createState() =>
      _BacklineInventoryPhotosEditorState();
}

class _BacklineInventoryPhotosEditorState
    extends State<_BacklineInventoryPhotosEditor> {
  static const _maximumPhotoCount = _maximumBacklineEquipmentPhotoCount;
  final _pageController = PageController();
  int _activeIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photoPaths;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ownerManagementInsetBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ekipman Fotoğrafları',
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
              child: PageView.builder(
                controller: _pageController,
                itemCount: _maximumPhotoCount,
                onPageChanged: (index) => setState(() => _activeIndex = index),
                itemBuilder: (_, index) => index < photos.length
                    ? _BacklineInventoryPhotoSlot(
                        path: photos[index],
                        onReplace: () => widget.onReplacePhoto(index),
                        onDelete: () => _deletePhoto(index, photos.length),
                        onMoveLeft: index > 0
                            ? () => _movePhoto(index, index - 1)
                            : null,
                        onMoveRight: index < photos.length - 1
                            ? () => _movePhoto(index, index + 1)
                            : null,
                      )
                    : _EmptyStudioRoomPhotoSlot(
                        slotNumber: index + 1,
                        onAddPhoto: widget.onAddPhotos,
                      ),
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
                width: index == _activeIndex ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _activeIndex
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

  void _movePhoto(int fromIndex, int toIndex) {
    widget.onMovePhoto(fromIndex, toIndex);
    _pageController.animateToPage(
      toIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

class _BacklineInventoryPhotoSlot extends StatelessWidget {
  final String path;
  final VoidCallback onReplace;
  final VoidCallback onDelete;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  const _BacklineInventoryPhotoSlot({
    required this.path,
    required this.onReplace,
    required this.onDelete,
    required this.onMoveLeft,
    required this.onMoveRight,
  });

  @override
  Widget build(BuildContext context) {
    final isNetworkImage = isValidNetworkImageUrl(path);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (isNetworkImage)
          AppCachedNetworkImage(
            imageUrl: path,
            fit: BoxFit.cover,
            cacheWidth: 360,
            cacheHeight: 360,
            errorBuilder: (_) => const _BacklineBrokenPhoto(),
          )
        else
          Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _BacklineBrokenPhoto(),
          ),
        Positioned(
          top: 10,
          left: 10,
          child: _StudioPhotoOverlayIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Fotoğrafı kaldır',
            color: const Color(0xFFFF8792),
            onPressed: onDelete,
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: _StudioPhotoOverlayIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Fotoğrafı değiştir',
            onPressed: onReplace,
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Material(
            color: const Color(0xD90A111B),
            borderRadius: BorderRadius.circular(999),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onMoveLeft,
                  tooltip: 'Sola taşı',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                ),
                Container(width: 1, height: 20, color: const Color(0x667E8CA2)),
                IconButton(
                  onPressed: onMoveRight,
                  tooltip: 'Sağa taşı',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BacklineBrokenPhoto extends StatelessWidget {
  const _BacklineBrokenPhoto();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _ownerManagementInsetColor,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Color(0xFF929BA8),
          size: 38,
        ),
      ),
    );
  }
}
