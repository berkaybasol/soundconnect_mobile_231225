import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../domain/announcement_access.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/promotion_repository.dart';

class AnnouncementListState {
  const AnnouncementListState({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.nextCursor,
    this.error,
    this.accessRevoked = false,
    this.filter,
  });
  final List<Announcement> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;
  final bool accessRevoked;
  final AnnouncementStatus? filter;
}

class AnnouncementListCubit extends Cubit<AnnouncementListState> {
  AnnouncementListCubit(this.repository, this.sessions, {this.admin = false})
    : super(const AnnouncementListState()) {
    _identity = announcementSessionIdentity(sessions.session, admin: admin);
    sessions.addListener(_sessionChanged);
  }
  final PromotionRepository repository;
  final AuthSessionManager sessions;
  final bool admin;
  AnnouncementSessionIdentity? _identity;
  int _epoch = 0;
  bool _revoked = false;
  final _seenCursors = <String>{};
  void _sessionChanged() {
    if (_revoked ||
        isClosed ||
        _identity ==
            announcementSessionIdentity(sessions.session, admin: admin)) {
      return;
    }
    _revoked = true;
    _epoch++;
    emit(
      const AnnouncementListState(
        accessRevoked: true,
        error: 'Oturumun veya yetkin değişti. Sayfayı yeniden aç.',
      ),
    );
  }

  Future<void> refresh({AnnouncementStatus? filter}) =>
      _load(reset: true, filter: filter);
  Future<void> loadMore() => _load(reset: false, filter: state.filter);
  Future<void> _load({required bool reset, AnnouncementStatus? filter}) async {
    if (isClosed ||
        _revoked ||
        _identity == null ||
        (!reset && (state.loading || state.loadingMore || !state.hasMore))) {
      return;
    }
    final epoch = ++_epoch;
    if (reset) _seenCursors.clear();
    final previous = state;
    emit(
      AnnouncementListState(
        items: reset ? const [] : previous.items,
        loading: reset,
        loadingMore: !reset,
        filter: filter,
        hasMore: previous.hasMore,
        nextCursor: previous.nextCursor,
      ),
    );
    final result = await repository.announcements(
      admin: admin,
      status: filter,
      cursor: reset ? null : previous.nextCursor,
    );
    if (isClosed || _revoked || epoch != _epoch) return;
    final page = result.data;
    if (!result.isSuccess || page == null) {
      emit(
        AnnouncementListState(
          items: reset ? const [] : previous.items,
          filter: filter,
          hasMore: !reset && previous.hasMore,
          nextCursor: reset ? null : previous.nextCursor,
          error: result.error?.message ?? 'Duyurular getirilemedi.',
        ),
      );
      return;
    }
    final merged = <String, Announcement>{
      if (!reset)
        for (final item in previous.items) item.id: item,
      for (final item in page.items) item.id: item,
    };
    if (page.hasMore && !_seenCursors.add(page.nextCursor!)) {
      emit(
        AnnouncementListState(
          items: List.unmodifiable(merged.values),
          filter: filter,
          error: 'Duyuru listesi ilerleyemedi. Listeyi yenile.',
        ),
      );
      return;
    }
    emit(
      AnnouncementListState(
        items: List.unmodifiable(merged.values),
        filter: filter,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      ),
    );
  }

  @override
  Future<void> close() {
    _epoch++;
    sessions.removeListener(_sessionChanged);
    return super.close();
  }
}
