import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/musician_feed_report_admin.dart';
import '../../domain/musician_feed_report_admin_repository.dart';

enum MusicianFeedReportLoadStatus {
  initial,
  loading,
  ready,
  failure,
  accessDenied,
}

const _accessError = AppError(
  code: 'feed_report_admin_access_changed',
  message: 'Oturumun veya inceleme yetkin değişti. Bu sayfayı yeniden aç.',
);
const _unknownError = AppError(
  code: 'feed_report_admin_failed',
  message: 'Şikâyet bilgileri yüklenemedi. Lütfen tekrar dene.',
);
const _staleNotice =
    'Bu kayıt başka bir işlemle değişti. Güncel bilgileri inceleyip kararını yeniden ver.';

abstract class MusicianFeedReportSessionCubit<S> extends Cubit<S> {
  MusicianFeedReportSessionCubit(
    this.sessions,
    S initial, {
    MusicianFeedReportAdminIdentity? expectedIdentity,
  }) : owner =
           expectedIdentity ??
           musicianFeedReportAdminIdentity(sessions.session),
       super(initial) {
    sessions.addListener(_onSessionChanged);
  }
  final AuthSessionManager sessions;
  final MusicianFeedReportAdminIdentity? owner;
  bool _revoked = false;
  int sessionEpoch = 0;
  bool get hasAccess =>
      !_revoked &&
      owner != null &&
      owner == musicianFeedReportAdminIdentity(sessions.session);

  bool checkAccess() {
    if (isClosed) return false;
    if (hasAccess) return true;
    revokeAccess();
    return false;
  }

  void revokeAccess() {
    if (!isClosed && !_revoked) {
      _revoked = true;
      sessionEpoch++;
      onAccessLost();
    }
  }

  void _onSessionChanged() => checkAccess();
  void onAccessLost();
  @override
  Future<void> close() {
    sessions.removeListener(_onSessionChanged);
    _revoked = true;
    sessionEpoch++;
    return super.close();
  }
}

class MusicianFeedReportAdminState {
  const MusicianFeedReportAdminState({
    this.loadStatus = MusicianFeedReportLoadStatus.initial,
    this.filterStatus = MusicianFeedReportStatus.fresh,
    this.itemType,
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.error,
    this.pagingError,
  });
  final MusicianFeedReportLoadStatus loadStatus;
  final MusicianFeedReportStatus filterStatus;
  final String? itemType;
  final List<MusicianFeedReportSummary> items;
  final String? nextCursor;
  final bool hasMore;
  final bool refreshing;
  final bool loadingMore;
  final AppError? error;
  final AppError? pagingError;

  MusicianFeedReportAdminState copyWith({
    MusicianFeedReportLoadStatus? loadStatus,
    MusicianFeedReportStatus? filterStatus,
    Object? itemType = copyWithUnset,
    List<MusicianFeedReportSummary>? items,
    Object? nextCursor = copyWithUnset,
    bool? hasMore,
    bool? refreshing,
    bool? loadingMore,
    Object? error = copyWithUnset,
    Object? pagingError = copyWithUnset,
  }) => MusicianFeedReportAdminState(
    loadStatus: loadStatus ?? this.loadStatus,
    filterStatus: filterStatus ?? this.filterStatus,
    itemType: identical(itemType, copyWithUnset)
        ? this.itemType
        : itemType as String?,
    items: items ?? this.items,
    nextCursor: identical(nextCursor, copyWithUnset)
        ? this.nextCursor
        : nextCursor as String?,
    hasMore: hasMore ?? this.hasMore,
    refreshing: refreshing ?? this.refreshing,
    loadingMore: loadingMore ?? this.loadingMore,
    error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    pagingError: identical(pagingError, copyWithUnset)
        ? this.pagingError
        : pagingError as AppError?,
  );
}

class MusicianFeedReportAdminCubit
    extends MusicianFeedReportSessionCubit<MusicianFeedReportAdminState> {
  MusicianFeedReportAdminCubit(this.repository, AuthSessionManager sessions)
    : super(sessions, const MusicianFeedReportAdminState());
  final MusicianFeedReportAdminRepository repository;
  int _generation = 0;

  @override
  void onAccessLost() {
    _generation++;
    emit(
      const MusicianFeedReportAdminState(
        loadStatus: MusicianFeedReportLoadStatus.accessDenied,
        error: _accessError,
      ),
    );
  }

  Future<void> initialize() async {
    if (state.loadStatus == MusicianFeedReportLoadStatus.initial) {
      await refresh();
    }
  }

  Future<void> filter({
    required MusicianFeedReportStatus status,
    String? itemType,
  }) async {
    if (!checkAccess()) return;
    _generation++;
    emit(
      MusicianFeedReportAdminState(filterStatus: status, itemType: itemType),
    );
    await refresh();
  }

  Future<void> refresh() async {
    if (!checkAccess()) return;
    final generation = ++_generation;
    final keepItems = state.items.isNotEmpty;
    emit(
      state.copyWith(
        loadStatus: keepItems
            ? MusicianFeedReportLoadStatus.ready
            : MusicianFeedReportLoadStatus.loading,
        refreshing: keepItems,
        loadingMore: false,
        error: null,
        pagingError: null,
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
          loadStatus: keepItems
              ? MusicianFeedReportLoadStatus.ready
              : MusicianFeedReportLoadStatus.failure,
          refreshing: false,
          error: result.error ?? _unknownError,
        ),
      );
      return;
    }
    final page = result.data!;
    emit(
      state.copyWith(
        loadStatus: MusicianFeedReportLoadStatus.ready,
        items: _merge([], page.items),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        refreshing: false,
      ),
    );
  }

  Future<void> loadMore() async {
    if (!checkAccess() ||
        state.loadingMore ||
        state.refreshing ||
        !state.hasMore ||
        state.loadStatus != MusicianFeedReportLoadStatus.ready) {
      return;
    }
    final cursor = state.nextCursor;
    if (cursor == null) {
      await refresh();
      return;
    }
    final generation = _generation;
    emit(state.copyWith(loadingMore: true, pagingError: null));
    final result = await _read(cursor: cursor);
    if (!checkAccess() || generation != _generation) return;
    if (!result.isSuccess || result.data == null) {
      if (isMusicianFeedReportAdminAccessFailure(result.error)) {
        revokeAccess();
        return;
      }
      if (_isCode(result.error, {
        '1323',
        'MUSICIAN_FEED_REPORT_CURSOR_INVALID',
      })) {
        await refresh();
      } else {
        emit(
          state.copyWith(
            loadingMore: false,
            pagingError: result.error ?? _unknownError,
          ),
        );
      }
      return;
    }
    final page = result.data!;
    if (page.hasMore &&
        (page.nextCursor == null || page.nextCursor == cursor)) {
      emit(state.copyWith(loadingMore: false, pagingError: _unknownError));
      return;
    }
    emit(
      state.copyWith(
        items: _merge(state.items, page.items),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
        pagingError: null,
      ),
    );
  }

  bool canOpen(String reportId) =>
      checkAccess() && state.items.any((item) => item.id == reportId);
  Future<Result<MusicianFeedReportAdminPage>> _read({String? cursor}) async {
    try {
      return await repository.load(
        status: state.filterStatus,
        itemType: state.itemType,
        cursor: cursor,
      );
    } catch (_) {
      return const Result.failure(_unknownError);
    }
  }

  List<MusicianFeedReportSummary> _merge(
    List<MusicianFeedReportSummary> a,
    List<MusicianFeedReportSummary> b,
  ) {
    final seen = <String>{};
    return List.unmodifiable([...a, ...b].where((item) => seen.add(item.id)));
  }
}

class MusicianFeedReportDetailState {
  const MusicianFeedReportDetailState({
    this.loadStatus = MusicianFeedReportLoadStatus.initial,
    this.detail,
    this.refreshing = false,
    this.submitting = false,
    this.error,
    this.notice,
  });
  final MusicianFeedReportLoadStatus loadStatus;
  final MusicianFeedReportDetail? detail;
  final bool refreshing;
  final bool submitting;
  final AppError? error;
  final String? notice;
  MusicianFeedReportDetailState copyWith({
    MusicianFeedReportLoadStatus? loadStatus,
    Object? detail = copyWithUnset,
    bool? refreshing,
    bool? submitting,
    Object? error = copyWithUnset,
    Object? notice = copyWithUnset,
  }) => MusicianFeedReportDetailState(
    loadStatus: loadStatus ?? this.loadStatus,
    detail: identical(detail, copyWithUnset)
        ? this.detail
        : detail as MusicianFeedReportDetail?,
    refreshing: refreshing ?? this.refreshing,
    submitting: submitting ?? this.submitting,
    error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    notice: identical(notice, copyWithUnset) ? this.notice : notice as String?,
  );
}

class MusicianFeedReportDetailCubit
    extends MusicianFeedReportSessionCubit<MusicianFeedReportDetailState> {
  MusicianFeedReportDetailCubit(
    this.repository,
    AuthSessionManager sessions,
    this.reportId, {
    MusicianFeedReportAdminIdentity? expectedIdentity,
    String Function()? requestIdFactory,
  }) : _requestIdFactory = requestIdFactory ?? const Uuid().v4,
       super(
         sessions,
         const MusicianFeedReportDetailState(),
         expectedIdentity: expectedIdentity,
       );
  final MusicianFeedReportAdminRepository repository;
  final String reportId;
  final String Function() _requestIdFactory;
  final _requestIds = <(int, MusicianFeedReportDecision, String), String>{};
  int _generation = 0;
  bool changed = false;

  @override
  void onAccessLost() {
    _generation++;
    _requestIds.clear();
    emit(
      const MusicianFeedReportDetailState(
        loadStatus: MusicianFeedReportLoadStatus.accessDenied,
        error: _accessError,
      ),
    );
  }

  Future<void> load({bool preserveNotice = false}) async {
    if (!checkAccess() || state.submitting) return;
    final generation = ++_generation;
    emit(
      state.copyWith(
        loadStatus: MusicianFeedReportLoadStatus.loading,
        detail: null,
        refreshing: true,
        error: null,
        notice: preserveNotice ? state.notice : null,
      ),
    );
    Result<MusicianFeedReportDetail> result;
    try {
      result = await repository.detail(reportId);
    } catch (_) {
      result = const Result.failure(_unknownError);
    }
    if (!checkAccess() || generation != _generation) return;
    if (!result.isSuccess || result.data?.report.id != reportId) {
      if (isMusicianFeedReportAdminAccessFailure(result.error)) {
        revokeAccess();
        return;
      }
      final error =
          _isCode(result.error, {
            '1321',
            '404',
            'MUSICIAN_FEED_REPORT_NOT_FOUND',
          })
          ? const AppError(
              code: '1321',
              message: 'Bu şikâyet kaydı artık bulunamıyor.',
            )
          : result.error ?? _unknownError;
      emit(
        state.copyWith(
          loadStatus: MusicianFeedReportLoadStatus.failure,
          refreshing: false,
          error: error,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        loadStatus: MusicianFeedReportLoadStatus.ready,
        detail: result.data,
        refreshing: false,
      ),
    );
  }

  Future<bool> review(
    MusicianFeedReportDecision decision,
    String note, {
    required int expectedVersion,
    required int expectedEpoch,
  }) async {
    if (!checkAccess() || expectedEpoch != sessionEpoch || state.submitting) {
      return false;
    }
    final detail = state.detail;
    if (detail == null ||
        detail.report.version != expectedVersion ||
        !detail.allowedDecisions.contains(decision)) {
      emit(state.copyWith(notice: _staleNotice));
      return false;
    }
    final normalized = note.trim();
    if (!isValidMusicianFeedResolutionNote(normalized)) {
      emit(
        state.copyWith(
          error: const AppError(
            code: 'feed_report_note_invalid',
            message: 'Karar gerekçesi 5–500 karakter olmalı.',
          ),
        ),
      );
      return false;
    }
    final key = (expectedVersion, decision, normalized);
    final requestId = _requestIds.putIfAbsent(key, _requestIdFactory);
    final generation = ++_generation;
    emit(state.copyWith(submitting: true, error: null, notice: null));
    Result<MusicianFeedReportDetail> result;
    try {
      result = await repository.review(
        reportId,
        clientRequestId: requestId,
        expectedVersion: expectedVersion,
        decision: decision,
        resolutionNote: normalized,
      );
    } catch (_) {
      result = const Result.failure(_unknownError);
    }
    if (!checkAccess() ||
        generation != _generation ||
        expectedEpoch != sessionEpoch) {
      return false;
    }
    if (!result.isSuccess || result.data?.report.id != reportId) {
      if (isMusicianFeedReportAdminAccessFailure(result.error)) {
        revokeAccess();
        return false;
      }
      if (_isCode(result.error, {
        '1322',
        '409',
        'MUSICIAN_FEED_REPORT_CONFLICT',
      })) {
        _requestIds.clear();
        emit(
          state.copyWith(submitting: false, detail: null, notice: _staleNotice),
        );
        await load(preserveNotice: true);
      } else if (_isCode(result.error, {
        '1321',
        '404',
        'MUSICIAN_FEED_REPORT_NOT_FOUND',
      })) {
        _requestIds.clear();
        emit(
          const MusicianFeedReportDetailState(
            loadStatus: MusicianFeedReportLoadStatus.failure,
            error: AppError(
              code: '1321',
              message: 'Bu şikâyet kaydı artık bulunamıyor.',
            ),
          ),
        );
      } else {
        emit(
          state.copyWith(
            submitting: false,
            error: result.error ?? _unknownError,
          ),
        );
      }
      return false;
    }
    _requestIds.clear();
    changed = true;
    emit(
      state.copyWith(
        detail: result.data,
        submitting: false,
        notice: 'Karar kaydedildi.',
      ),
    );
    return true;
  }
}

bool _isCode(AppError? error, Set<String> values) =>
    values.contains(error?.code.trim().toUpperCase());
bool isMusicianFeedReportAdminAccessFailure(AppError? error) => _isCode(error, {
  '401',
  '403',
  '1101',
  '1102',
  '1103',
  '1008',
  'FEED_REPORT_ADMIN_ACCESS_CHANGED',
});
