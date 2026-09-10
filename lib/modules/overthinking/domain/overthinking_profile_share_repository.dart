import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/error/result.dart';
import '../../../core/pagination/page.dart';
import 'entities/overthinking_profile_share.dart';

export '../../../core/pagination/page.dart';
export 'entities/overthinking_profile_share.dart';
export 'overthinking_profile_share_access.dart';

abstract class OverthinkingProfileShareRepository {
  ValueListenable<int> get changes;

  Future<Result<OverthinkingProfileShareState>> getState({
    required String postId,
    required AuthSession expectedSession,
  });

  /// Creates one publication. Repeating the same note is idempotent; an
  /// existing publication's note is immutable until that share is removed.
  Future<Result<OverthinkingProfileShareState>> publish({
    required String postId,
    String? note,
    required AuthSession expectedSession,
  });

  /// Addresses the publication itself, so an old card cannot delete a repost.
  Future<Result<void>> deleteShare({
    required String shareId,
    required AuthSession expectedSession,
  });

  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  });
}
