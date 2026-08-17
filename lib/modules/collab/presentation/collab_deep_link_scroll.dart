import 'dart:async';

import 'package:flutter/material.dart';

/// Reveals a lazily built SliverList child without assuming that its GlobalKey
/// already has a context. Offset candidates are bounded and index-aware; the
/// caller can defer to manual scrolling if none materializes the child.
Future<bool> revealCollabPagedTarget({
  required ScrollController controller,
  required GlobalKey targetKey,
  required int targetIndex,
  required int itemCount,
  double estimatedItemExtent = 240,
}) async {
  if (targetIndex < 0 || itemCount <= targetIndex) return false;

  for (var attempt = 0; attempt < 6; attempt++) {
    await WidgetsBinding.instance.endOfFrame;
    final targetContext = targetKey.currentContext;
    if (targetContext != null) {
      if (!targetContext.mounted) continue;
      try {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.2,
          duration: const Duration(milliseconds: 180),
        );
        return true;
      } catch (_) {
        // The route may have been disposed between frames.
        return false;
      }
    }
    if (!controller.hasClients) continue;

    final position = controller.position;
    final ratio = itemCount == 1 ? 0.0 : targetIndex / (itemCount - 1);
    final ratioOffset = position.maxScrollExtent * ratio;
    final estimatedOffset = targetIndex * estimatedItemExtent;
    final viewport = position.viewportDimension;
    final candidate = switch (attempt) {
      0 => ratioOffset,
      1 => estimatedOffset,
      2 => ratioOffset - viewport * 0.75,
      3 => ratioOffset + viewport * 0.75,
      4 => estimatedOffset - viewport * 0.5,
      _ => estimatedOffset + viewport * 0.5,
    };
    final offset = candidate
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    try {
      await controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } catch (_) {
      return false;
    }
  }

  await WidgetsBinding.instance.endOfFrame;
  final targetContext = targetKey.currentContext;
  if (targetContext == null || !targetContext.mounted) return false;
  try {
    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.2,
      duration: const Duration(milliseconds: 180),
    );
    return true;
  } catch (_) {
    return false;
  }
}
