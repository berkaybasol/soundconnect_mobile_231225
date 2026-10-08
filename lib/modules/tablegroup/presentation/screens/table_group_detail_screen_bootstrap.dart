part of 'table_group_detail_screen.dart';

extension _TableGroupDetailScreenStateBootstrapMethods
    on _TableGroupDetailScreenState {
  Future<void> _bootstrap() {
    final inFlight = _bootstrapInFlight;
    if (inFlight != null) return inFlight;
    final future = _bootstrapInternal();
    _bootstrapInFlight = future;
    return future.whenComplete(() {
      if (identical(_bootstrapInFlight, future)) _bootstrapInFlight = null;
    });
  }

  Future<void> _bootstrapInternal() async {
    _updateView(() {
      _loading = _group == null;
      _error = null;
    });
    try {
      _currentUserId = await resolveCurrentUserId(_tokenStore);
      final detailLoaded = await _loadDetail(replaceScreenOnFailure: true);
      if (!detailLoaded || !mounted) return;
      if (_shouldRunChat) {
        await _loadMessages(reset: true, followLatest: true);
        await _gameCubit.loadActive(exposeError: false);
        await _connectRealtime();
      }
    } catch (_) {
      if (mounted) {
        _updateView(() {
          _error ??= 'Masa detaylari yuklenemedi';
        });
      }
    } finally {
      if (mounted) {
        _updateView(() {
          _loading = false;
        });
      }
    }
  }

  Future<bool> _loadDetail({required bool replaceScreenOnFailure}) async {
    final result = await _repository.getDetail(widget.args.tableGroupId);
    if (!mounted) return false;
    if (!result.isSuccess || result.data == null) {
      final message = result.error?.message ?? 'Masa detayi alinamadi';
      if (replaceScreenOnFailure) {
        _updateView(() => _error = message);
      } else {
        _showSnack(message);
      }
      return false;
    }
    final updatedGroup = result.data!;
    if (!_notificationMatches(updatedGroup)) {
      _updateView(
        () => _error =
            'Bu bildirimin başvuru veya katılım durumu değişti. Güncel sonucu tekrar aç.',
      );
      return false;
    }
    final sessionWillBeActive = isTableGroupSessionActiveAt(
      updatedGroup,
      _now(),
    );
    final hasActiveChatAccess =
        sessionWillBeActive && _isCurrentUserAcceptedIn(updatedGroup);
    final shouldRunChat = hasActiveChatAccess && _showChat;
    _updateView(() {
      _group = updatedGroup;
      if (replaceScreenOnFailure) _error = null;
      if (!shouldRunChat) {
        _messages = const <TableGroupMessage>[];
        _chatHasNext = false;
        _chatLoading = false;
        _chatError = null;
        _realtimeError = null;
        _gameState = const TableGroupGameState.idle();
        _clearGameExpiryRetry();
      }
    });
    _scheduleExpiryTimer();
    if (!shouldRunChat) {
      _gameCubit.clear();
      unawaited(_realtimeClient.disconnect());
    }
    return true;
  }

  Future<void> _loadMessages({
    required bool reset,
    bool followLatest = false,
  }) async {
    if (_chatLoading || !_shouldRunChat) return;
    final loadCompleter = Completer<void>();
    _chatLoadCompleter = loadCompleter;
    final resetSnapshot = reset
        ? <String, TableGroupMessage>{
            for (final message in _messages) message.messageId: message,
          }
        : const <String, TableGroupMessage>{};
    final preserveScrollPosition = !reset && _chatScrollController.hasClients;
    final previousMaxScroll = preserveScrollPosition
        ? _chatScrollController.position.maxScrollExtent
        : 0.0;
    final previousPixels = preserveScrollPosition
        ? _chatScrollController.position.pixels
        : 0.0;
    _updateView(() {
      _chatLoading = true;
      _chatError = null;
    });
    final targetPage = reset ? 0 : _chatPage + 1;
    final target = widget.args.notificationTarget;
    final result = target != null && _shareSession != null
        ? await serviceLocator<NotificationTargetRepository>().tableChat(
            target,
            _shareSession,
            page: targetPage,
          )
        : await _repository.getChatMessages(
            tableGroupId: widget.args.tableGroupId,
            page: targetPage,
            size: 30,
          );
    if (!mounted) {
      _finishChatLoad(loadCompleter);
      return;
    }
    if (!_shouldRunChat) {
      _updateView(() => _chatLoading = false);
      _finishChatLoad(loadCompleter);
      return;
    }
    if (!result.isSuccess || result.data == null) {
      _updateView(() {
        _chatLoading = false;
        _chatRetryReset = reset;
        _chatError = result.error?.message ?? 'Sohbet gecmisi yuklenemedi';
      });
      _finishChatLoad(loadCompleter);
      return;
    }
    final incoming = result.data!;
    _updateView(() {
      final messagesToKeep = reset
          ? _messages.where((message) {
              final baseline = resetSnapshot[message.messageId];
              return baseline == null ||
                  isFresherTableGroupGameMessage(message, baseline);
            })
          : _messages;
      _messages = mergeTableGroupMessagesChronologically(
        existing: messagesToKeep,
        incoming: incoming.items,
      );
      _chatLoaded = true;
      _chatPage = targetPage;
      _chatHasNext = incoming.hasNext;
      _chatLoading = false;
      _chatError = null;
      if (reset &&
          _realtimeClient.isConnected &&
          _realtimeClient.connectedTableGroupId == widget.args.tableGroupId) {
        _realtimeError = null;
      }
    });
    // History is chronological. Feed the newest game first so it is the
    // authoritative fallback when /games/active is temporarily unavailable;
    // the cubit deliberately refuses older pages switching game identity.
    for (final message in incoming.items.reversed) {
      if (message.game != null) _gameCubit.acceptHistoryMessage(message);
    }
    if (followLatest) {
      _scheduleScrollToLatest();
    } else if (preserveScrollPosition) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_chatScrollController.hasClients) return;
        final addedExtent =
            _chatScrollController.position.maxScrollExtent - previousMaxScroll;
        final target = (previousPixels + addedExtent).clamp(
          _chatScrollController.position.minScrollExtent,
          _chatScrollController.position.maxScrollExtent,
        );
        _chatScrollController.jumpTo(target);
      });
    }
    _finishChatLoad(loadCompleter);
  }

  void _finishChatLoad(Completer<void> completer) {
    if (identical(_chatLoadCompleter, completer)) {
      _chatLoadCompleter = null;
    }
    if (!completer.isCompleted) completer.complete();
  }

  void _onRealtimeMsg(TableGroupMessage message) {
    if (!_shouldRunChat || message.tableGroupId != widget.args.tableGroupId) {
      return;
    }
    if (!mounted) return;
    if (message.game != null) _gameCubit.acceptRealtimeMessage(message);
    final followLatest = _isNearLatest;
    _updateView(() {
      if (_realtimeClient.isConnected &&
          _realtimeClient.connectedTableGroupId == widget.args.tableGroupId) {
        _realtimeError = null;
      }
      _messages = mergeTableGroupMessagesChronologically(
        existing: _messages,
        incoming: <TableGroupMessage>[message],
      );
    });
    if (followLatest) _scheduleScrollToLatest();
  }

  void _onGameState(TableGroupGameState state) {
    if (!mounted) return;
    final followLatest = _isNearLatest;
    final previousMessage = _gameState.message;
    final previousGame = _gameState.game;
    final nextGame = state.game;
    final messageChanged = !identical(previousMessage, state.message);
    if (previousGame?.gameId != nextGame?.gameId ||
        previousGame?.revision != nextGame?.revision ||
        previousGame?.phase != nextGame?.phase ||
        previousGame?.phaseDeadline != nextGame?.phaseDeadline) {
      _clearGameExpiryRetry();
    }
    _updateView(() {
      _gameState = state;
      final message = state.message;
      if (_shouldRunChat && messageChanged && message != null) {
        _messages = mergeTableGroupMessagesChronologically(
          existing: _messages,
          incoming: <TableGroupMessage>[message],
        );
      }
    });
    if (followLatest && messageChanged && state.message != null) {
      _scheduleScrollToLatest();
    }
  }

  void _onRealtimeConnected(void _) {
    if (!mounted ||
        !_shouldRunChat ||
        _realtimeClient.connectedTableGroupId != widget.args.tableGroupId) {
      return;
    }
    final shouldReconcile = _realtimeError != null;
    if (shouldReconcile && _shouldRunChat) {
      _queueReconnectReconciliation();
    } else {
      _updateView(() => _realtimeError = null);
    }
  }

  void _queueReconnectReconciliation() {
    if (_reconciliationInFlight != null) return;
    final future = _reconcileAfterReconnect();
    _reconciliationInFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_reconciliationInFlight, future)) {
          _reconciliationInFlight = null;
        }
      }),
    );
  }

  Future<void> _reconcileAfterReconnect() async {
    final currentLoad = _chatLoadCompleter;
    if (currentLoad != null) await currentLoad.future;
    if (!mounted || !_shouldRunChat) return;
    await _loadMessages(reset: true, followLatest: _isNearLatest);
    await _gameCubit.loadActive(exposeError: false);
    if (!mounted || !_shouldRunChat || _chatError != null) return;
    if (_realtimeClient.isConnected &&
        _realtimeClient.connectedTableGroupId == widget.args.tableGroupId) {
      _updateView(() => _realtimeError = null);
    }
  }

  void _onRealtimeError(RealtimeClientError error) {
    if (!mounted || !_shouldRunChat) return;
    _updateView(() {
      _realtimeError = switch (error.type) {
        RealtimeClientErrorType.invalidPayload =>
          'Canli sohbetten gecersiz bir mesaj alindi.',
        RealtimeClientErrorType.disconnected =>
          'Canli baglanti kesildi. Yeniden baglanmayi deniyoruz.',
        RealtimeClientErrorType.timeout =>
          'Canli sohbet baglantisi zaman asimina ugradi.',
        _ => 'Canli sohbet baglantisi kurulamadi.',
      };
    });
  }

  Future<void> _connectRealtime() async {
    if (_connectingRealtime || !_shouldRunChat) return;
    final token = await readAuthToken(_tokenStore);
    if (!mounted || !_shouldRunChat) return;
    if (token == null || token.trim().isEmpty) {
      _updateView(() {
        _realtimeError = 'Canli sohbet icin oturum bilgisi bulunamadi.';
      });
      return;
    }
    _updateView(() => _connectingRealtime = true);
    try {
      await _realtimeClient.connect(
        tableGroupId: widget.args.tableGroupId,
        token: token,
      );
      if (!mounted) return;
      if (!_shouldRunChat) {
        await _realtimeClient.disconnect();
        return;
      }
    } catch (_) {
      if (mounted) {
        _updateView(() {
          _realtimeError ??= 'Canli sohbet baglantisi kurulamadi.';
        });
      }
    } finally {
      if (mounted) _updateView(() => _connectingRealtime = false);
    }
  }

  Future<void> _recoverRealtime() async {
    if (!_shouldRunChat) return;
    if (_realtimeClient.isConnected &&
        _realtimeClient.connectedTableGroupId == widget.args.tableGroupId) {
      await _loadMessages(reset: true, followLatest: _isNearLatest);
      await _gameCubit.loadActive(exposeError: false);
      return;
    }
    await _connectRealtime();
  }

  Future<void> _resumeFromBackground() async {
    final inFlight = _resumeInFlight;
    if (inFlight != null) return inFlight;
    final future = _resumeFromBackgroundInternal();
    _resumeInFlight = future;
    return future.whenComplete(() {
      if (identical(_resumeInFlight, future)) _resumeInFlight = null;
    });
  }

  Future<void> _resumeFromBackgroundInternal() async {
    if (widget.args.notificationTarget != null &&
        (_error != null || _chatError != null)) {
      return;
    }
    if (_bootstrapInFlight != null || _group == null) return;
    final detailLoaded = await _loadDetail(replaceScreenOnFailure: false);
    if (!detailLoaded || !mounted || !_shouldRunChat) {
      await _realtimeClient.disconnect();
      return;
    }
    final followLatest = _isNearLatest;
    await _loadMessages(reset: true, followLatest: followLatest);
    await _gameCubit.loadActive(exposeError: false);
    if (!_realtimeClient.isConnected ||
        _realtimeClient.connectedTableGroupId != widget.args.tableGroupId) {
      await _connectRealtime();
    }
  }

  bool get _isNearLatest {
    if (!_chatScrollController.hasClients) return true;
    final position = _chatScrollController.position;
    return position.maxScrollExtent - position.pixels <= 96;
  }

  void _scheduleScrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  TableGroupParticipantStatus? get _myStatus {
    final userId = _currentUserId;
    if (userId == null || _group == null) return null;
    for (final p in _group!.participants) {
      if (p.userId == userId) return p.status;
    }
    return null;
  }

  bool get _isOwner =>
      _group != null &&
      _currentUserId != null &&
      _group!.ownerId == _currentUserId;

  bool get _isAccepted =>
      _isOwner || _myStatus == TableGroupParticipantStatus.accepted;

  bool get _canShareOnProfile =>
      !_loading &&
      _error == null &&
      !_sessionActionInFlight &&
      _isSessionActive &&
      _isAccepted &&
      canPublishListenerProfile(_shareSession) &&
      identical(_shareSessions?.session, _shareSession) &&
      _shareSession?.userId == _currentUserId;

  void _updateProfileShareSession() {
    if (mounted) _updateView(() {});
  }

  Future<void> _openProfileDraft() async {
    if (!_canShareOnProfile || _profileDraftOpening) return;
    _updateView(() => _profileDraftOpening = true);
    try {
      await openTableGroupProfileDraft(
        context,
        tableGroupId: widget.args.tableGroupId,
        expectedSession: _shareSession!,
        sessions: _shareSessions,
      );
    } finally {
      if (mounted) _updateView(() => _profileDraftOpening = false);
    }
  }

  bool _isCurrentUserAcceptedIn(TableGroup group) {
    final userId = _currentUserId;
    if (userId == null || userId.trim().isEmpty) return false;
    if (group.ownerId == userId) return true;
    return group.participants.any(
      (participant) =>
          participant.userId == userId &&
          participant.status == TableGroupParticipantStatus.accepted,
    );
  }

  bool get _isSessionActive => isTableGroupSessionActiveAt(_group, _now());

  bool get _hasActiveChatAccess => _isAccepted && _isSessionActive;

  bool get _shouldRunChat =>
      _showChat &&
      _hasActiveChatAccess &&
      (widget.args.notificationTarget == null ||
          (_notificationSessionCurrent &&
              _error == null &&
              ModalRoute.of(context)?.isCurrent == true &&
              (WidgetsBinding.instance.lifecycleState == null ||
                  WidgetsBinding.instance.lifecycleState ==
                      AppLifecycleState.resumed)));

  bool get _isTableFull {
    final group = _group;
    if (group == null || group.maxPersonCount <= 0) return false;
    return group.acceptedCount >= group.maxPersonCount;
  }

  bool get _canCreateOrJoin {
    try {
      final override = widget.canCreateOrJoin;
      if (override != null) return override();
      return AccessPolicy.canCreateOrJoinTableGroups(
        serviceLocator<AuthSessionManager>().session.roles,
      );
    } catch (_) {
      return false;
    }
  }

  void _scheduleExpiryTimer() {
    _expiryTimer?.cancel();
    final delay = tableGroupTimeUntilExpiry(_group, _now());
    if (delay == null) return;
    _expiryTimer = Timer(delay, _handleExpiry);
  }

  void _handleExpiry() {
    if (!mounted) return;
    _updateView(() {
      _messages = const <TableGroupMessage>[];
      _chatHasNext = false;
      _chatLoading = false;
      _chatError = null;
      _realtimeError = null;
      _sending = false;
      _retryableChatContent = null;
      _retryableChatClientMessageId = null;
      _sessionActionInFlight = false;
      _ownerActionInFlightIds.clear();
      _gameState = const TableGroupGameState.idle();
      _clearGameExpiryRetry();
    });
    _gameCubit.clear();
    unawaited(_realtimeClient.disconnect());
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    if (!_shouldRunChat) {
      _showSnack(
        'Bu masa sona erdigi icin mesaj gonderilemez',
        tone: AppSnackBarTone.warning,
      );
      return;
    }
    final content = _chatController.text.trim();
    if (content.isEmpty) return;
    if (content.length > 1000) {
      _showSnack(
        'Mesaj en fazla 1000 karakter olabilir',
        tone: AppSnackBarTone.warning,
      );
      return;
    }
    _updateView(() {
      _sending = true;
    });
    final retryingSameContent =
        _retryableChatContent == content &&
        _retryableChatClientMessageId != null;
    final clientMessageId = retryingSameContent
        ? _retryableChatClientMessageId!
        : _chatRequestIdFactory();
    _retryableChatContent = content;
    _retryableChatClientMessageId = clientMessageId;
    final result = await _repository.sendChatMessage(
      tableGroupId: widget.args.tableGroupId,
      content: content,
      clientMessageId: clientMessageId,
    );
    if (!mounted) return;
    _updateView(() {
      _sending = false;
    });
    if (!_shouldRunChat) return;
    if (!result.isSuccess || result.data == null) {
      _showSnack(result.error?.message ?? 'Mesaj gonderilemedi');
      return;
    }
    if (_retryableChatClientMessageId == clientMessageId) {
      _retryableChatContent = null;
      _retryableChatClientMessageId = null;
    }
    if (_chatController.text.trim() == content) {
      _chatController.clear();
    }
    _updateView(() {
      _messages = mergeTableGroupMessagesChronologically(
        existing: _messages,
        incoming: <TableGroupMessage>[result.data!],
      );
    });
    _scheduleScrollToLatest();
  }

  Future<void> _openGameLauncher() async {
    if (!_shouldRunChat ||
        _gameLauncherOpen ||
        _gameState.loading ||
        _gameState.actionInFlight) {
      return;
    }
    final activeGame = _gameState.game;
    if (activeGame != null && !activeGame.isTerminal) {
      _showSnack(
        'Masada zaten aktif bir oyun var.',
        tone: AppSnackBarTone.warning,
      );
      return;
    }
    _updateView(() => _gameLauncherOpen = true);
    try {
      final mode = await showTableGroupGameLauncherSheet(context);
      if (!mounted || mode == null || !_shouldRunChat) return;
      final latestGame = _gameState.game;
      if (_gameState.loading ||
          (latestGame != null && !latestGame.isTerminal)) {
        _showSnack(
          'Oyun durumu değişti; tekrar deneyebilirsin.',
          tone: AppSnackBarTone.warning,
        );
        return;
      }
      final message = await _gameCubit.create(mode);
      if (!mounted) return;
      if (message == null) {
        _showGameError('Oyun başlatılamadı');
        return;
      }
      _scheduleScrollToLatest();
    } finally {
      if (mounted) _updateView(() => _gameLauncherOpen = false);
    }
  }

  Future<void> _joinGame(TableGroupGame game) async {
    final message = await _gameCubit.join(game.gameId);
    if (!mounted || message != null) return;
    _showGameError('Oyuna katılınamadı');
  }

  Future<void> _leaveGame(TableGroupGame game) async {
    final message = await _gameCubit.leave(game.gameId);
    if (!mounted || message != null) return;
    _showGameError('Oyundan ayrılınamadı');
  }

  Future<void> _startGame(TableGroupGame game) async {
    final message = await _gameCubit.start(game.gameId);
    if (!mounted || message != null) return;
    _showGameError('Oyun başlatılamadı');
  }

  Future<void> _cancelGame(TableGroupGame game) async {
    final confirmed = await _confirmSessionAction(
      title: 'Oyun iptal edilsin mi?',
      message: 'Aktif oyun herkes için sona erecek.',
      confirmLabel: 'Oyunu İptal Et',
    );
    if (!confirmed || !mounted) return;
    final message = await _gameCubit.cancel(game.gameId);
    if (!mounted || message != null) return;
    _showGameError('Oyun iptal edilemedi');
  }

  Future<void> _submitGameAction(
    TableGroupGame game,
    TableGroupGameAction action,
    String? targetUserId,
  ) async {
    final message = await _gameCubit.act(
      gameId: game.gameId,
      action: action,
      targetUserId: targetUserId,
    );
    if (!mounted || message != null) return;
    _showGameError('Hamle gönderilemedi');
  }

  void _reconcileExpiredGame(TableGroupGame game) {
    unawaited(_reconcileExpiredGameInternal(game));
  }

  Future<void> _reconcileExpiredGameInternal(TableGroupGame game) async {
    final retryToken = _gameExpiryToken(game);
    if (_gameExpiryRetryToken == retryToken) return;
    final current = _gameState.game;
    if (!_shouldRunChat ||
        current == null ||
        current.gameId != game.gameId ||
        current.revision != game.revision ||
        current.isTerminal) {
      return;
    }
    final refreshSucceeded = await _gameCubit.refreshGame(game.gameId);
    if (!mounted || !_shouldRunChat) return;
    final refreshed = _gameState.game;
    if (refreshed == null ||
        refreshed.gameId != game.gameId ||
        refreshed.revision != game.revision ||
        refreshed.isTerminal ||
        !_shouldRetryExpiredSnapshot(
          original: game,
          refreshed: refreshed,
          refreshSucceeded: refreshSucceeded,
        )) {
      return;
    }
    if (_gameExpiryRetryToken == retryToken) return;
    _gameExpiryRetryToken = retryToken;
    _gameExpiryRetryTimer?.cancel();
    _gameExpiryRetryTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || !_shouldRunChat) return;
      final latest = _gameState.game;
      if (latest == null ||
          latest.gameId != game.gameId ||
          latest.revision != game.revision ||
          latest.phase != game.phase ||
          latest.phaseDeadline != game.phaseDeadline ||
          latest.isTerminal) {
        return;
      }
      unawaited(_gameCubit.refreshGame(game.gameId));
    });
  }

  bool _shouldRetryExpiredSnapshot({
    required TableGroupGame original,
    required TableGroupGame refreshed,
    required bool refreshSucceeded,
  }) {
    final deadline = original.phaseDeadline;
    if (deadline == null ||
        refreshed.phase != original.phase ||
        refreshed.phaseDeadline != deadline) {
      return false;
    }
    if (!refreshSucceeded) return true;
    final refreshedServerTime = refreshed.serverTime;
    if (refreshedServerTime == null ||
        refreshedServerTime == original.serverTime) {
      // An exact snapshot cannot disprove the countdown's expiry observation.
      return true;
    }
    return !deadline.isAfter(refreshedServerTime);
  }

  String _gameExpiryToken(TableGroupGame game) =>
      '${game.gameId}:${game.revision}:${game.phase.name}:'
      '${game.phaseDeadline?.microsecondsSinceEpoch ?? -1}';

  void _clearGameExpiryRetry() {
    _gameExpiryRetryTimer?.cancel();
    _gameExpiryRetryTimer = null;
    _gameExpiryRetryToken = null;
  }

  void _showGameError(String fallback) {
    _showSnack(_gameCubit.state.error?.message ?? fallback);
  }
}
