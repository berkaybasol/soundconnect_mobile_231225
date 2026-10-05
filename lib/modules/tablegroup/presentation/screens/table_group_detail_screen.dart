import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/auth/listener_profile_publication_access.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/access_policy.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../core/realtime/realtime_client_error.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_surface_theme.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../dm/data/dm_auth_support.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../../dm/presentation/dm_profile_navigation.dart';
import '../../../notification/presentation/notification_target_read.dart';
import '../../../notification/data/notification_target_repository.dart';
import '../../../notification/domain/entities/table_notification_target.dart';
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
import '../table_group_profile_draft.dart';
import '../widgets/table_group_game_launcher_sheet.dart';
import '../widgets/table_group_game_message_card.dart';
import '../widgets/table_group_overview_style.dart';
import 'table_group_list_screen.dart';

part 'table_group_detail_screen_bootstrap.dart';
part 'table_group_detail_screen_join.dart';
part 'table_group_detail_screen_detail_sticky_action.dart';
part 'table_group_detail_screen_display_name_for_sender.dart';
part 'table_group_detail_screen_premium_description_dialog.dart';

class TableGroupDetailArgs {
  final String tableGroupId;
  final StageMode bottomBarStageMode;
  final bool openChat;
  final TableNotificationTarget? notificationTarget;
  final TableNotificationTarget? notificationResult;
  final String? notificationResultMessage;
  final VoidCallback? onNotificationRetry;

  const TableGroupDetailArgs({
    required this.tableGroupId,
    this.bottomBarStageMode = StageMode.backstage,
    this.openChat = true,
    this.notificationTarget,
    this.notificationResult,
    this.notificationResultMessage,
    this.onNotificationRetry,
  });
}

class TableGroupDetailScreen extends StatelessWidget {
  final TableGroupDetailArgs args;
  final TableGroupRepository? repository;
  final TableGroupGameRepository? gameRepository;
  final TokenStore? tokenStore;
  final TableGroupChatRealtimeClient? realtimeClient;
  final DateTime Function()? now;
  final bool Function()? canCreateOrJoin;
  final String Function()? chatRequestIdFactory;
  final AuthSessionManager? sessions;

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
    this.sessions,
  });

  @override
  Widget build(BuildContext context) => AppSurfaceThemeScope(
    child: _TableGroupDetailContent(
      args: args,
      repository: repository,
      gameRepository: gameRepository,
      tokenStore: tokenStore,
      realtimeClient: realtimeClient,
      now: now,
      canCreateOrJoin: canCreateOrJoin,
      chatRequestIdFactory: chatRequestIdFactory,
      sessions: sessions,
    ),
  );
}

class _TableGroupDetailContent extends StatefulWidget {
  const _TableGroupDetailContent({
    required this.args,
    this.repository,
    this.gameRepository,
    this.tokenStore,
    this.realtimeClient,
    this.now,
    this.canCreateOrJoin,
    this.chatRequestIdFactory,
    this.sessions,
  });

  final TableGroupDetailArgs args;
  final TableGroupRepository? repository;
  final TableGroupGameRepository? gameRepository;
  final TokenStore? tokenStore;
  final TableGroupChatRealtimeClient? realtimeClient;
  final DateTime Function()? now;
  final bool Function()? canCreateOrJoin;
  final String Function()? chatRequestIdFactory;
  final AuthSessionManager? sessions;

  @override
  State<_TableGroupDetailContent> createState() =>
      _TableGroupDetailScreenState();
}

class _TableGroupDetailScreenState extends State<_TableGroupDetailContent>
    with WidgetsBindingObserver {
  late final TableGroupRepository _repository;
  late final TableGroupGameCubit _gameCubit;
  late final TokenStore _tokenStore;
  late final TableGroupChatRealtimeClient _realtimeClient;
  late final bool _ownsRealtimeClient;
  late final String Function() _chatRequestIdFactory;
  late final DateTime Function() _now;
  late final AuthSessionManager? _shareSessions;
  late final AuthSession? _shareSession;
  late final TableGroupLocalDayRefreshScheduler _dayRefreshScheduler;
  final TextEditingController _chatController = TextEditingController();
  final GlobalKey _chatComposerKey = GlobalKey();
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
  bool _chatLoaded = false;
  bool _chatRetryReset = true;
  bool _connectingRealtime = false;
  bool _sending = false;
  bool _joinInFlight = false;
  bool _sessionActionInFlight = false;
  bool _gameLauncherOpen = false;
  bool _profileDraftOpening = false;
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
    _shareSessions =
        widget.sessions ??
        (serviceLocator.isRegistered<AuthSessionManager>()
            ? serviceLocator<AuthSessionManager>()
            : null);
    _shareSession = _shareSessions?.session;
    _shareSessions?.addListener(_profileShareSessionChanged);
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
    _shareSessions?.removeListener(_profileShareSessionChanged);
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

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if ((widget.args.notificationTarget != null ||
            widget.args.notificationResult != null) &&
        _error != null) {
      return NotificationTerminalFeedback(
        message: 'Bu masa şu anda açılamıyor.',
        acknowledge: false,
        ready: _notificationSessionCurrent,
        retry: widget.args.onNotificationRetry ?? _bootstrap,
        child: TableGroupListScreen(),
      );
    }
    final group = _group;
    final description = _tableDescription(group);
    final showOverview =
        group != null && _isSessionActive && (!_isAccepted || !_showChat);
    final showMoreMenu =
        group != null &&
        (showOverview || (_isSessionActive && (_isOwner || _isAccepted)));
    final page = NotificationTargetReady(
      ready:
          !_loading &&
          _error == null &&
          group?.id == widget.args.tableGroupId &&
          (widget.args.notificationTarget == null ||
              (widget.args.notificationTarget!.chat &&
                  _notificationMatches(group!) &&
                  _shouldRunChat &&
                  _chatLoaded &&
                  !_chatLoading &&
                  _chatError == null)),
      contentIdentity: widget.args.notificationTarget,
      onVisible: widget.args.notificationTarget?.chat == true
          ? _confirmVisibleChat
          : null,
      child: TableGroupSurfaceBackdrop(
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
            title: Text(
              'Masa Detayı',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: TableGroupSurfaceStyle.of(context).headingMuted,
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
                    if (_canShareOnProfile)
                      PopupMenuItem<_DetailMenuAction>(
                        key: const Key('table_group_profile_share'),
                        value: _DetailMenuAction.shareOnProfile,
                        enabled: !_profileDraftOpening,
                        child: const Text('Paylaş'),
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
                        GradientOutline(
                          enabled: AppColors.isLight,
                          radius: 999,
                          child: FilledButton(
                            onPressed:
                                widget.args.onNotificationRetry ?? _bootstrap,
                            style: AppColors.isLight
                                ? FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: AppColors.textPrimary,
                                  )
                                : null,
                            child: const Text('Tekrar dene'),
                          ),
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
      ),
    );
    final result = widget.args.notificationResult;
    if (result == null) return page;
    return NotificationTerminalFeedback(
      message: widget.args.notificationResultMessage!,
      contentIdentity: result,
      ready:
          !_loading &&
          _error == null &&
          group?.id == result.tableGroupId &&
          _notificationSessionCurrent,
      child: page,
    );
  }

  void _updateView(VoidCallback change) => setState(change);
}

enum _DetailMenuAction { refresh, shareOnProfile, closeTable, leaveTable }

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
    Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        color: TableGroupSurfaceStyle.of(context).headingMuted,
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
    Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: TableGroupSurfaceStyle.of(context).cardGradient,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: TableGroupSurfaceStyle.of(context).cardBorder,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: TableGroupSurfaceStyle.of(context).bodyMuted,
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
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: (AppColors.isOriginalDark
            ? Theme.of(context).colorScheme.surfaceContainerHigh
            : AppColors.navBlueSoft),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: TableGroupSurfaceStyle.of(context).cardBorder,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: TableGroupSurfaceStyle.of(context).headingMuted,
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
    Theme.of(context);
    final innerSize = size - 3;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.isLight
              ? AppColors.decorativeGradient
              : const <Color>[Color(0xFFFF755B), Color(0xFFD33EFF)],
        ),
      ),
      child: ClipOval(
        child: AppCachedNetworkImage(
          imageUrl: imageUrl,
          width: innerSize,
          height: innerSize,
          cacheWidth: (innerSize * 3).round(),
          cacheHeight: (innerSize * 3).round(),
          placeholderBuilder: (_) => _fallback(context),
          errorBuilder: (_) => _fallback(context),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return ColoredBox(
      color: (AppColors.isOriginalDark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : AppColors.avatarBackground),
      child: Center(
        child: Text(
          initials,
          maxLines: 1,
          style: TextStyle(
            color: (AppColors.isOriginalDark
                ? Theme.of(context).colorScheme.onSurface
                : AppColors.avatarForeground),
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
    Theme.of(context);
    final normalizedVenue = group.venueName?.trim();
    final venue = normalizedVenue?.isNotEmpty == true
        ? normalizedVenue!
        : TableGroupOverviewStyle.unspecifiedVenueLabel;
    return Container(
      key: const Key('table_group_detail_stats'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: TableGroupSurfaceStyle.of(context).insetGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TableGroupSurfaceStyle.of(context).insetBorder,
        ),
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
            style: TextStyle(
              color: TableGroupSurfaceStyle.of(context).bodyMuted,
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
    Theme.of(context);
    final textWidget = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: TableGroupSurfaceStyle.of(context).bodyMuted,
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
    Theme.of(context);
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: TableGroupSurfaceStyle.of(context).divider,
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
    Theme.of(context);
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
                    shaderCallback: (bounds) => LinearGradient(
                      colors: AppColors.isLight
                          ? AppColors.decorativeGradient
                          : const <Color>[Color(0xFFFF755B), Color(0xFFD33EFF)],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: AppColors.isLight
                        ? AppColors.decorativeGradient.last
                        : const Color(0xFFC04DFF),
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
    Theme.of(context);
    return Padding(
      key: ValueKey<String>('table_group_detail_empty_participant-$index'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
      child: Row(
        children: [
          CustomPaint(
            painter: _DashedCirclePainter(
              color: AppColors.isOriginalDark
                  ? Theme.of(context).colorScheme.outline
                  : const Color(0xFF55657D),
            ),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                Icons.person_outline_rounded,
                color: AppColors.isOriginalDark
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : const Color(0xFF7D8BA0),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '–',
            style: TextStyle(
              color: AppColors.isOriginalDark
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : const Color(0xFF8996AA),
              fontSize: 18,
            ),
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
    Theme.of(context);
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
            subtitle: item.isGhostListener
                ? Row(
                    children: [
                      Text(item.type.displayLabel),
                      const SizedBox(width: 7),
                      const GhostProfileBadge(),
                    ],
                  )
                : Text(item.type.displayLabel),
            onTap: () => Navigator.of(context).pop(item),
          );
        },
      ),
    );
  }
}
