import 'package:uuid/uuid.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/musician_feed_report_admin.dart';
import '../../domain/musician_feed_report_admin_repository.dart';
import 'musician_feed_report_admin_cubit.dart';

class MusicianFeedRestrictionsAdminState {
  const MusicianFeedRestrictionsAdminState({
    this.status = MusicianFeedReportLoadStatus.initial,
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.loadingMore = false,
    this.submittingId,
    this.error,
    this.notice,
  });
  final MusicianFeedReportLoadStatus status;
  final List<MusicianFeedOrphanRestriction> items;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingMore;
  final String? submittingId;
  final AppError? error;
  final String? notice;
  MusicianFeedRestrictionsAdminState copyWith({
    MusicianFeedReportLoadStatus? status,
    List<MusicianFeedOrphanRestriction>? items,
    Object? nextCursor = copyWithUnset,
    bool? hasMore,
    bool? loadingMore,
    Object? submittingId = copyWithUnset,
    Object? error = copyWithUnset,
    Object? notice = copyWithUnset,
  }) => MusicianFeedRestrictionsAdminState(
    status: status ?? this.status,
    items: items ?? this.items,
    nextCursor: identical(nextCursor, copyWithUnset)
        ? this.nextCursor
        : nextCursor as String?,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    submittingId: identical(submittingId, copyWithUnset)
        ? this.submittingId
        : submittingId as String?,
    error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    notice: identical(notice, copyWithUnset) ? this.notice : notice as String?,
  );
}

class MusicianFeedRestrictionsAdminCubit
    extends MusicianFeedReportSessionCubit<MusicianFeedRestrictionsAdminState> {
  MusicianFeedRestrictionsAdminCubit(
    this.repository,
    AuthSessionManager sessions, {
    MusicianFeedReportAdminIdentity? expectedIdentity,
  }) : super(
         sessions,
         const MusicianFeedRestrictionsAdminState(),
         expectedIdentity: expectedIdentity,
       );
  final MusicianFeedReportAdminRepository repository;
  final _requestIds = <(String, DateTime, String), String>{};
  int _generation = 0;
  static const _unknown = AppError(
    code: 'feed_restrictions_failed',
    message: 'Kısıtlamalar yüklenemedi. Lütfen tekrar dene.',
  );
  @override
  void onAccessLost() {
    _generation++;
    _requestIds.clear();
    emit(
      const MusicianFeedRestrictionsAdminState(
        status: MusicianFeedReportLoadStatus.accessDenied,
        error: AppError(
          code: 'feed_report_admin_access_changed',
          message:
              'Oturumun veya inceleme yetkin değişti. Bu sayfayı yeniden aç.',
        ),
      ),
    );
  }

  Future<void> refresh({bool preserveNotice = false}) async {
    if (!checkAccess() || state.submittingId != null) return;
    final generation = ++_generation;
    emit(
      MusicianFeedRestrictionsAdminState(
        status: MusicianFeedReportLoadStatus.loading,
        notice: preserveNotice ? state.notice : null,
      ),
    );
    final result = await _read();
    if (!checkAccess() || generation != _generation) return;
    if (!result.isSuccess || result.data == null) {
      if (isMusicianFeedReportAdminAccessFailure(result.error)) {
        revokeAccess();
        return;
      }
      emit(
        state.copyWith(
          status: MusicianFeedReportLoadStatus.failure,
          error: result.error ?? _unknown,
        ),
      );
      return;
    }
    final page = result.data!;
    emit(
      state.copyWith(
        status: MusicianFeedReportLoadStatus.ready,
        items: _merge([], page.items),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      ),
    );
  }

  Future<void> loadMore() async {
    if (!checkAccess() ||
        state.status != MusicianFeedReportLoadStatus.ready ||
        state.loadingMore ||
        state.submittingId != null ||
        !state.hasMore) {
      return;
    }
    final cursor = state.nextCursor;
    if (cursor == null) {
      await refresh();
      return;
    }
    final generation = _generation;
    emit(state.copyWith(loadingMore: true, error: null));
    final result = await _read(cursor: cursor);
    if (!checkAccess() || generation != _generation) return;
    if (!result.isSuccess || result.data == null) {
      if (isMusicianFeedReportAdminAccessFailure(result.error)) {
        revokeAccess();
        return;
      }
      if (result.error?.code == '1323') {
        await refresh();
        return;
      }
      emit(state.copyWith(loadingMore: false, error: result.error ?? _unknown));
      return;
    }
    final page = result.data!;
    if (page.hasMore &&
        (page.nextCursor == null || page.nextCursor == cursor)) {
      emit(state.copyWith(loadingMore: false, error: _unknown));
      return;
    }
    emit(
      state.copyWith(
        items: _merge(state.items, page.items),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      ),
    );
  }

  bool canRestore(MusicianFeedOrphanRestriction restriction, int epoch) =>
      checkAccess() &&
      epoch == sessionEpoch &&
      state.submittingId == null &&
      state.items.any(
        (row) =>
            row.reportId == restriction.reportId &&
            row.updatedAt == restriction.updatedAt,
      );

  Future<bool> restore(
    MusicianFeedOrphanRestriction restriction,
    String note, {
    required int expectedEpoch,
  }) async {
    if (!canRestore(restriction, expectedEpoch) ||
        !isValidMusicianFeedResolutionNote(note)) {
      return false;
    }
    final normalized = note.trim();
    final requestId = _requestIds.putIfAbsent((
      restriction.reportId,
      restriction.updatedAt,
      normalized,
    ), const Uuid().v4);
    final generation = ++_generation;
    emit(
      state.copyWith(
        submittingId: restriction.reportId,
        loadingMore: false,
        error: null,
        notice: null,
      ),
    );
    Result<MusicianFeedRestrictionRestored> result;
    try {
      result = await repository.restoreRestriction(
        restriction.reportId,
        clientRequestId: requestId,
        expectedUpdatedAt: restriction.updatedAt,
        resolutionNote: normalized,
      );
    } catch (_) {
      result = const Result.failure(_unknown);
    }
    if (!checkAccess() ||
        generation != _generation ||
        expectedEpoch != sessionEpoch) {
      return false;
    }
    if (!result.isSuccess || result.data?.reportId != restriction.reportId) {
      if (isMusicianFeedReportAdminAccessFailure(result.error)) {
        revokeAccess();
        return false;
      }
      if ({'1322', '409', '1321', '404'}.contains(result.error?.code)) {
        _requestIds.clear();
        emit(
          state.copyWith(
            submittingId: null,
            notice:
                'Kısıtlama bilgileri değişti. Güncel listeyi inceleyip kararını yeniden ver.',
          ),
        );
        await refresh(preserveNotice: true);
      } else {
        emit(
          state.copyWith(submittingId: null, error: result.error ?? _unknown),
        );
      }
      return false;
    }
    _requestIds.removeWhere((key, _) => key.$1 == restriction.reportId);
    emit(
      state.copyWith(
        items: List.unmodifiable(
          state.items.where((row) => row.reportId != restriction.reportId),
        ),
        submittingId: null,
        notice: result.data!.activeRestriction
            ? 'Bu karar geri alındı. Başka etkin kaldırma kararları nedeniyle içerik akışta kısıtlı kalıyor.'
            : 'Kısıtlama kararı geri alındı.',
      ),
    );
    return true;
  }

  Future<Result<MusicianFeedOrphanRestrictionsPage>> _read({
    String? cursor,
  }) async {
    try {
      return await repository.restrictions(cursor: cursor);
    } catch (_) {
      return const Result.failure(_unknown);
    }
  }

  List<MusicianFeedOrphanRestriction> _merge(
    List<MusicianFeedOrphanRestriction> a,
    List<MusicianFeedOrphanRestriction> b,
  ) {
    final seen = <String>{};
    return List.unmodifiable(
      [...a, ...b].where((row) => seen.add(row.reportId)),
    );
  }
}
