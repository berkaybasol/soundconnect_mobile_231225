import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../event_audience/domain/event_audience_repository.dart';
import '../../../event_audience/presentation/event_audience_controller.dart';
import '../../domain/entities/venue_event_detail.dart';

class ListenerEventFeedRow {
  const ListenerEventFeedRow({
    required this.event,
    required this.intent,
    required this.note,
    required this.ended,
    this.postId,
    this.privateState,
  });
  final VenueEventDetail event;
  final String? postId;
  final EventAudienceStatus intent;
  final String? note;
  final bool ended;
  final EventAudienceState? privateState;
}

/// Holds one bounded page, never a growing copy of the profile's history.
/// Both transport and presentation are fenced to the session that requested it.
class ListenerEventFeedController extends ChangeNotifier {
  ListenerEventFeedController({
    required this.repository,
    required this.sessions,
    required this.listenerProfileId,
    this.ownerUserId,
    this.privatePlans = false,
    this.pageSize = 20,
    EventAudiencePeriod? period,
  }) : period =
           period ??
           (privatePlans
               ? EventAudiencePeriod.upcoming
               : EventAudiencePeriod.all) {
    _identity = _sessionIdentity(sessions.session);
    sessions.addListener(_sessionChanged);
    repository.changes.addListener(_dataChanged);
  }

  final EventAudienceRepository repository;
  final AuthSessionManager sessions;
  final String listenerProfileId;
  final String? ownerUserId;
  final bool privatePlans;
  final int pageSize;
  EventAudiencePeriod period;
  List<ListenerEventFeedRow> rows = const [];
  bool loading = false;
  String? error;
  int page = 0;
  bool hasNext = false;
  int _requestedPage = 0;
  int _generation = 0;
  bool _disposed = false;
  late String _identity;

  bool get allowed {
    if (_disposed) return false;
    final session = sessions.session;
    if (!session.isAuthenticated ||
        !session.isActive ||
        session.userId?.trim().isNotEmpty != true) {
      return false;
    }
    if (ownerUserId != null && session.userId != ownerUserId) return false;
    if ((privatePlans || ownerUserId != null) &&
        (session.requiresListenerProfileChoice ||
            !canUseEventAudience(session) ||
            !session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']))) {
      return false;
    }
    return true;
  }

  Future<void> reload() => _load(0);
  Future<void> retry() => _load(_requestedPage);
  Future<void> next() async {
    if (!loading && hasNext) await _load(page + 1);
  }

  Future<void> previous() async {
    if (!loading && page > 0) await _load(page - 1);
  }

  Future<void> selectPeriod(EventAudiencePeriod value) async {
    if (value == period) return;
    period = value;
    await reload();
  }

  Future<void> _load(int requestedPage) async {
    if (_disposed) return;
    final generation = ++_generation;
    _requestedPage = requestedPage;
    page = requestedPage;
    rows = const [];
    hasNext = false;
    error = null;
    loading = allowed;
    notifyListeners();
    if (!loading) return;
    final identity = _identity;
    final userId = sessions.session.userId!;
    try {
      if (privatePlans) {
        final result = await repository.listMine(
          expectedSessionKey: userId,
          period: period,
          page: requestedPage,
          size: pageSize,
        );
        if (!_isCurrent(generation, identity)) return;
        final data = result.data;
        if (!result.isSuccess || data == null) {
          _fail(result.error?.message);
          return;
        }
        rows = List.unmodifiable(
          data.items
              .where(
                (item) =>
                    item.eventAvailable &&
                    item.event != null &&
                    item.intent != EventAudienceStatus.none,
              )
              .map(
                (item) => ListenerEventFeedRow(
                  event: item.event!,
                  postId: item.postId,
                  intent: item.intent,
                  note: item.note,
                  privateState: item,
                  ended: item.eventEnded,
                ),
              ),
        );
        page = data.page;
        hasNext = data.hasNext;
      } else {
        final result = await repository.listPublic(
          listenerProfileId,
          expectedSessionKey: userId,
          period: period,
          page: requestedPage,
          size: pageSize,
        );
        if (!_isCurrent(generation, identity)) return;
        final data = result.data;
        if (!result.isSuccess || data == null) {
          _fail(result.error?.message);
          return;
        }
        rows = List.unmodifiable(
          data.items
              .where((item) => item.intent != EventAudienceStatus.none)
              .map(
                (item) => ListenerEventFeedRow(
                  event: item.event,
                  postId: item.postId,
                  intent: item.intent,
                  note: item.note,
                  ended: item.eventEnded,
                ),
              ),
        );
        page = data.page;
        hasNext = data.hasNext;
      }
      loading = false;
      notifyListeners();
    } catch (_) {
      if (_isCurrent(generation, identity)) _fail(null);
    }
  }

  bool _isCurrent(int generation, String identity) =>
      !_disposed &&
      generation == _generation &&
      identity == _identity &&
      allowed;

  void _fail(String? message) {
    // Even a failed page request may follow a privacy change. Do not retain a
    // formerly public page behind the error or treat forbidden as empty data.
    rows = const [];
    loading = false;
    hasNext = false;
    error = message?.trim().isNotEmpty == true
        ? message!.trim()
        : 'Etkinlik planları yüklenemedi. Tekrar deneyebilirsin.';
    notifyListeners();
  }

  void _sessionChanged() {
    final next = _sessionIdentity(sessions.session);
    if (next == _identity) {
      // Metadata updates (such as a username change) replace AuthSession too.
      // Rebind UI callbacks fenced to that instance without reloading the page.
      notifyListeners();
      return;
    }
    _identity = next;
    unawaited(reload());
  }

  void _dataChanged() => unawaited(reload());

  static String _sessionIdentity(AuthSession session) =>
      '${session.userId}|${session.token}|${session.accountStatus}|'
      '${session.normalizedRoles.toList()..sort()}|'
      '${session.requiresListenerProfileChoice}|${session.isAdmin}';

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    sessions.removeListener(_sessionChanged);
    repository.changes.removeListener(_dataChanged);
    super.dispose();
  }
}
