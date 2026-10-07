import 'inbox_product_notification_open.dart';
import '../notification_direct_open.dart';
import 'band_notification_open_screen.dart';
import 'venue_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';
import 'dart:async';
import 'follow_notification_open_screen.dart';
import 'media_notification_open_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/push_provider.dart';
import '../../../auth/presentation/screens/venue_application_decision_screen.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../../dm/presentation/dm_profile_navigation.dart';
import '../../../dm/presentation/screens/dm_notification_open_screen.dart';
import '../../../profile/domain/entities/listener_visibility_context.dart';
import '../../../profile/presentation/screens/band_profile_screen.dart';
import 'studio_reservation_notification_open_screen.dart';
import 'table_notification_open_screen.dart';
import '../../domain/entities/app_notification.dart';
import '../cubit/notification_cubit.dart';
import '../cubit/notification_state.dart';
import '../notification_target_read.dart';

part 'notification_screen_support_widgets.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _paginationCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<NotificationCubit>().refresh());
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 180;
    if (_scrollController.position.pixels >= threshold) {
      context.read<NotificationCubit>().loadMore();
    }
  }

  bool _onScrollMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0) _schedulePaginationCheck();
    return false;
  }

  void _schedulePaginationCheck() {
    if (_paginationCheckScheduled) return;
    _paginationCheckScheduled = true;
    // Refresh can clamp the offset during layout without notifying the scroll
    // controller. Check the new boundary once layout and Bloc updates settle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paginationCheckScheduled = false;
      if (!mounted) return;
      final state = context.read<NotificationCubit>().state;
      if (state.status == NotificationStatus.success &&
          state.errorMessage == null &&
          state.hasNext) {
        _onScroll();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return BlocListener<NotificationCubit, NotificationState>(
      listenWhen: (previous, current) => !previous.hasNext && current.hasNext,
      listener: (_, _) {
        // A late DELETE can reopen an offset repair at the current bottom
        // without changing the list's dimensions or scroll position.
        _schedulePaginationCheck();
      },
      child: BlocConsumer<NotificationCubit, NotificationState>(
        listenWhen: (previous, current) =>
            previous.errorMessage != current.errorMessage,
        listener: (context, state) {
          final error = state.errorMessage;
          if (error == null || error.trim().isEmpty) return;
          ScaffoldMessenger.of(context).showSnackBar(
            appSnackBar(
              context,
              tone: AppSnackBarTone.error,
              content: Text(error),
            ),
          );
        },
        builder: (context, state) {
          final loading =
              state.status == NotificationStatus.loading && state.items.isEmpty;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Bildirimler'),
              actions: [
                PopupMenuButton<_NotificationAction>(
                  onSelected: (action) => _handleAction(context, state, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _NotificationAction.markAllRead,
                      enabled: state.unreadCount > 0,
                      child: const Text('Tümünü oku'),
                    ),
                    PopupMenuItem(
                      value: _NotificationAction.clearAll,
                      enabled: state.items.isNotEmpty,
                      child: const Text('Tümünü temizle'),
                    ),
                  ],
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () => context.read<NotificationCubit>().refresh(),
              child: loading
                  ? const _NotificationLoadingList()
                  : state.items.isEmpty
                  ? const _EmptyNotifications()
                  : NotificationListener<ScrollMetricsNotification>(
                      onNotification: _onScrollMetrics,
                      child: ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                        itemBuilder: (context, index) {
                          if (index >= state.items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(18),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final item = state.items[index];
                          return _NotificationTile(
                            key: ValueKey(item.id),
                            notification: item,
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemCount:
                            state.items.length +
                            (state.status == NotificationStatus.loadingMore
                                ? 1
                                : 0),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    NotificationState state,
    _NotificationAction action,
  ) async {
    final cubit = context.read<NotificationCubit>();
    switch (action) {
      case _NotificationAction.markAllRead:
        await cubit.markAllAsRead();
        return;
      case _NotificationAction.clearAll:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Bildirimleri temizle'),
            content: const Text('Tüm bildirimlerin silinecek.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Temizle'),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await cubit.clearAllNotifications();
        }
        return;
    }
  }
}

enum _NotificationAction { markAllRead, clearAll }

class _NotificationTile extends StatefulWidget {
  final AppNotification notification;

  const _NotificationTile({super.key, required this.notification});

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _openingTarget = false;
  NotificationTargetRead? _readTicket;
  ModalRoute<dynamic>? _originRoute;

  bool get _currentOpen =>
      mounted &&
      _readTicket?.isCurrent == true &&
      _readTicket?.notification.id == notification.id &&
      _originRoute?.isCurrent != false &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  Future<void> _pushNamedTarget(
    String name, {
    Object? arguments,
    bool acknowledge = true,
  }) async {
    if (!_currentOpen) return;
    await Navigator.of(context).pushNamed<void>(
      name,
      arguments: acknowledge && !notification.read
          ? _readTicket!.argumentsFor(name, arguments: arguments)
          : arguments,
    );
  }

  AppNotification get notification => widget.notification;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final unread = !notification.read;
    final colors = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.isLight
              ? const Color(0xFFB63B49)
              : AppColors.coralAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) =>
          context.read<NotificationCubit>().deleteNotification(notification),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openingTarget ? null : () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: unread
                ? colors.surfaceContainerHighest
                : colors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread
                  ? AppColors.brandGradient.last.withValues(alpha: 0.45)
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationTypeIcon(notification: notification, unread: unread),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayText(notification.title),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 15,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_isGhostContextualIdentity) ...[
                          const SizedBox(width: 7),
                          GhostProfileBadge(
                            key: ValueKey(
                              'notification-ghost-badge-${notification.id}',
                            ),
                          ),
                        ],
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppColors.brandGradient,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (notification.message.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        _displayText(notification.message.trim()),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _timeLabel(notification.createdAt),
                      style: TextStyle(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    if (_openingTarget) return;
    _readTicket = NotificationTargetRead(
      notification: notification,
      cubit: context.read<NotificationCubit>(),
      sessions: serviceLocator<AuthSessionManager>(),
    );
    _originRoute = ModalRoute.of(context);
    if (!_currentOpen) return;
    setState(() => _openingTarget = true);
    try {
      if (PushTarget.venueApplicationTypes.contains(notification.type)) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => VenueApplicationDecisionScreen(
              target: PushTarget(
                notificationId: notification.id,
                recipientId: notification.recipientId,
                type: notification.type,
              ),
            ),
          ),
        );
        return;
      }
      if (PushTarget.followTypes.contains(notification.type)) {
        await _openDirect(
          FollowNotificationOpenScreen(target: _pushTargetFor()),
        );
        return;
      }
      if (PushTarget.mediaTypes.contains(notification.type)) {
        await _openDirect(
          MediaNotificationOpenScreen(target: _pushTargetFor()),
        );
        return;
      }
      if (_isDmNotification(notification)) {
        await _openDirect(
          DmNotificationOpenScreen(
            target: _pushTargetFor(
              conversationId: notification.payload['conversationId']
                  ?.toString()
                  .trim(),
            ),
          ),
        );
        return;
      }
      if (_isStudioNotification(notification)) {
        await _openStudioReservationTarget(context, notification);
        return;
      }
      if (_isCollabNotification(notification)) {
        await _openCollabTarget(context, notification);
        return;
      }
      if (_isEventPerformerNotification(notification)) {
        await _openEventPerformerTarget(context, notification);
        return;
      }
      if (_isArtistVenueNotification(notification)) {
        await _openArtistVenueTarget(context, notification.payload);
        return;
      }
      if (_isOverthinkingNotification(notification)) {
        await _openOverthinkingTarget(context, notification);
        return;
      }
      if (_isTableNotification(notification)) {
        await _openTableTarget(context, notification);
        return;
      }
      if (_isSocialNotification(notification)) {
        await _openSocialTarget(context, notification);
        return;
      }
      if (_isBandNotification(notification)) {
        await _openBandTarget(context, notification);
      }
    } catch (_) {
      if (context.mounted && _currentOpen) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.error,
            content: const Text(
              'Bildirim hedefi şu anda açılamıyor. Tekrar dene.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingTarget = false);
    }
  }

  bool _isDmNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'DM' || notification.type.startsWith('DM');
  }

  PushTarget _pushTargetFor({String? conversationId}) => PushTarget(
    notificationId: notification.id,
    recipientId: notification.recipientId,
    type: notification.type,
    conversationId: conversationId,
  );

  Future<void> _openDirect(Widget opener) => NotificationDirectOpen.start(
    context,
    identity: notification.id,
    builder: (_) => opener,
  );

  bool get _isGhostContextualIdentity {
    final Object? rawVisibility;
    if (_isDmNotification(notification)) {
      rawVisibility = notification.payload['senderVisibilityMode'];
    } else if (_isSocialNotification(notification)) {
      rawVisibility = notification.payload['followerVisibilityMode'];
    } else {
      return false;
    }
    return parseContextualListenerVisibilityMode(rawVisibility).isGhost;
  }

  bool _isCollabNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'COLLAB' || notification.type.startsWith('COLLAB_');
  }

  Future<void> _openCollabTarget(
    BuildContext context,
    AppNotification notification,
  ) => _openDirect(InboxProductNotificationOpen(notification: notification));

  bool _isStudioNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'STUDIO' ||
        notification.type.startsWith('STUDIO_RESERVATION');
  }

  Future<void> _openStudioReservationTarget(
    BuildContext context,
    AppNotification notification,
  ) => _openDirect(
    StudioReservationNotificationOpenScreen(target: _pushTargetFor()),
  );

  bool _isArtistVenueNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'ARTIST_VENUE' ||
        notification.type.startsWith('ARTIST_VENUE');
  }

  bool _isEventPerformerNotification(AppNotification notification) {
    final module =
        notification.payload['module']?.toString().trim().toUpperCase() ?? '';
    final type = notification.type.trim().toUpperCase();
    return module == 'EVENT_PERFORMER' ||
        module == 'EVENT_PLAN' ||
        type.startsWith('EVENT_PERFORMER_');
  }

  Future<void> _openEventPerformerTarget(
    BuildContext context,
    AppNotification notification,
  ) async {
    if (!_currentOpen) return;
    await _openDirect(VenueNotificationOpenScreen(target: _pushTargetFor()));
  }

  bool _isOverthinkingNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'OVERTHINKING' ||
        notification.type.startsWith('OVERTHINKING');
  }

  bool _isTableNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'TABLE' || notification.type.startsWith('TABLE');
  }

  bool _isSocialNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'SOCIAL' || notification.type.startsWith('SOCIAL');
  }

  bool _isBandNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'BAND' || notification.type.startsWith('BAND');
  }

  Future<void> _openOverthinkingTarget(
    BuildContext context,
    AppNotification notification,
  ) => _openDirect(InboxProductNotificationOpen(notification: notification));

  Future<void> _openArtistVenueTarget(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    if (!_currentOpen) return;
    await _openDirect(VenueNotificationOpenScreen(target: _pushTargetFor()));
  }

  Future<void> _openTableTarget(
    BuildContext context,
    AppNotification notification,
  ) => _openDirect(TableNotificationOpenScreen(notification: notification));

  Future<void> _openSocialTarget(
    BuildContext context,
    AppNotification notification,
  ) async {
    final payload = notification.payload;
    final action = payload['action']?.toString().trim() ?? '';
    final bandId = payload['bandId']?.toString().trim() ?? '';
    if (action == 'NEW_BAND_FOLLOWER' && bandId.isNotEmpty) {
      await _pushNamedTarget(
        AppRoutes.bandMemberProfile,
        arguments: BandProfileScreenArgs(
          bandId: bandId,
          viewMode: BandProfileViewMode.auto,
        ),
      );
      return;
    }

    final followerId = payload['followerId']?.toString().trim() ?? '';
    if (followerId.isEmpty) return;
    final followerUsername =
        payload['followerUsername']?.toString().trim() ?? '';
    final followerAvatarUrl = _followerAvatarUrl(payload);
    final followerVisibilityMode = parseContextualListenerVisibilityMode(
      payload['followerVisibilityMode'],
    );
    final resolver = serviceLocator<DmUserProfileResolver>();
    final resolvedTargets = await resolver.resolveByUserId(
      userId: followerId,
      usernameHint: followerUsername,
    );
    if (!context.mounted || !_currentOpen) return;
    final targets = resolvedTargets
        .map(
          (target) =>
              followerVisibilityMode.isGhost &&
                  target.type == DmProfileTargetType.listener
              ? DmProfileTarget(
                  type: target.type,
                  id: target.id,
                  displayName: followerUsername.isEmpty
                      ? target.displayName
                      : followerUsername,
                  imageUrl: followerAvatarUrl.isEmpty
                      ? target.imageUrl
                      : followerAvatarUrl,
                  visibilityMode: followerVisibilityMode,
                )
              : target,
        )
        .where((target) => dmProfileRouteFor(target) != null)
        .toList(growable: false);
    if (targets.isEmpty) return;
    if (targets.length == 1) {
      await _navigateToProfileTarget(context, targets.first);
      return;
    }
    final selected = await showModalBottomSheet<DmProfileTarget>(
      context: context,
      showDragHandle: true,
      builder: (_) => _SocialProfileTargetSheet(items: targets),
    );
    if (!context.mounted || selected == null || !_currentOpen) return;
    await _navigateToProfileTarget(context, selected);
  }

  Future<void> _navigateToProfileTarget(
    BuildContext context,
    DmProfileTarget target,
  ) async {
    final route = dmProfileRouteFor(target);
    if (route == null) return;
    await _pushNamedTarget(
      route.routeName,
      arguments: route.arguments,
      acknowledge: route.routeName != AppRoutes.studioListenerInfo,
    );
  }

  Future<void> _openBandTarget(
    BuildContext context,
    AppNotification notification,
  ) => _openDirect(BandNotificationOpenScreen(target: _pushTargetFor()));

  String _followerAvatarUrl(Map<String, dynamic> payload) {
    for (final key in const [
      'followerAvatarUrl',
      'followerProfilePictureUrl',
      'followerProfilePicture',
      'profilePictureUrl',
      'avatarUrl',
    ]) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _timeLabel(DateTime? createdAt) {
    if (createdAt == null) return 'Şimdi';
    final now = DateTime.now();
    var localCreatedAt = createdAt.toLocal();
    var diff = now.difference(localCreatedAt);
    if (diff.inSeconds < -60 && diff.inHours > -6) {
      final timezoneAdjusted = localCreatedAt.subtract(
        const Duration(hours: 3),
      );
      final adjustedDiff = now.difference(timezoneAdjusted);
      if (!adjustedDiff.isNegative) {
        localCreatedAt = timezoneAdjusted;
        diff = adjustedDiff;
      }
    }
    if (diff.inSeconds < 60) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${localCreatedAt.day.toString().padLeft(2, '0')}.'
        '${localCreatedAt.month.toString().padLeft(2, '0')}.'
        '${localCreatedAt.year}';
  }

  String _displayText(String value) {
    var text = value.trim();
    for (final entry in _turkishNotificationTextFixes.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text;
  }
}

const Map<String, String> _turkishNotificationTextFixes = {
  'Ä±': 'ı',
  'Ä°': 'İ',
  'ÄŸ': 'ğ',
  'Äž': 'Ğ',
  'Ã¼': 'ü',
  'Ãœ': 'Ü',
  'Ã¶': 'ö',
  'Ã–': 'Ö',
  'ÅŸ': 'ş',
  'Å': 'Ş',
  'Ã§': 'ç',
  'Ã‡': 'Ç',
  'Simdi': 'Şimdi',
  'suan': 'şu an',
  'Su an': 'Şu an',
  'once': 'önce',
  'gun': 'gün',
  'Tumunu': 'Tümünü',
  'Muzisyen': 'Müzisyen',
  'Kullanici': 'Kullanıcı',
  'kullanici': 'kullanıcı',
  'takipcin': 'takipçin',
  'takipci': 'takipçi',
  'takip etmeye basladi': 'takip etmeye başladı',
  'bandini': 'bandını',
  'bandina': 'bandına',
  'bandinin': 'bandının',
  'bandinden': 'bandından',
  'bandden': 'banddan',
  'uyesi': 'üyesi',
  'uyelerinden': 'üyelerinden',
  'uyeligin': 'üyeliğin',
  'cikarildin': 'çıkarıldın',
  'cikarildi': 'çıkarıldı',
  'ayrildi': 'ayrıldı',
  'aldi': 'aldı',
  'aldin': 'aldın',
  'gonderdi': 'gönderdi',
  'gonderilen': 'gönderilen',
  'istegi': 'isteği',
  'istegin': 'isteğin',
  'basvuru': 'başvuru',
  'Basvuru': 'Başvuru',
  'basvurun': 'başvurun',
  'Basvurun': 'Başvurun',
  'basladi': 'başladı',
  'onaylandi': 'onaylandı',
  'reddedildi': 'reddedildi',
  'Katildigin': 'Katıldığın',
  'katildigin': 'katıldığın',
  'Katilimci': 'Katılımcı',
  'katilimci': 'katılımcı',
  'katilim': 'katılım',
  'Mekan': 'Mekân',
  'mekanina': 'mekânına',
  'mekana': 'mekâna',
  'baglanti': 'bağlantı',
  'adli': 'adlı',
  'goruntuleme': 'görüntüleme',
  'paylasimina': 'paylaşımına',
  'profilini paylasmak': 'profilini paylaşmak',
  'Artik': 'Artık',
  'Yazar su an': 'Yazar şu an',
  'Yeni bir takipçin var.': 'Yeni bir takipçin var.',
  'Yeni bir takipcin var.': 'Yeni bir takipçin var.',
};
