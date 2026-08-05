import 'package:flutter/material.dart';

/// Compact, keyboard-accessible controls for changing a room photo's display
/// order. The first photo is also the room's cover image.
class StudioRoomPhotoOrderControls extends StatelessWidget {
  const StudioRoomPhotoOrderControls({
    required this.index,
    required this.itemCount,
    required this.onMoveTo,
    this.enabled = true,
    super.key,
  });

  final int index;
  final int itemCount;
  final ValueChanged<int> onMoveTo;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (itemCount < 2 || index < 0 || index >= itemCount) {
      return const SizedBox.shrink();
    }

    return Material(
      color: const Color(0xE60A111B),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x667E8CA2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('studio-room-photo-move-previous'),
              onPressed: enabled && index > 0
                  ? () => onMoveTo(index - 1)
                  : null,
              tooltip: 'Fotoğrafı sola taşı',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
            ),
            Semantics(
              label: 'Fotoğraf sırası ${index + 1} / $itemCount',
              child: Text(
                '${index + 1}/$itemCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              key: const Key('studio-room-photo-move-next'),
              onPressed: enabled && index < itemCount - 1
                  ? () => onMoveTo(index + 1)
                  : null,
              tooltip: 'Fotoğrafı sağa taşı',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
