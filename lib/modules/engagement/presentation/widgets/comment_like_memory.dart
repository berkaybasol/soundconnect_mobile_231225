import 'package:flutter/foundation.dart';

import '../../domain/entities/comment_item.dart';
import '../../domain/entities/comment_like_state.dart';

/// Thread-owned, weakly keyed by the exact server row snapshot. Scrolling or
/// folding replies retains confirmed/in-flight state without keeping old pages
/// alive. A fresh DTO or account never inherits another snapshot's projection.
class CommentLikeMemory {
  Expando<CommentLikeRecord> _rows = Expando<CommentLikeRecord>();
  int _generation = 0;

  CommentLikeRecord acquire(
    CommentItem item,
    Object? session,
    Object? repository,
    CommentLikeState initial,
  ) {
    final existing = _rows[item];
    if (existing != null &&
        identical(existing.session, session) &&
        identical(existing.repository, repository)) {
      return existing;
    }
    return _rows[item] = CommentLikeRecord(
      session: session,
      repository: repository,
      generation: _generation,
      value: initial,
    );
  }

  bool contains(CommentItem item, CommentLikeRecord record) =>
      record.generation == _generation && identical(_rows[item], record);

  void clear() {
    _generation++;
    _rows = Expando<CommentLikeRecord>();
  }
}

class CommentLikeRecord extends ChangeNotifier {
  CommentLikeRecord({
    required this.session,
    required this.repository,
    required this.generation,
    required this.value,
  });

  final Object? session;
  final Object? repository;
  final int generation;
  CommentLikeState value;
  bool busy = false;
  bool uncertain = false;

  void update({CommentLikeState? value, bool? busy, bool? uncertain}) {
    this.value = value ?? this.value;
    this.busy = busy ?? this.busy;
    this.uncertain = uncertain ?? this.uncertain;
    notifyListeners();
  }
}
