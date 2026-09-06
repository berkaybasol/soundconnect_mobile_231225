import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/event_performer_request.dart';
import '../../domain/event_performer_request_repository.dart';
import 'event_performer_request_copy.dart';
import 'event_performer_request_card.dart';
import 'event_invitation_rejection_dialog.dart';

typedef _RequestIdentity = (
  String,
  String,
  EventPerformerTargetType,
  String,
  String?,
  String?,
  EventPerformerRequestPurpose,
);

_RequestIdentity _identityOf(EventPerformerRequest request) => (
  request.requestId,
  request.eventId,
  request.targetType,
  request.targetId,
  request.musicianProfileId,
  request.bandId,
  request.requestPurpose,
);

class EventPerformerRequestsScreen extends StatefulWidget {
  final EventPerformerTargetType? targetType;
  final String? targetId;
  final EventPerformerRequestRepository? repository;
  final String? Function()? sessionKeyProvider;
  final EventPerformerRequestStatus status;
  @visibleForTesting
  final Duration Function()? elapsedProvider;

  const EventPerformerRequestsScreen({
    super.key,
    this.targetType,
    this.targetId,
    this.repository,
    this.sessionKeyProvider,
    this.status = EventPerformerRequestStatus.pending,
    this.elapsedProvider,
  });

  @override
  State<EventPerformerRequestsScreen> createState() =>
      _EventPerformerRequestsScreenState();
}

class _EventPerformerRequestsScreenState
    extends State<EventPerformerRequestsScreen> {
  bool get _rejected => widget.status == EventPerformerRequestStatus.rejected;
  static const int _pageSize = 20;
  static const int _automaticFilteredPageBudget = 3;

  late EventPerformerRequestRepository _repository;
  final ScrollController _scrollController = ScrollController();

  List<EventPerformerRequest> _requests = const [];
  final Set<String> _processingIds = <String>{};
  final Set<String> _resolvedIds = <String>{};
  final Set<_RequestIdentity> _profileChoices = <_RequestIdentity>{};
  AuthSessionManager? _sessionManager;
  String? _observedSession;
  int _loadGeneration = 0;
  int _nextPage = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = false;
  bool _reloadRequired = false;
  String? _errorText;
  String? _loadMoreErrorText;
  String? _loadedSession;
  ModalRoute<bool>? _decisionDialogRoute;
  NavigatorState? _decisionDialogNavigator;
  final Stopwatch _elapsed = Stopwatch()..start();
  final Map<_RequestIdentity, Duration> _deadlines = {};
  Timer? _deadlineTimer;
  Duration get _elapsedNow =>
      widget.elapsedProvider?.call() ?? _elapsed.elapsed;

  bool _expired(EventPerformerRequest request) =>
      request.expired == true ||
      (_deadlines[_identityOf(request)]?.compareTo(_elapsedNow) ?? 1) <= 0;

  bool _canDecide(EventPerformerRequest request) =>
      !_expired(request) &&
      _deadlines.containsKey(_identityOf(request)) &&
      (_rejected
          ? request.canReconsider == true
          : request.decisionAllowed == true);

  void _scheduleDeadline() {
    _deadlineTimer?.cancel();
    final elapsed = _elapsedNow;
    final next = _deadlines.values.where((value) => value > elapsed).toList()
      ..sort();
    if (next.isEmpty) return;
    final remaining = next.first - elapsed;
    final delay = remaining > const Duration(days: 1)
        ? const Duration(days: 1)
        : remaining;
    _deadlineTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleDeadline();
    });
  }

  String? get _session {
    if (widget.sessionKeyProvider != null) return widget.sessionKeyProvider!();
    final session = _sessionManager?.session;
    if (session == null || !session.isAuthenticated) return null;
    return '${session.userId}:${session.token}:${session.accountStatus}';
  }

  void _bindSessionListener() {
    _sessionManager?.removeListener(_onSessionChanged);
    _sessionManager =
        widget.sessionKeyProvider == null &&
            serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    _observedSession = _session;
    _sessionManager?.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    if (!mounted || _observedSession == _session) return;
    _observedSession = _session;
    _discardChangedSession();
  }

  void _discardChangedSession() {
    _deadlineTimer?.cancel();
    _deadlines.clear();
    final dialog = _decisionDialogRoute;
    final navigator = _decisionDialogNavigator;
    _decisionDialogRoute = null;
    _decisionDialogNavigator = null;
    if (dialog != null && navigator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && dialog.isActive) {
          navigator.removeRoute(dialog, false);
        }
      });
    }
    ++_loadGeneration;
    setState(() {
      _loadedSession = null;
      _processingIds.clear();
      _requests = const [];
      _resolvedIds.clear();
      _profileChoices.clear();
      _hasNext = false;
      _loading = false;
      _loadingMore = false;
      _reloadRequired = false;
      _errorText = 'Oturum değişti. Etkinlik davetlerini yeniden aç.';
    });
  }

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? serviceLocator<EventPerformerRequestRepository>();
    _bindSessionListener();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void didUpdateWidget(covariant EventPerformerRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.status != widget.status ||
        oldWidget.targetType != widget.targetType ||
        oldWidget.targetId?.trim() != widget.targetId?.trim() ||
        oldWidget.sessionKeyProvider != widget.sessionKeyProvider ||
        _observedSession != _session) {
      _deadlineTimer?.cancel();
      _deadlines.clear();
      _processingIds.clear();
      _bindSessionListener();
      _repository =
          widget.repository ??
          serviceLocator<EventPerformerRequestRepository>();
      unawaited(_loadFirstPage());
    }
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    _elapsed.stop();
    _sessionManager?.removeListener(_onSessionChanged);
    final dialog = _decisionDialogRoute;
    final navigator = _decisionDialogNavigator;
    if (dialog != null && navigator != null) {
      // A navigation guard can unmount this inbox while confirmation is open.
      // Remove only our own dialog, never unrelated routes above the inbox.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && dialog.isActive) {
          navigator.removeRoute(dialog, false);
        }
      });
    }
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        !_hasNext ||
        _loading ||
        _loadingMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      unawaited(_loadMore());
    }
  }

  List<EventPerformerRequest> get _visibleRequests {
    final filtered = _requests
        .where(
          (request) =>
              request.status == widget.status &&
              !_resolvedIds.contains(request.requestId) &&
              request.targets(type: widget.targetType, id: widget.targetId),
        )
        .toList(growable: false);
    // The server orders by createdAt and UUID. Preserve that tie-break order
    // across pages instead of re-sorting equal timestamps on the client.
    return filtered;
  }

  Future<void> _loadFirstPage({bool showSpinner = true}) async {
    if (!mounted || _processingIds.isNotEmpty) return;
    final generation = ++_loadGeneration;
    final session = _session;
    final hadVisibleRequests = _visibleRequests.isNotEmpty;
    if (mounted) {
      setState(() {
        // Publication is explicit per loaded invitation, never inherited from
        // an earlier response, another profile or a previous login.
        _profileChoices.clear();
        if (showSpinner || _loadedSession != session) {
          _loading = true;
          _requests = const [];
          _nextPage = 0;
          _hasNext = false;
          _reloadRequired = false;
          _resolvedIds.clear();
        }
        _loadingMore = !showSpinner;
        _errorText = null;
        _loadMoreErrorText = null;
      });
    }

    final result = await _fetchPage(0);
    if (!mounted || generation != _loadGeneration) return;
    if (session != _session) {
      _discardChangedSession();
      return;
    }
    final page = result.data;
    final preserveCurrentPage =
        !showSpinner &&
        hadVisibleRequests &&
        (!result.isSuccess || page == null);
    setState(() {
      _loading = false;
      _loadingMore = false;
      if (result.isSuccess && page != null) {
        _profileChoices.clear();
        _loadedSession = session;
        _requests = _deduplicate(page.items);
        _nextPage = page.page + 1;
        _hasNext = page.hasNext;
        _reloadRequired = false;
        _errorText = null;
      } else if (!preserveCurrentPage) {
        _errorText = _friendlyError(result.error);
      } else {
        _reloadRequired = true;
        _loadMoreErrorText = _friendlyError(result.error);
      }
    });
    if (preserveCurrentPage) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(result.error))));
    }
    if (result.isSuccess && _visibleRequests.isEmpty && _hasNext) {
      unawaited(_loadMore(untilVisibleOrExhausted: true));
    }
  }

  Future<void> _loadMore({bool untilVisibleOrExhausted = false}) async {
    if (_loading || _loadingMore || _processingIds.isNotEmpty) return;
    if (_reloadRequired) {
      await _loadFirstPage(showSpinner: false);
      return;
    }
    if (!_hasNext) return;
    final generation = _loadGeneration;
    final session = _session;
    if (_loadedSession != session) {
      _discardChangedSession();
      return;
    }
    setState(() {
      _loadingMore = true;
      _loadMoreErrorText = null;
    });

    var fetchedPages = 0;
    do {
      final requestedPage = _nextPage;
      final result = await _fetchPage(requestedPage);
      if (!mounted || generation != _loadGeneration) return;
      if (session != _session) {
        _discardChangedSession();
        return;
      }
      final page = result.data;
      if (!result.isSuccess || page == null) {
        setState(() {
          _loadingMore = false;
          _loadMoreErrorText = _friendlyError(result.error);
        });
        return;
      }
      if (page.page != requestedPage) {
        setState(() {
          _loadingMore = false;
          _loadMoreErrorText =
              'Etkinlik davetlerinde sayfa sırası doğrulanamadı.';
        });
        return;
      }
      if (page.isOutOfRange) {
        setState(() {
          _loadingMore = false;
          _hasNext = false;
          _reloadRequired = true;
        });
        unawaited(_loadFirstPage(showSpinner: false));
        return;
      }
      setState(() {
        _requests = _deduplicate(<EventPerformerRequest>[
          ..._requests,
          ...page.items,
        ]);
        _nextPage = page.page + 1;
        _hasNext = page.hasNext;
      });
      fetchedPages += 1;
    } while (untilVisibleOrExhausted &&
        _visibleRequests.isEmpty &&
        _hasNext &&
        fetchedPages < _automaticFilteredPageBudget);

    if (mounted && generation == _loadGeneration) {
      setState(() => _loadingMore = false);
    }
  }

  Future<Result<EventPerformerRequestPage>> _fetchPage(int page) async {
    final sentAt = _elapsedNow;
    final generation = _loadGeneration;
    try {
      final result = await _repository.listMine(
        status: widget.status,
        page: page,
        size: _pageSize,
        targetType: widget.targetType,
        targetId: widget.targetId,
      );
      if (mounted && generation == _loadGeneration && result.isSuccess) {
        if (page == 0) _deadlines.clear();
        for (final request in result.data?.items ?? <EventPerformerRequest>[]) {
          _deadlines.remove(_identityOf(request));
          final start = request.eventStartsAt;
          final serverNow = request.serverNow;
          if (start != null && serverNow != null) {
            // Counting the whole request latency is conservative at the deadline.
            _deadlines[_identityOf(request)] =
                sentAt + start.difference(serverNow);
          }
        }
        _scheduleDeadline();
      }
      return result;
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'event_performer_requests_unexpected_failure',
          message: 'Etkinlik davetleri şu anda alınamıyor.',
        ),
      );
    }
  }

  Future<void> _retryFirstPage() =>
      _loadFirstPage(showSpinner: !_reloadRequired);

  List<EventPerformerRequest> _deduplicate(
    Iterable<EventPerformerRequest> requests,
  ) {
    final byId = <String, EventPerformerRequest>{};
    for (final request in requests) {
      byId.putIfAbsent(request.requestId, () => request);
    }
    return List.unmodifiable(byId.values);
  }

  String _friendlyError(AppError? error) {
    final code = error?.code.toLowerCase() ?? '';
    if (code.contains('unauthor') || code.contains('auth')) {
      return 'Etkinlik davetlerini görmek için yeniden giriş yapmalısın.';
    }
    if (code.contains('forbidden') || code.contains('access')) {
      return 'Bu etkinlik davetlerini yönetme yetkin bulunmuyor.';
    }
    return error?.message.trim().isNotEmpty == true
        ? error!.message.trim()
        : 'Etkinlik davetleri şu anda alınamıyor.';
  }

  Future<void> _decide(
    EventPerformerRequest request, {
    required bool accept,
  }) async {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (_loadedSession != _session) {
      _discardChangedSession();
      return;
    }
    if (_processingIds.isNotEmpty ||
        !_canDecide(request) ||
        (_rejected && !accept) ||
        request.status != widget.status ||
        !request.targets(type: widget.targetType, id: widget.targetId) ||
        !_visibleRequests.any(
          (visible) => _identityOf(visible) == _identityOf(request),
        )) {
      return;
    }
    if (accept && request.profileCalendarApproved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(request.incompatibleApprovalExplanation)),
      );
      return;
    }
    final decisionGeneration = _loadGeneration;
    final session = _session;
    final repository = _repository;
    final showOnProfile =
        request.requestPurpose ==
            EventPerformerRequestPurpose.profileVisibility ||
        _profileChoices.contains(_identityOf(request));
    setState(() => _processingIds.add(request.requestId));

    if (!accept) {
      var dialogFinished = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          _decisionDialogRoute = ModalRoute.of<bool>(dialogContext);
          _decisionDialogNavigator = Navigator.of(dialogContext);
          void finish(bool decision) {
            if (dialogFinished ||
                !dialogContext.mounted ||
                ModalRoute.of<bool>(dialogContext)?.isCurrent != true) {
              return;
            }
            dialogFinished = true;
            Navigator.of(dialogContext).pop(decision);
          }

          return EventInvitationRejectionDialog(
            requestId: request.requestId,
            onDecision: finish,
          );
        },
      );
      _decisionDialogRoute = null;
      _decisionDialogNavigator = null;
      if (confirmed != true || !mounted) {
        if (mounted) {
          setState(() => _processingIds.remove(request.requestId));
        }
        return;
      }
      if (!_visibleRequests.any(
        (visible) => _identityOf(visible) == _identityOf(request),
      )) {
        setState(() => _processingIds.remove(request.requestId));
        return;
      }
    }

    if (!mounted) return;
    if (session != _session || decisionGeneration != _loadGeneration) {
      setState(() => _processingIds.remove(request.requestId));
      if (session != _session) _discardChangedSession();
      return;
    }
    Result<void> result;
    if (!_canDecide(request)) {
      setState(() => _processingIds.remove(request.requestId));
      unawaited(_loadFirstPage(showSpinner: false));
      return;
    }
    try {
      result = accept
          ? _rejected
                ? await repository.reconsider(
                    request.requestId,
                    showOnProfile: showOnProfile,
                  )
                : await repository.accept(
                    request.requestId,
                    showOnProfile: showOnProfile,
                  )
          : await repository.reject(request.requestId);
    } catch (_) {
      result = const Result.failure(
        AppError(
          code: 'event_performer_decision_unexpected_failure',
          message: 'Etkinlik onayı güncellenemedi.',
        ),
      );
    }
    if (!mounted) return;
    if (session != _session) {
      setState(() => _processingIds.remove(request.requestId));
      _discardChangedSession();
      return;
    }
    if (decisionGeneration != _loadGeneration) {
      setState(() => _processingIds.remove(request.requestId));
      return;
    }

    setState(() {
      _processingIds.remove(request.requestId);
      if (result.isSuccess) {
        _profileChoices.remove(_identityOf(request));
        _resolvedIds.add(request.requestId);
        _requests = _requests
            .where((item) => item.requestId != request.requestId)
            .toList(growable: false);
        _hasNext = false;
        _reloadRequired = true;
      }
    });

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            request.decisionSuccessMessage(
              accept: accept,
              showOnProfile: showOnProfile,
            ),
          ),
        ),
      );
      unawaited(_loadFirstPage(showSpinner: false));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_friendlyError(result.error))));
    // A timeout may follow a committed decision. Hide old actions until a fresh
    // read completes. Never automatically repeat the mutation.
    unawaited(_loadFirstPage());
  }

  void _setShowOnProfile(
    EventPerformerRequest request,
    bool value,
    int generation,
  ) {
    if (!mounted || !_canDecide(request)) return;
    if (_loadedSession != _session) {
      _discardChangedSession();
      return;
    }
    final identity = _identityOf(request);
    if (generation != _loadGeneration ||
        _processingIds.isNotEmpty ||
        request.profileCalendarApproved == null ||
        request.requestPurpose !=
            EventPerformerRequestPurpose.performerConsent ||
        !_visibleRequests.any((visible) => _identityOf(visible) == identity)) {
      return;
    }
    setState(() {
      if (value) {
        _profileChoices.add(identity);
      } else {
        _profileChoices.remove(identity);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final requests = _visibleRequests;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _rejected ? 'Reddedilen Etkinlikler' : 'Etkinlik Davetleri',
        ),
        centerTitle: true,
      ),
      body: _invitationBody(context, requests),
    );
  }

  Widget _invitationBody(
    BuildContext context,
    List<EventPerformerRequest> requests,
  ) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _loadFirstPage(showSpinner: false),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              sliver: SliverToBoxAdapter(child: _header(context)),
            ),
            if (_loading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Semantics(
                    label: 'Etkinlik davetleri yükleniyor',
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (_errorText != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: _errorText!,
                  onRetry: _retryFirstPage,
                ),
              )
            else if (requests.isEmpty && _loadingMore)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (requests.isEmpty && _loadMoreErrorText != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: _loadMoreErrorText!,
                  onRetry: () => _loadMore(untilVisibleOrExhausted: true),
                ),
              )
            else if (requests.isEmpty && _hasNext)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _FilteredSearchContinuationState(
                  onContinue: () => _loadMore(untilVisibleOrExhausted: true),
                ),
              )
            else if (requests.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(rejected: _rejected),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                sliver: SliverList.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final generation = _loadGeneration;
                    return EventPerformerRequestCard(
                      key: ValueKey(_identityOf(request)),
                      request: request,
                      reconsider: _rejected,
                      expired: _expired(request),
                      decisionAllowed: _canDecide(request),
                      processing: _processingIds.contains(request.requestId),
                      interactionLocked: _processingIds.isNotEmpty,
                      showOnProfile: _profileChoices.contains(
                        _identityOf(request),
                      ),
                      onShowOnProfileChanged: (value) =>
                          _setShowOnProfile(request, value, generation),
                      onAccept: () => _decide(request, accept: true),
                      onReject: () => _decide(request, accept: false),
                    );
                  },
                ),
              ),
            if (!_loading && _errorText == null && requests.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: _LoadMoreFooter(
                    loading: _loadingMore,
                    hasNext: _hasNext || _reloadRequired,
                    errorText: _loadMoreErrorText,
                    onLoadMore: _loadMore,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.brandGradient,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _rejected
                  ? 'Reddettiğin davetleri etkinlik başlamadan önce onaylayabilirsin.'
                  : 'Katılım ve profilde gösterim davetlerini buradan yanıtlayabilirsin.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilteredSearchContinuationState extends StatelessWidget {
  final Future<void> Function() onContinue;

  const _FilteredSearchContinuationState({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            const Text(
              'Bu profil için sonraki onaylar aranabilir',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              'Henüz eşleşen bir onay yüklenmedi. Kalan sayfaları kontrollü '
              'olarak tarayabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('continue-filtered-event-request-search'),
              onPressed: onContinue,
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('Sonraki sayfalarda ara'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.rejected = false});
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              rejected
                  ? 'Reddedilen etkinlik yok'
                  : 'Bekleyen etkinlik daveti yok',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              rejected
                  ? 'Reddettiğin etkinlik davetleri burada görünür.'
                  : 'Yeni bir katılım veya profilde gösterim isteği geldiğinde burada görünür.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('retry-event-performer-requests'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  final bool loading;
  final bool hasNext;
  final String? errorText;
  final Future<void> Function() onLoadMore;

  const _LoadMoreFooter({
    required this.loading,
    required this.hasNext,
    required this.errorText,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final error = errorText?.trim() ?? '';
    if (error.isNotEmpty) {
      return Column(
        children: [
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('retry-more-event-performer-requests'),
            onPressed: onLoadMore,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
          ),
        ],
      );
    }
    if (!hasNext) return const SizedBox.shrink();
    return Center(
      child: TextButton.icon(
        key: const Key('load-more-event-performer-requests'),
        onPressed: onLoadMore,
        icon: const Icon(Icons.expand_more_rounded),
        label: const Text('Daha fazla göster'),
      ),
    );
  }
}
