import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/access_policy.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../core/realtime/realtime_client_error.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../dm/data/dm_auth_support.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../../dm/presentation/dm_profile_navigation.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../data/table_group_chat_realtime_client.dart';
import '../../domain/entities/table_group.dart';
import '../../domain/entities/table_group_game.dart';
import '../../domain/entities/table_group_message.dart';
import '../../domain/entities/table_group_participant.dart';
import '../../domain/table_group_lifecycle.dart';
import '../../domain/table_group_expiry_policy.dart';
import '../../domain/table_group_game_repository.dart';
import '../../domain/table_group_message_timeline.dart';
import '../../domain/table_group_repository.dart';
import '../cubit/table_group_game_cubit.dart';
import '../cubit/table_group_game_state.dart';
import '../widgets/table_group_game_launcher_sheet.dart';
import '../widgets/table_group_game_message_card.dart';
import '../widgets/table_group_overview_style.dart';

class TableGroupDetailArgs {
  final String tableGroupId;
  final StageMode bottomBarStageMode;
  final bool openChat;

  const TableGroupDetailArgs({
    required this.tableGroupId,
    this.bottomBarStageMode = StageMode.backstage,
    this.openChat = true,
  });
}

class TableGroupDetailScreen extends StatefulWidget {
  final TableGroupDetailArgs args;
  final TableGroupRepository? repository;
  final TableGroupGameRepository? gameRepository;
  final TokenStore? tokenStore;
  final TableGroupChatRealtimeClient? realtimeClient;
  final DateTime Function()? now;
  final bool Function()? canCreateOrJoin;
  final String Function()? chatRequestIdFactory;

  const TableGroupDetailScreen({
    super.key,
    required this.args,
    this.repository,
    this.gameRepository,
    this.tokenStore,
    this.realtimeClient,
    this.now,
    this.canCreateOrJoin,
    this.chatRequestIdFactory,
  });

  @override
  State<TableGroupDetailScreen> createState() => _TableGroupDetailScreenState();
}

class _TableGroupDetailScreenState extends State<TableGroupDetailScreen>
    with WidgetsBindingObserver {
  late final TableGroupRepository _repository;
  late final TableGroupGameCubit _gameCubit;
  late final TokenStore _tokenStore;
  late final TableGroupChatRealtimeClient _realtimeClient;
  late final bool _ownsRealtimeClient;
  late final String Function() _chatRequestIdFactory;
  late final DateTime Function() _now;
  late final TableGroupLocalDayRefreshScheduler _dayRefreshScheduler;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  StreamSubscription<TableGroupMessage>? _messageSubscription;
  StreamSubscription<void>? _connectionSubscription;
  StreamSubscription<RealtimeClientError>? _realtimeErrorSubscription;
  StreamSubscription<TableGroupGameState>? _gameStateSubscription;
  Future<void>? _bootstrapInFlight;
  Future<void>? _resumeInFlight;
  Future<void>? _reconciliationInFlight;
  Completer<void>? _chatLoadCompleter;
  Timer? _expiryTimer;
  Timer? _gameExpiryRetryTimer;
  String? _gameExpiryRetryToken;
  bool _loading = true;
  bool _chatLoading = false;
  bool _chatRetryReset = true;
  bool _connectingRealtime = false;
  bool _sending = false;
  bool _joinInFlight = false;
  bool _sessionActionInFlight = false;
  bool _gameLauncherOpen = false;
  late bool _showChat;
  String? _error;
  String? _chatError;
  String? _realtimeError;
  String? _currentUserId;
  String? _retryableChatContent;
  String? _retryableChatClientMessageId;
  TableGroup? _group;
  List<TableGroupMessage> _messages = const [];
  TableGroupGameState _gameState = const TableGroupGameState.idle();
  bool _chatHasNext = false;
  int _chatPage = 0;
  final Set<String> _ownerActionInFlightIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = widget.repository ?? serviceLocator<TableGroupRepository>();
    _showChat = widget.args.openChat;
    _tokenStore = widget.tokenStore ?? serviceLocator<TokenStore>();
    _ownsRealtimeClient = widget.realtimeClient == null;
    _realtimeClient = widget.realtimeClient ?? TableGroupChatRealtimeClient();
    _chatRequestIdFactory = widget.chatRequestIdFactory ?? const Uuid().v4;
    _now = widget.now ?? DateTime.now;
    _dayRefreshScheduler = TableGroupLocalDayRefreshScheduler(
      now: _now,
      onRefresh: () {
        if (mounted) setState(() {});
      },
    )..start();
    _gameCubit = TableGroupGameCubit(
      repository:
          widget.gameRepository ?? serviceLocator<TableGroupGameRepository>(),
      tableGroupId: widget.args.tableGroupId,
    );
    _gameStateSubscription = _gameCubit.stream.listen(_onGameState);
    _messageSubscription = _realtimeClient.messageStream.listen(_onRealtimeMsg);
    _connectionSubscription = _realtimeClient.connectionStream.listen(
      _onRealtimeConnected,
    );
    _realtimeErrorSubscription = _realtimeClient.errorStream.listen(
      _onRealtimeError,
    );
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayRefreshScheduler.dispose();
    _expiryTimer?.cancel();
    _gameExpiryRetryTimer?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _realtimeErrorSubscription?.cancel();
    _gameStateSubscription?.cancel();
    unawaited(_gameCubit.close());
    if (_ownsRealtimeClient) {
      unawaited(_realtimeClient.dispose());
    } else {
      unawaited(_realtimeClient.disconnect());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _dayRefreshScheduler.reschedule(refresh: true);
      unawaited(_resumeFromBackground());
    }
  }

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
    setState(() {
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
        setState(() {
          _error ??= 'Masa detaylari yuklenemedi';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
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
        setState(() => _error = message);
      } else {
        _showSnack(message);
      }
      return false;
    }
    final updatedGroup = result.data!;
    final sessionWillBeActive = isTableGroupSessionActiveAt(
      updatedGroup,
      _now(),
    );
    final hasActiveChatAccess =
        sessionWillBeActive && _isCurrentUserAcceptedIn(updatedGroup);
    final shouldRunChat = hasActiveChatAccess && _showChat;
    setState(() {
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
    setState(() {
      _chatLoading = true;
      _chatError = null;
    });
    final targetPage = reset ? 0 : _chatPage + 1;
    final result = await _repository.getChatMessages(
      tableGroupId: widget.args.tableGroupId,
      page: targetPage,
      size: 30,
    );
    if (!mounted) {
      _finishChatLoad(loadCompleter);
      return;
    }
    if (!_shouldRunChat) {
      setState(() => _chatLoading = false);
      _finishChatLoad(loadCompleter);
      return;
    }
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _chatLoading = false;
        _chatRetryReset = reset;
        _chatError = result.error?.message ?? 'Sohbet gecmisi yuklenemedi';
      });
      _finishChatLoad(loadCompleter);
      return;
    }
    final incoming = result.data!;
    setState(() {
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
    setState(() {
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
    setState(() {
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
      setState(() => _realtimeError = null);
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
      setState(() => _realtimeError = null);
    }
  }

  void _onRealtimeError(RealtimeClientError error) {
    if (!mounted || !_shouldRunChat) return;
    setState(() {
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
      setState(() {
        _realtimeError = 'Canli sohbet icin oturum bilgisi bulunamadi.';
      });
      return;
    }
    setState(() => _connectingRealtime = true);
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
        setState(() {
          _realtimeError ??= 'Canli sohbet baglantisi kurulamadi.';
        });
      }
    } finally {
      if (mounted) setState(() => _connectingRealtime = false);
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

  bool get _shouldRunChat => _showChat && _hasActiveChatAccess;

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
    setState(() {
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
      _showSnack('Bu masa sona erdigi icin mesaj gonderilemez');
      return;
    }
    final content = _chatController.text.trim();
    if (content.isEmpty) return;
    if (content.length > 1000) {
      _showSnack('Mesaj en fazla 1000 karakter olabilir');
      return;
    }
    setState(() {
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
    setState(() {
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
    setState(() {
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
      _showSnack('Masada zaten aktif bir oyun var.');
      return;
    }
    setState(() => _gameLauncherOpen = true);
    try {
      final mode = await showTableGroupGameLauncherSheet(context);
      if (!mounted || mode == null || !_shouldRunChat) return;
      final latestGame = _gameState.game;
      if (_gameState.loading ||
          (latestGame != null && !latestGame.isTerminal)) {
        _showSnack('Oyun durumu değişti; tekrar deneyebilirsin.');
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
      if (mounted) setState(() => _gameLauncherOpen = false);
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

  Future<void> _join() async {
    if (_joinInFlight || !_isSessionActive) return;
    if (!_canCreateOrJoin) {
      _showSnack(
        'Masa oluşturma ve katılma işlemleri kişisel hesaplarla kullanılabilir.',
      );
      return;
    }
    final submission = await showDialog<_JoinDialogSubmission>(
      context: context,
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.76),
      builder: (context) => const _PremiumJoinDialog(),
    );
    if (submission == null) return;
    final note = submission.note.trim();
    if (!mounted) return;
    setState(() => _joinInFlight = true);
    try {
      final result = await _repository.joinTableGroup(
        tableGroupId: widget.args.tableGroupId,
        note: note,
      );
      if (!mounted) return;
      _showSnack(
        result.isSuccess
            ? 'Katılma isteği gönderildi'
            : (result.error?.message ?? 'Islem basarisiz'),
      );
      if (result.isSuccess) {
        await _loadDetail(replaceScreenOnFailure: false);
      }
    } finally {
      if (mounted) setState(() => _joinInFlight = false);
    }
  }

  Future<void> _runOwnerAction({
    required String participantId,
    required Future<bool> Function() fn,
  }) async {
    if (!_hasActiveChatAccess ||
        _ownerActionInFlightIds.contains(participantId)) {
      return;
    }
    setState(() {
      _ownerActionInFlightIds.add(participantId);
    });
    try {
      final succeeded = await fn();
      if (succeeded) {
        await _loadDetail(replaceScreenOnFailure: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _ownerActionInFlightIds.remove(participantId);
        });
      }
    }
  }

  Future<bool> _approve(String participantId) async {
    if (!_hasActiveChatAccess) return false;
    final result = await _repository.approveJoinRequest(
      tableGroupId: widget.args.tableGroupId,
      participantId: participantId,
    );
    if (!mounted) return false;
    _showSnack(
      result.isSuccess
          ? 'Onaylandi'
          : (result.error?.message ?? 'Islem basarisiz'),
    );
    return result.isSuccess;
  }

  Future<bool> _reject(String participantId) async {
    if (!_hasActiveChatAccess) return false;
    final result = await _repository.rejectJoinRequest(
      tableGroupId: widget.args.tableGroupId,
      participantId: participantId,
    );
    if (!mounted) return false;
    _showSnack(
      result.isSuccess
          ? 'Reddedildi'
          : (result.error?.message ?? 'Islem basarisiz'),
    );
    return result.isSuccess;
  }

  Future<void> _confirmKickParticipant(
    TableGroupParticipant participant,
  ) async {
    if (!_isOwner ||
        !_hasActiveChatAccess ||
        participant.userId == _group?.ownerId ||
        _ownerActionInFlightIds.contains(participant.userId)) {
      return;
    }
    final confirmed = await _confirmSessionAction(
      title: 'Katilimciyi masadan cikar',
      message:
          '${_participantDisplayName(participant)} bu masadan ve sohbetten '
          'cikarilacak.',
      confirmLabel: 'Masadan Cikar',
    );
    if (!confirmed || !mounted) return;
    await _runOwnerAction(
      participantId: participant.userId,
      fn: () => _kick(participant.userId),
    );
  }

  Future<bool> _kick(String participantId) async {
    if (!_isOwner ||
        !_hasActiveChatAccess ||
        participantId == _group?.ownerId) {
      return false;
    }
    final result = await _repository.kickParticipant(
      tableGroupId: widget.args.tableGroupId,
      participantId: participantId,
    );
    if (!mounted) return false;
    _showSnack(
      result.isSuccess
          ? 'Katilimci masadan cikarildi'
          : (result.error?.message ?? 'Katilimci cikarilamadi'),
    );
    return result.isSuccess;
  }

  Future<void> _leave() async {
    if (_sessionActionInFlight || !_hasActiveChatAccess) return;
    final confirmed = await _confirmSessionAction(
      title: 'Masadan ayrıl',
      message: 'Masadan ayrıldığında bu sohbete erişimin sona erecek.',
      confirmLabel: 'Ayrıl',
    );
    if (!confirmed || !mounted) return;
    setState(() => _sessionActionInFlight = true);
    try {
      final result = await _repository.leaveTableGroup(
        tableGroupId: widget.args.tableGroupId,
      );
      if (!mounted) return;
      if (!result.isSuccess) {
        _showSnack(result.error?.message ?? 'Masadan ayrılamadı');
        return;
      }
      _showSnack('Masadan ayrıldın');
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _sessionActionInFlight = false);
    }
  }

  Future<void> _cancelTable() async {
    if (_sessionActionInFlight || !_hasActiveChatAccess) return;
    final confirmed = await _confirmSessionAction(
      title: 'Oturumu sonlandir',
      message: 'Oturum sonlandirilacak ve katilimcilar sohbete erisemeyecek.',
      confirmLabel: 'Sonlandir',
    );
    if (!confirmed || !mounted) return;
    setState(() => _sessionActionInFlight = true);
    try {
      final result = await _repository.cancelTableGroup(
        tableGroupId: widget.args.tableGroupId,
      );
      if (!mounted) return;
      if (!result.isSuccess) {
        _showSnack(result.error?.message ?? 'Masa sonlandirilamadi');
        return;
      }
      _showSnack('Masa iptal edildi');
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _sessionActionInFlight = false);
    }
  }

  Future<bool> _confirmSessionAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.76),
      builder: (context) => _PremiumConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      ),
    );
    return confirmed == true;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final description = _tableDescription(group);
    final showOverview =
        group != null && _isSessionActive && (!_isAccepted || !_showChat);
    final showMoreMenu =
        group != null &&
        (showOverview || (_isSessionActive && (_isOwner || _isAccepted)));
    return TableGroupOverviewBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 56,
          leadingWidth: 56,
          titleSpacing: 12,
          title: const Text(
            'Masa Detayı',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: TableGroupOverviewStyle.headingMuted,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (!showOverview)
              IconButton(
                tooltip: 'Yenile',
                onPressed: _loading ? null : _bootstrap,
                icon: const Icon(Icons.refresh_rounded),
              ),
            if (showMoreMenu)
              PopupMenuButton<_DetailMenuAction>(
                key: const Key('table_group_detail_more'),
                tooltip: 'Diğer seçenekler',
                onSelected: _handleDetailMenuAction,
                itemBuilder: (context) => <PopupMenuEntry<_DetailMenuAction>>[
                  if (showOverview)
                    const PopupMenuItem<_DetailMenuAction>(
                      value: _DetailMenuAction.refresh,
                      child: Text('Yenile'),
                    ),
                  if (_isOwner && _isSessionActive)
                    const PopupMenuItem<_DetailMenuAction>(
                      value: _DetailMenuAction.closeTable,
                      child: Text('Masayı kapat'),
                    )
                  else if (_isAccepted && _isSessionActive)
                    const PopupMenuItem<_DetailMenuAction>(
                      value: _DetailMenuAction.leaveTable,
                      child: Text('Masadan ayrıl'),
                    ),
                ],
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _bootstrap,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              )
            : group == null
            ? const Center(child: Text('Masa bulunamadi'))
            : !_isSessionActive
            ? _closedSessionPanel(group)
            : showOverview
            ? _detailOverview(group, description)
            : _isAccepted
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    if (description != null) ...[
                      _tableDescriptionCard(description),
                      const SizedBox(height: 12),
                    ],
                    Expanded(child: _chatPanel(fullScreen: true)),
                  ],
                ),
              )
            : const SizedBox.shrink(),
        bottomNavigationBar: showOverview
            ? _overviewBottomBar(
                group,
                includePublicNavigation: !widget.args.openChat,
              )
            : null,
      ),
    );
  }

  void _handleDetailMenuAction(_DetailMenuAction action) {
    switch (action) {
      case _DetailMenuAction.refresh:
        unawaited(_bootstrap());
        break;
      case _DetailMenuAction.closeTable:
        unawaited(_cancelTable());
        break;
      case _DetailMenuAction.leaveTable:
        unawaited(_leave());
        break;
    }
  }

  Future<void> _openChat() async {
    if (_showChat || !_hasActiveChatAccess) return;
    setState(() => _showChat = true);
    await _loadMessages(reset: true, followLatest: true);
    if (!mounted || !_shouldRunChat) return;
    await _gameCubit.loadActive(exposeError: false);
    if (!mounted || !_shouldRunChat) return;
    await _connectRealtime();
  }

  Widget _detailOverview(TableGroup group, String? description) {
    return RefreshIndicator(
      onRefresh: _bootstrap,
      child: ListView(
        key: const Key('table_group_detail_overview'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(15, 8, 15, 28),
        children: [
          _detailSummaryCard(group, description),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 10),
            child: _DetailSectionTitle('Masa Hakkında'),
          ),
          const SizedBox(height: 10),
          if (description != null)
            _tableDescriptionCard(description, showInlineTitle: false)
          else
            const _DetailEmptyInfoCard('Bu masa için açıklama eklenmemiş.'),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: _DetailSectionTitle('Katılımcılar'),
                ),
              ),
              _DetailCountPill(
                text: '${group.acceptedCount}/${group.maxPersonCount}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _detailParticipantsCard(group),
        ],
      ),
    );
  }

  Widget _overviewBottomBar(
    TableGroup group, {
    required bool includePublicNavigation,
  }) {
    final action = _overviewAction(group);
    return Material(
      color: TableGroupOverviewStyle.pageBase,
      elevation: 18,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 16, 15, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        action.message,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: TableGroupOverviewStyle.bodyMuted,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailStickyAction(action),
                ],
              ),
            ),
            if (includePublicNavigation)
              ProfilePublicBottomBar(
                currentIndex: 2,
                stageMode: widget.args.bottomBarStageMode,
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailSummaryCard(TableGroup group, String? description) {
    final ownerName = _detailOwnerUsername(group);
    final ownerAvatar = _validUrlOrNull(group.ownerProfileImageUrl);
    return Container(
      key: const Key('table_group_detail_summary'),
      decoration: BoxDecoration(
        gradient: TableGroupOverviewStyle.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TableGroupOverviewStyle.cardBorder),
        boxShadow: TableGroupOverviewStyle.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description ?? 'Masa buluşması',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TableGroupOverviewStyle.primaryText,
                    fontSize: 21,
                    height: 1.16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _DetailAvatar(
                      imageUrl: ownerAvatar,
                      initials: _initialsFrom(ownerName),
                      size: 58,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ownerName.startsWith('@')
                                ? ownerName
                                : '@$ownerName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: TableGroupOverviewStyle.headingMuted,
                              fontSize: 16,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Masa sahibi',
                            style: TextStyle(
                              color: TableGroupOverviewStyle.tertiaryText,
                              fontSize: 14,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: TableGroupOverviewStyle.bodyMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _detailLocationLabel(group),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: TableGroupOverviewStyle.bodyMuted,
                                    fontSize: 14,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            child: _DetailStatsStrip(
              group: group,
              timeText: _meetingTimeOf(group.meetingAt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailParticipantsCard(TableGroup group) {
    final accepted = group.participants
        .where(
          (participant) =>
              participant.status == TableGroupParticipantStatus.accepted,
        )
        .toList(growable: true);
    if (!accepted.any((participant) => participant.userId == group.ownerId)) {
      accepted.add(
        TableGroupParticipant(
          userId: group.ownerId,
          joinedAt: null,
          status: TableGroupParticipantStatus.accepted,
          joinNote: null,
          username: group.ownerUsername,
          profilePictureUrl: group.ownerProfileImageUrl,
        ),
      );
    }
    accepted.sort((a, b) {
      if (a.userId == group.ownerId) return -1;
      if (b.userId == group.ownerId) return 1;
      final aTime = a.joinedAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.joinedAt?.millisecondsSinceEpoch ?? 0;
      return aTime.compareTo(bTime);
    });
    final visible = accepted.take(group.maxPersonCount).toList();
    final emptyCount = (group.maxPersonCount - visible.length).clamp(0, 6);
    final rows = <Widget>[
      for (final participant in visible)
        _detailParticipantRow(group, participant),
      for (var index = 0; index < emptyCount; index++)
        _DetailEmptyParticipantRow(index: index),
    ];
    return Container(
      key: const Key('table_group_detail_participants'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: TableGroupOverviewStyle.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TableGroupOverviewStyle.cardBorder),
        boxShadow: TableGroupOverviewStyle.cardShadows,
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index != rows.length - 1)
              const Divider(height: 1, color: TableGroupOverviewStyle.divider),
          ],
        ],
      ),
    );
  }

  Widget _detailParticipantRow(
    TableGroup group,
    TableGroupParticipant participant,
  ) {
    final isOwner = participant.userId == group.ownerId;
    final username = isOwner
        ? _detailOwnerUsername(group)
        : _participantDisplayName(participant);
    final imageUrl = _validUrlOrNull(
      isOwner
          ? group.ownerProfileImageUrl ?? participant.profilePictureUrl
          : participant.profilePictureUrl,
    );
    return InkWell(
      key: ValueKey<String>(
        'table_group_detail_participant-${participant.userId}',
      ),
      onTap: () => _openParticipantProfile(participant),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        child: Row(
          children: [
            _DetailAvatar(
              imageUrl: imageUrl,
              initials: _initialsFrom(username),
              size: 44,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username.startsWith('@') ? username : '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TableGroupOverviewStyle.headingMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Masa sahibi',
                      style: TextStyle(
                        color: TableGroupOverviewStyle.tertiaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _DetailOverviewAction _overviewAction(TableGroup group) {
    if (_isAccepted) {
      return _DetailOverviewAction(
        label: 'Masaya git',
        message: 'Sohbete ve masa oyunlarına buradan ulaşabilirsin.',
        icon: Icons.chat_bubble_outline_rounded,
        onTap: () => unawaited(_openChat()),
      );
    }
    if (_myStatus == null && _isTableFull) {
      return const _DetailOverviewAction(
        label: 'Masa dolu',
        message:
            'Bu masadaki tüm yerler dolmuş. Başka bir masaya göz atabilirsin.',
        icon: Icons.group_off_outlined,
      );
    }
    if (_myStatus == null && !_canCreateOrJoin) {
      return const _DetailOverviewAction(
        label: 'Kişisel hesap gerekli',
        message:
            'Masa oluşturma ve katılma işlemleri kişisel hesaplarla kullanılabilir.',
        icon: Icons.lock_outline_rounded,
      );
    }
    return switch (_myStatus) {
      null => _DetailOverviewAction(
        label: _joinInFlight ? 'Katılıyor…' : 'Katıl',
        message: 'Masa sahibi isteğini onayladığında sohbete katılabilirsin.',
        icon: Icons.person_add_alt_1_rounded,
        onTap: _joinInFlight ? null : _join,
        loading: _joinInFlight,
      ),
      TableGroupParticipantStatus.pending => const _DetailOverviewAction(
        label: 'Katılma isteği beklemede',
        message:
            'Masa sahibi isteğini değerlendirdiğinde sana haber vereceğiz.',
        icon: Icons.hourglass_top_rounded,
      ),
      TableGroupParticipantStatus.rejected => const _DetailOverviewAction(
        label: 'İstek reddedildi',
        message: 'Bu masa için gönderdiğin katılma isteği reddedildi.',
        icon: Icons.block_outlined,
      ),
      TableGroupParticipantStatus.kicked => const _DetailOverviewAction(
        label: 'Masadan çıkarıldın',
        message: 'Masa sahibi tarafından bu masadan çıkarıldın.',
        icon: Icons.person_remove_outlined,
      ),
      TableGroupParticipantStatus.left => const _DetailOverviewAction(
        label: 'Masadan ayrıldın',
        message: 'Bu masadan ayrıldığın için sohbete erişemezsin.',
        icon: Icons.logout_rounded,
      ),
      TableGroupParticipantStatus.accepted => _DetailOverviewAction(
        label: 'Masaya git',
        message: 'Sohbete ve masa oyunlarına buradan ulaşabilirsin.',
        icon: Icons.chat_bubble_outline_rounded,
        onTap: () => unawaited(_openChat()),
      ),
    };
  }

  Widget _detailStickyAction(_DetailOverviewAction action) {
    final enabled = action.onTap != null;
    final colors = enabled
        ? TableGroupOverviewStyle.brandGradient
        : const <Color>[Color(0xFF334054), Color(0xFF334054)];
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('table_group_detail_sticky_action'),
          borderRadius: BorderRadius.circular(14),
          onTap: action.onTap,
          child: CustomPaint(
            painter: _GradientOutlinePainter(
              radius: 14,
              strokeWidth: 1.5,
              colors: colors,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (action.loading)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          action.icon,
                          size: 28,
                          color: enabled
                              ? TableGroupOverviewStyle.primaryText
                              : const Color(0xFF7F8A9B),
                        ),
                      const SizedBox(width: 12),
                      Text(
                        action.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: enabled
                              ? TableGroupOverviewStyle.primaryText
                              : const Color(0xFF7F8A9B),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _detailOwnerUsername(TableGroup group) {
    final username = group.ownerUsername?.trim();
    if (username != null && username.isNotEmpty) {
      return username.startsWith('@') ? username.substring(1) : username;
    }
    final ownerId = group.ownerId.trim();
    if (ownerId.isEmpty) return 'kullanıcı';
    return ownerId.length <= 8 ? ownerId : ownerId.substring(0, 8);
  }

  String _detailLocationLabel(TableGroup group) {
    final district = group.district?.name.trim();
    final city = group.city.name.trim();
    if (district != null && district.isNotEmpty && city.isNotEmpty) {
      return '$district · $city';
    }
    if (district != null && district.isNotEmpty) return district;
    return city.isEmpty ? 'Konum belirtilmedi' : city;
  }

  String? _tableDescription(TableGroup? group) {
    final description = group?.description?.trim();
    return description == null || description.isEmpty ? null : description;
  }

  Widget _tableDescriptionCard(
    String description, {
    bool showInlineTitle = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        key: const Key('table_group_description_card'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: TableGroupOverviewStyle.cardGradient,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: TableGroupOverviewStyle.cardBorder),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showTableDescription(description),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 13, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showInlineTitle) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Masa hakkında',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.open_in_full_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    description,
                    key: const Key('table_group_description'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TableGroupOverviewStyle.bodyMuted,
                      fontSize: 15,
                      height: 1.42,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTableDescription(String description) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.76),
      builder: (dialogContext) =>
          _PremiumDescriptionDialog(description: description),
    );
  }

  Widget _chatPanel({required bool fullScreen}) {
    final group = _group;
    final participants = group == null
        ? const <TableGroupParticipant>[]
        : group.participants
              .where(
                (participant) =>
                    participant.status == TableGroupParticipantStatus.accepted,
              )
              .toList(growable: false);

    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!fullScreen)
            const Text('Sohbet', style: TextStyle(fontWeight: FontWeight.w700)),
          if (_isOwner || (!_isOwner && _isAccepted)) ...[
            if (!fullScreen) const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!_isOwner && _isAccepted)
                    SizedBox(
                      width: 120,
                      child: _brandOutlineButton(
                        label: _sessionActionInFlight ? 'Bekleyin...' : 'Ayril',
                        onTap: _sessionActionInFlight || !_hasActiveChatAccess
                            ? null
                            : _leave,
                      ),
                    ),
                  if (_isOwner)
                    SizedBox(
                      width: 170,
                      child: _brandOutlineButton(
                        label: _sessionActionInFlight
                            ? 'Sonlandiriliyor...'
                            : 'Oturumu Sonlandir',
                        onTap: _sessionActionInFlight || !_hasActiveChatAccess
                            ? null
                            : _cancelTable,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (_realtimeError != null) ...[
            _chatStatusBanner(
              message: _realtimeError!,
              icon: Icons.wifi_off_rounded,
              actionLabel: _connectingRealtime ? 'Baglaniyor...' : 'Baglan',
              onAction: _connectingRealtime ? null : _recoverRealtime,
            ),
            const SizedBox(height: 8),
          ] else if (_connectingRealtime) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
          ],
          if (_chatError != null) ...[
            _chatStatusBanner(
              message: _chatError!,
              icon: Icons.history_rounded,
              actionLabel: 'Tekrar dene',
              onAction: _chatLoading
                  ? null
                  : () => _loadMessages(
                      reset: _chatRetryReset,
                      followLatest: _chatRetryReset && _messages.isEmpty,
                    ),
            ),
            const SizedBox(height: 8),
          ],
          if (fullScreen)
            Expanded(child: _chatRoom(participants))
          else
            SizedBox(height: 440, child: _chatRoom(participants)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_chatHasNext)
                TextButton(
                  onPressed: _chatLoading || !_shouldRunChat
                      ? null
                      : () => _loadMessages(reset: false),
                  child: const Text('Daha eski mesajlar'),
                ),
              if (_chatLoading && _messages.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'Mesaj yaz',
                    counterText: '',
                    prefixIcon: IconButton(
                      key: const ValueKey<String>('table-group-game-launcher'),
                      tooltip: 'Oyunlar',
                      onPressed:
                          !_shouldRunChat ||
                              _gameLauncherOpen ||
                              _gameState.loading ||
                              _gameState.actionInFlight
                          ? null
                          : _openGameLauncher,
                      icon: const BrandGradientIcon(
                        Icons.sports_esports_rounded,
                        semanticLabel: 'Oyunlar',
                      ),
                    ),
                  ),
                  enabled: _shouldRunChat,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 116,
                child: _brandOutlineButton(
                  label: _sending ? 'Gonderiliyor...' : 'Gonder',
                  onTap: (_sending || !_shouldRunChat) ? null : _sendMessage,
                  compact: true,
                ),
              ),
            ],
          ),
          if (!_shouldRunChat)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Bu sohbet artik yeni mesaja kapali'),
            ),
        ],
      ),
    );

    if (fullScreen) return content;
    return Card(child: content);
  }

  Widget _pendingRequestsPanel() {
    final requests = _pendingJoinRequests;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: requests.length,
        itemBuilder: (context, index) => _joinRequestCard(requests[index]),
      ),
    );
  }

  Widget _chatRoom(List<TableGroupParticipant> participants) {
    final pendingRequests = _isOwner
        ? _pendingJoinRequests
        : const <TableGroupParticipant>[];
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              if (pendingRequests.isNotEmpty)
                Flexible(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _pendingRequestsPanel(),
                  ),
                ),
              Expanded(
                child: _messages.isEmpty && _chatLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _chatScrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final mine = msg.senderId == _currentUserId;
                          final sender = _participantByUserId(msg.senderId);
                          return _chatMessageRow(
                            message: msg,
                            mine: mine,
                            sender: sender,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: participants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    final avatarUrl = _validUrlOrNull(p.profilePictureUrl);
                    final canKick =
                        _isOwner &&
                        p.userId != _group?.ownerId &&
                        _shouldRunChat;
                    final actionInFlight = _ownerActionInFlightIds.contains(
                      p.userId,
                    );
                    return Center(
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 4,
                              top: 2,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => _openParticipantProfile(p),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _participantStatusColor(p.status),
                                      width: 1.3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundImage: avatarUrl != null
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl == null
                                        ? Text(
                                            _initialsFrom(
                                              _participantDisplayName(p),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            if (canKick)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Tooltip(
                                  message:
                                      '${_participantDisplayName(p)} '
                                      'kullanicisini masadan cikar',
                                  child: InkWell(
                                    key: ValueKey<String>('kick-${p.userId}'),
                                    onTap: actionInFlight
                                        ? null
                                        : () => _confirmKickParticipant(p),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.errorContainer,
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: actionInFlight
                                          ? const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                              ),
                                            )
                                          : Icon(
                                              Icons.remove_rounded,
                                              size: 15,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onErrorContainer,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _closedSessionPanel(TableGroup group) {
    final expiresAt = group.expiresAt?.toLocal();
    final description = _tableDescription(group);
    final normalizedVenue = group.venueName?.trim();
    final venue = normalizedVenue?.isNotEmpty == true
        ? normalizedVenue!
        : TableGroupOverviewStyle.unspecifiedVenueLabel;
    final status = group.status.trim().toUpperCase();
    final cancelled = status == 'CANCELLED';
    final expired =
        !cancelled &&
        (status == 'INACTIVE' || group.expiresAt?.isAfter(_now()) == false);
    final locationParts = <String>[
      group.city.name,
      if (group.district?.name.trim().isNotEmpty == true) group.district!.name,
      if (group.neighborhood?.name.trim().isNotEmpty == true)
        group.neighborhood!.name,
    ];
    return RefreshIndicator(
      onRefresh: _bootstrap,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 48),
          Icon(
            expired ? Icons.schedule_rounded : Icons.event_busy_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            expired ? 'Bu masa sona erdi' : 'Bu masa kapatildi',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Masa bilgilerini gorebilirsin ancak katilim ve sohbet '
            'aksiyonlari artik kullanilamaz.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (description != null) ...[
            _tableDescriptionCard(description),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    key: const Key('table_group_closed_venue'),
                    children: [
                      const Icon(Icons.storefront_outlined, size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          venue,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(locationParts.join(' • ')),
                  const SizedBox(height: 8),
                  Text('${group.acceptedCount} katilimci'),
                  if (expiresAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Bitis: '
                      '${expiresAt.day.toString().padLeft(2, '0')}.'
                      '${expiresAt.month.toString().padLeft(2, '0')}.'
                      '${expiresAt.year} '
                      '${_timeOf(expiresAt)}',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatStatusBanner({
    required String message,
    required IconData icon,
    required String actionLabel,
    required Future<void> Function()? onAction,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  String _timeOf(DateTime? value) {
    if (value == null) return '--:--';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _meetingTimeOf(DateTime? value) =>
      formatTableGroupMeetingAt(value, now: _now());

  List<TableGroupParticipant> get _pendingJoinRequests {
    final group = _group;
    if (group == null) return const <TableGroupParticipant>[];
    final pending = group.participants
        .where(
          (participant) =>
              participant.status == TableGroupParticipantStatus.pending &&
              participant.userId != group.ownerId,
        )
        .toList();
    pending.sort((a, b) {
      final aa = a.joinedAt?.millisecondsSinceEpoch ?? 0;
      final bb = b.joinedAt?.millisecondsSinceEpoch ?? 0;
      return bb.compareTo(aa);
    });
    return pending;
  }

  String _participantDisplayName(TableGroupParticipant participant) {
    final username = participant.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    final shortId = participant.userId.length > 8
        ? participant.userId.substring(0, 8)
        : participant.userId;
    return shortId;
  }

  String _displayNameForSender(
    TableGroupParticipant? sender,
    String senderUserId,
  ) {
    if (sender != null) return _participantDisplayName(sender);
    return senderUserId.length > 8
        ? senderUserId.substring(0, 8)
        : senderUserId;
  }

  String? _validUrlOrNull(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;
    return text;
  }

  String _initialsFrom(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final one = parts.first;
      return one.length >= 2
          ? one.substring(0, 2).toUpperCase()
          : one.toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  Color _participantStatusColor(TableGroupParticipantStatus status) {
    return switch (status) {
      TableGroupParticipantStatus.accepted => const Color(0xFF2FB46E),
      TableGroupParticipantStatus.pending => const Color(0xFFE0A200),
      TableGroupParticipantStatus.rejected => const Color(0xFFD06363),
      TableGroupParticipantStatus.kicked => const Color(0xFFD06363),
      TableGroupParticipantStatus.left => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
  }

  Future<void> _openParticipantProfile(
    TableGroupParticipant participant,
  ) async {
    if (!mounted) return;
    final resolver = serviceLocator<DmUserProfileResolver>();
    final resolvedTargets = await resolver.resolveByUserId(
      userId: participant.userId,
      usernameHint: participant.username,
    );
    if (!mounted) return;
    final isCurrentUser = participant.userId == _currentUserId;
    final targets = resolvedTargets
        .where((target) => isCurrentUser || dmProfileRouteFor(target) != null)
        .toList(growable: false);
    if (targets.isEmpty) {
      _showSnack('Bu kullanici icin acik profil bulunamadi');
      return;
    }
    if (targets.length == 1) {
      if (isCurrentUser) {
        _navigateToOwnerProfileTarget(targets.first);
      } else {
        _navigateToProfileTarget(targets.first);
      }
      return;
    }
    final selected = await showModalBottomSheet<DmProfileTarget>(
      context: context,
      showDragHandle: true,
      builder: (context) => _TableGroupProfileTargetSheet(items: targets),
    );
    if (!mounted || selected == null) return;
    if (isCurrentUser) {
      _navigateToOwnerProfileTarget(selected);
    } else {
      _navigateToProfileTarget(selected);
    }
  }

  void _navigateToOwnerProfileTarget(DmProfileTarget target) {
    Navigator.of(context).pushNamed(ownerProfileRouteFor(target.type));
  }

  void _navigateToProfileTarget(DmProfileTarget target) {
    final route = dmProfileRouteFor(target);
    if (route == null) return;
    Navigator.of(
      context,
    ).pushNamed(route.routeName, arguments: route.arguments);
  }

  Future<void> _approvePendingRequest(TableGroupParticipant participant) async {
    final displayName = _participantDisplayName(participant);
    final username = displayName.startsWith('@')
        ? displayName
        : '@$displayName';
    final confirmed = await _confirmSessionAction(
      title: 'Katılım talebini onayla?',
      message: "$username'nin masaya katılım talebini onaylıyor musunuz?",
      confirmLabel: 'Onayla',
    );
    if (!confirmed || !mounted) return;
    await _runOwnerAction(
      participantId: participant.userId,
      fn: () => _approve(participant.userId),
    );
  }

  Future<void> _rejectPendingRequest(TableGroupParticipant participant) async {
    final displayName = _participantDisplayName(participant);
    final confirmed = await _confirmSessionAction(
      title: 'Başvuruyu reddet?',
      message: '$displayName kullanıcısının katılma isteği reddedilecek.',
      confirmLabel: 'Reddet',
    );
    if (!confirmed || !mounted) return;
    await _runOwnerAction(
      participantId: participant.userId,
      fn: () => _reject(participant.userId),
    );
  }

  Widget _joinRequestCard(TableGroupParticipant participant) {
    final avatarUrl = _validUrlOrNull(participant.profilePictureUrl);
    final loading = _ownerActionInFlightIds.contains(participant.userId);
    final displayName = _participantDisplayName(participant);
    final joinNote = participant.joinNote?.trim();
    return CustomPaint(
      painter: _GradientOutlinePainter(
        radius: 14,
        strokeWidth: 1.2,
        colors: AppColors.brandGradient,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      _initialsFrom(displayName),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yeni katılma isteği',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (joinNote != null && joinNote.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      joinNote,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (loading)
              const SizedBox(
                width: 48,
                height: 48,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              _requestActionIcon(
                key: ValueKey<String>(
                  'table_group_approve-${participant.userId}',
                ),
                label: '$displayName kullanıcısını onayla',
                icon: Icons.check_rounded,
                color: const Color(0xFF2FB46E),
                onTap: () => _approvePendingRequest(participant),
              ),
              const SizedBox(width: 6),
              _requestActionIcon(
                key: ValueKey<String>(
                  'table_group_reject-${participant.userId}',
                ),
                label: '$displayName kullanıcısını reddet',
                icon: Icons.close_rounded,
                color: const Color(0xFFE45656),
                onTap: () => _rejectPendingRequest(participant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _requestActionIcon({
    required Key key,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      key: key,
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        tooltip: label,
        onPressed: onTap,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          side: BorderSide(color: color, width: 1.25),
          backgroundColor: color.withValues(alpha: 0.12),
        ),
        icon: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _brandOutlineButton({
    required String label,
    required VoidCallback? onTap,
    bool compact = false,
  }) {
    final disabled = onTap == null;
    const radius = 18.0;
    final borderColors = disabled
        ? [
            Theme.of(context).dividerColor.withValues(alpha: 0.7),
            Theme.of(context).dividerColor.withValues(alpha: 0.7),
          ]
        : AppColors.brandGradient;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: CustomPaint(
          painter: _GradientOutlinePainter(
            radius: radius,
            strokeWidth: 1.3,
            colors: borderColors,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: disabled
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableGroupParticipant? _participantByUserId(String userId) {
    final group = _group;
    if (group == null) return null;
    for (final participant in group.participants) {
      if (participant.userId == userId) return participant;
    }
    return null;
  }

  Widget _chatMessageRow({
    required TableGroupMessage message,
    required bool mine,
    required TableGroupParticipant? sender,
  }) {
    final game = message.game;
    if (message.messageType == 'GAME' && game != null) {
      final currentGame = _gameState.game;
      return TableGroupGameMessageCard(
        message: message,
        currentUserId: _currentUserId,
        canCancelGame: _isOwner || _currentUserId == game.createdBy,
        actionInFlight: _gameState.actionInFlight,
        actionCommitted: _gameState.isActionCommittedFor(game),
        interactionEnabled:
            _shouldRunChat &&
            currentGame?.gameId == game.gameId &&
            currentGame?.revision == game.revision,
        onJoin: () => unawaited(_joinGame(game)),
        onLeave: () => unawaited(_leaveGame(game)),
        onStart: () => unawaited(_startGame(game)),
        onCancel: () => unawaited(_cancelGame(game)),
        onAction: (action, targetUserId) =>
            unawaited(_submitGameAction(game, action, targetUserId)),
        onExpired: () => _reconcileExpiredGame(game),
        now: _now,
      );
    }
    final avatarUrl = sender == null
        ? null
        : _validUrlOrNull(sender.profilePictureUrl);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: mine
            ? LinearGradient(colors: [AppColors.gradientA, AppColors.gradientC])
            : null,
        color: mine
            ? null
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(mine ? 14 : 6),
          bottomRight: Radius.circular(mine ? 6 : 14),
        ),
        border: Border.all(
          color: mine ? Colors.transparent : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            _timeOf(message.sentAt),
            style: TextStyle(
              fontSize: 11,
              color: mine
                  ? AppColors.white.withValues(alpha: 0.84)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (mine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    _initialsFrom(
                      _displayNameForSender(sender, message.senderId),
                    ),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

enum _DetailMenuAction { refresh, closeTable, leaveTable }

class _DetailOverviewAction {
  final String label;
  final String message;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  const _DetailOverviewAction({
    required this.label,
    required this.message,
    required this.icon,
    this.onTap,
    this.loading = false,
  });
}

class _DetailSectionTitle extends StatelessWidget {
  final String text;

  const _DetailSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: TableGroupOverviewStyle.headingMuted,
        fontSize: 21,
        height: 1.15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _DetailEmptyInfoCard extends StatelessWidget {
  final String message;

  const _DetailEmptyInfoCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: TableGroupOverviewStyle.cardGradient,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: TableGroupOverviewStyle.cardBorder),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: TableGroupOverviewStyle.bodyMuted,
          height: 1.4,
        ),
      ),
    );
  }
}

class _DetailCountPill extends StatelessWidget {
  final String text;

  const _DetailCountPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TableGroupOverviewStyle.cardBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: TableGroupOverviewStyle.headingMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size;

  const _DetailAvatar({
    required this.imageUrl,
    required this.initials,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final innerSize = size - 3;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFF755B), Color(0xFFD33EFF)],
        ),
      ),
      child: ClipOval(
        child: AppCachedNetworkImage(
          imageUrl: imageUrl,
          width: innerSize,
          height: innerSize,
          cacheWidth: (innerSize * 3).round(),
          cacheHeight: (innerSize * 3).round(),
          placeholderBuilder: (_) => _fallback(),
          errorBuilder: (_) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: const Color(0xFF070D17),
      child: Center(
        child: Text(
          initials,
          maxLines: 1,
          style: TextStyle(
            color: const Color(0xFFF2F4F8),
            fontSize: size * 0.28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DetailStatsStrip extends StatelessWidget {
  final TableGroup group;
  final String timeText;

  const _DetailStatsStrip({required this.group, required this.timeText});

  @override
  Widget build(BuildContext context) {
    final normalizedVenue = group.venueName?.trim();
    final venue = normalizedVenue?.isNotEmpty == true
        ? normalizedVenue!
        : TableGroupOverviewStyle.unspecifiedVenueLabel;
    return Container(
      key: const Key('table_group_detail_stats'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: TableGroupOverviewStyle.insetGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TableGroupOverviewStyle.insetBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final venueStat = _DetailIconText(
            key: const Key('table_group_detail_venue'),
            icon: Icons.storefront_outlined,
            text: venue,
            semanticsLabel: 'Mekân $venue',
            flexibleText: true,
            shrinkTextToFit:
                venue == TableGroupOverviewStyle.unspecifiedVenueLabel,
          );
          final timeStat = _DetailIconText(
            key: const Key('table_group_detail_meeting_time'),
            icon: Icons.schedule_rounded,
            text: timeText,
            semanticsLabel: 'Buluşma saati $timeText',
            flexibleText: true,
          );
          final capacityGlyphs = _DetailCapacityGlyphs(
            acceptedCount: group.acceptedCount,
            maxPersonCount: group.maxPersonCount,
          );
          final capacityText = Text(
            '${group.acceptedCount}/${group.maxPersonCount} kişi',
            key: const Key('table_group_detail_capacity'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TableGroupOverviewStyle.bodyMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          );
          final capacityStat = Row(
            mainAxisSize: MainAxisSize.min,
            children: [capacityGlyphs, const SizedBox(width: 8), capacityText],
          );
          final useStackedLayout =
              constraints.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.8;
          if (useStackedLayout) {
            return Wrap(
              key: const Key('table_group_detail_stats_stacked'),
              spacing: 14,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: venueStat,
                ),
                SizedBox(width: constraints.maxWidth, child: timeStat),
                SizedBox(
                  width: constraints.maxWidth,
                  child: Row(
                    children: [
                      capacityGlyphs,
                      const SizedBox(width: 8),
                      Expanded(child: capacityText),
                    ],
                  ),
                ),
              ],
            );
          }
          return Row(
            key: const Key('table_group_detail_stats_inline'),
            children: [
              Expanded(flex: 4, child: venueStat),
              const _DetailStatDivider(),
              Expanded(flex: 4, child: timeStat),
              const _DetailStatDivider(),
              Expanded(
                flex: 5,
                child: FittedBox(
                  alignment: Alignment.centerRight,
                  fit: BoxFit.scaleDown,
                  child: capacityStat,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailIconText extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? semanticsLabel;
  final bool flexibleText;
  final bool shrinkTextToFit;

  const _DetailIconText({
    super.key,
    required this.icon,
    required this.text,
    this.semanticsLabel,
    this.flexibleText = false,
    this.shrinkTextToFit = false,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: TableGroupOverviewStyle.bodyMuted,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
    final displayedText = shrinkTextToFit
        ? FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: textWidget,
          )
        : textWidget;
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: flexibleText ? MainAxisSize.max : MainAxisSize.min,
          children: [
            BrandGradientIcon(icon, size: 19),
            const SizedBox(width: 7),
            if (flexibleText) Expanded(child: displayedText) else displayedText,
          ],
        ),
      ),
    );
  }
}

class _DetailStatDivider extends StatelessWidget {
  const _DetailStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: TableGroupOverviewStyle.divider,
    );
  }
}

class _DetailCapacityGlyphs extends StatelessWidget {
  final int acceptedCount;
  final int maxPersonCount;

  const _DetailCapacityGlyphs({
    required this.acceptedCount,
    required this.maxPersonCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = maxPersonCount.clamp(0, 6);
    final accepted = acceptedCount.clamp(0, total);
    return Row(
      key: const Key('table_group_detail_capacity_slots'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < total; index++)
          Padding(
            padding: EdgeInsets.only(right: index == total - 1 ? 0 : 1),
            child: index < accepted
                ? ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: <Color>[Color(0xFFFF755B), Color(0xFFD33EFF)],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: Color(0xFFC04DFF),
                  ),
          ),
      ],
    );
  }
}

class _DetailEmptyParticipantRow extends StatelessWidget {
  final int index;

  const _DetailEmptyParticipantRow({required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey<String>('table_group_detail_empty_participant-$index'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
      child: Row(
        children: [
          CustomPaint(
            painter: const _DashedCirclePainter(color: Color(0xFF55657D)),
            child: const SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF7D8BA0),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            '–',
            style: TextStyle(color: Color(0xFF8996AA), fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;

  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const dashCount = 12;
    const gapRadians = 0.12;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final sweep = ((2 * 3.141592653589793) / dashCount) - gapRadians;
    for (var index = 0; index < dashCount; index++) {
      final start = index * (2 * 3.141592653589793 / dashCount);
      canvas.drawArc(rect.deflate(1), start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TableGroupProfileTargetSheet extends StatelessWidget {
  final List<DmProfileTarget> items;

  const _TableGroupProfileTargetSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final imageUrl = item.imageUrl?.trim();
          final hasImage =
              imageUrl != null &&
              (imageUrl.startsWith('http://') ||
                  imageUrl.startsWith('https://'));
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
              child: hasImage
                  ? null
                  : Icon(switch (item.type) {
                      DmProfileTargetType.musician => Icons.person_outline,
                      DmProfileTargetType.venue => Icons.storefront_outlined,
                      DmProfileTargetType.studio => Icons.graphic_eq_outlined,
                      DmProfileTargetType.listener => Icons.headphones_outlined,
                    }, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            title: Text(item.displayName),
            subtitle: Text(item.type.displayLabel),
            onTap: () => Navigator.of(context).pop(item),
          );
        },
      ),
    );
  }
}

class _PremiumDescriptionDialog extends StatelessWidget {
  final String description;

  const _PremiumDescriptionDialog({required this.description});

  @override
  Widget build(BuildContext context) {
    final foreground = AppColors.white;
    final muted = AppColors.white.withValues(alpha: 0.72);

    return Dialog(
      key: const Key('table_group_description_dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 390),
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.brandGradient
                  .map((color) => color.withValues(alpha: 0.72))
                  .toList(growable: false),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.pureBlack.withValues(alpha: 0.52),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0A1526),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: AppColors.brandGradient,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF101D31),
                          ),
                          child: Icon(
                            Icons.subject_rounded,
                            color: foreground,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Masa hakkında',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Masa sahibinin buluşma notu',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 260),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF071321),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2A4059)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        description,
                        key: const Key('table_group_description_dialog_text'),
                        style: TextStyle(
                          color: foreground,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: AppColors.brandGradient),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: Material(
                        color: const Color(0xFF0A1526),
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          key: const Key('table_group_description_close'),
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(13),
                          child: SizedBox(
                            height: 48,
                            child: Center(
                              child: Text(
                                'Kapat',
                                style: TextStyle(
                                  color: foreground,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const _PremiumConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = AppColors.white;
    final muted = AppColors.white.withValues(alpha: 0.72);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxDialogHeight = screenHeight > 48
        ? screenHeight - 48
        : screenHeight;

    return Dialog(
      key: const Key('table_group_confirmation_dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: 390, maxHeight: maxDialogHeight),
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.brandGradient
                .map((color) => color.withValues(alpha: 0.76))
                .toList(growable: false),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.pureBlack.withValues(alpha: 0.56),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0A1526),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    key: const Key('table_group_confirmation_scroll'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              padding: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: AppColors.brandGradient,
                                ),
                              ),
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF101D31),
                                ),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: foreground,
                                  size: 23,
                                ),
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF071321),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2A4059)),
                          ),
                          child: Text(
                            message,
                            style: TextStyle(
                              color: muted,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('table_group_confirmation_cancel'),
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: muted,
                          side: const BorderSide(color: Color(0xFF2A4059)),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Vazgeç',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: AppColors.brandGradient,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandGradient.last.withValues(
                                alpha: 0.22,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            key: const Key('table_group_confirmation_confirm'),
                            onPressed: () => Navigator.of(context).pop(true),
                            style: FilledButton.styleFrom(
                              foregroundColor: AppColors.white,
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              confirmLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinDialogSubmission {
  final String note;

  const _JoinDialogSubmission(this.note);
}

class _PremiumJoinDialog extends StatefulWidget {
  const _PremiumJoinDialog();

  @override
  State<_PremiumJoinDialog> createState() => _PremiumJoinDialogState();
}

class _PremiumJoinDialogState extends State<_PremiumJoinDialog> {
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _noteFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _cancel() => Navigator.of(context).pop();

  void _confirm() =>
      Navigator.of(context).pop(_JoinDialogSubmission(_noteController.text));

  @override
  Widget build(BuildContext context) {
    final foreground = AppColors.white;
    final muted = AppColors.white.withValues(alpha: 0.72);

    return Dialog(
      key: const Key('table_group_join_dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 390),
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.brandGradient
                  .map((color) => color.withValues(alpha: 0.72))
                  .toList(growable: false),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.pureBlack.withValues(alpha: 0.52),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0A1526),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: AppColors.brandGradient,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF101D31),
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: foreground,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Katılma isteği',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Masa sahibine kısa bir not bırakabilirsin.',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('table_group_join_owner_warning'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.brandGradient.first.withValues(alpha: 0.18),
                          AppColors.brandGradient.last.withValues(alpha: 0.14),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: AppColors.coralLight.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.coralLight,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Aktif bir masan varsa bu istek onaylandığında '
                            'kapanır.',
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.94),
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Not',
                        style: TextStyle(
                          color: foreground,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111F34),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFF263A52)),
                        ),
                        child: Text(
                          'İsteğe bağlı',
                          style: TextStyle(
                            color: muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: _noteFocusNode.hasFocus
                          ? LinearGradient(colors: AppColors.brandGradient)
                          : const LinearGradient(
                              colors: [Color(0xFF2A4059), Color(0xFF2A4059)],
                            ),
                    ),
                    child: TextField(
                      key: const Key('table_group_join_note_input'),
                      controller: _noteController,
                      focusNode: _noteFocusNode,
                      autofocus: true,
                      maxLength: 256,
                      minLines: 3,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: AppColors.coralLight,
                      style: TextStyle(color: foreground),
                      decoration: InputDecoration(
                        hintText: 'Kısa bir not yazabilirsin…',
                        hintStyle: TextStyle(color: muted, fontSize: 14),
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF071321),
                        contentPadding: const EdgeInsets.fromLTRB(
                          15,
                          14,
                          15,
                          14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _noteController,
                    builder: (context, value, _) => Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${value.text.characters.length}/256',
                        key: const Key('table_group_join_note_counter'),
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('table_group_join_cancel'),
                          onPressed: _cancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: muted,
                            side: const BorderSide(color: Color(0xFF2A4059)),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'İptal',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: AppColors.brandGradient,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandGradient.last.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('table_group_join_confirm'),
                              onTap: _confirm,
                              borderRadius: BorderRadius.circular(14),
                              child: const SizedBox(
                                height: 48,
                                child: Center(
                                  child: Text(
                                    'Gönder',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientOutlinePainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final List<Color> colors;

  _GradientOutlinePainter({
    required this.radius,
    required this.strokeWidth,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(colors: colors).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientOutlinePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.colors != colors;
  }
}
