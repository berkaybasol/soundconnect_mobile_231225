import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/error/result.dart';
import '../../../core/pagination/page.dart';
import 'entities/table_group_profile_share.dart';

export '../../../core/pagination/page.dart';
export 'entities/table_group_profile_share.dart';

abstract class TableGroupProfileShareRepository {
  ValueListenable<int> get changes;

  Future<Result<TableGroupProfileShareState>> getState({
    required String tableGroupId,
    required AuthSession expectedSession,
  });

  /// One publication per eligible table. Repeating the same note is idempotent.
  Future<Result<TableGroupProfileShareState>> publish({
    required String tableGroupId,
    String? note,
    required AuthSession expectedSession,
  });

  /// Uses publication identity so an old tile cannot remove a later repost.
  Future<Result<void>> deleteShare({
    required String shareId,
    required AuthSession expectedSession,
  });

  Future<Result<Page<TableGroupProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  });

  /// Refresh a bounded set of displayed publications without walking pages.
  /// An omitted requested ID is no longer visible to this viewer.
  Future<Result<List<TableGroupProfileShare>>> lookupProfile({
    required String profileId,
    required AuthSession expectedSession,
    required Set<String> shareIds,
  });
}
