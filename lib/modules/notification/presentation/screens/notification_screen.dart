import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../collab/presentation/collab_route_args.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../../dm/presentation/dm_profile_navigation.dart';
import '../../../dm/presentation/screens/dm_chat_screen.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../overthinking/domain/overthinking_repository.dart';
import '../../../overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import '../../../overthinking/presentation/screens/overthinking_feed_screen.dart';
import '../../../overthinking/presentation/screens/overthinking_manage_screen.dart';
import '../../../profile/domain/entities/listener_visibility_context.dart';
import '../../../profile/domain/entities/event_performer_request.dart';
import '../../../profile/domain/entities/venue_event_detail.dart';
import '../../../profile/domain/venue_event_repository.dart';
import '../../../profile/presentation/screens/band_invite_decision_screen.dart';
import '../../../profile/presentation/screens/band_profile_screen.dart';
import '../../../profile/presentation/screens/event_invitation_navigation.dart';
import '../../../profile/presentation/screens/musician_profile_screen.dart';
import '../../../profile/presentation/screens/profile_route_args.dart';
import '../../../profile/presentation/screens/studio_profile_screen.dart';
import '../../../profile/presentation/screens/weekly_event_detail_screen.dart';
import '../../../tablegroup/presentation/screens/table_group_detail_screen.dart';
import '../../domain/entities/app_notification.dart';
import '../cubit/notification_cubit.dart';
import '../cubit/notification_state.dart';

part 'notification_screen_support_widgets.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationCubit>().refresh();
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationCubit, NotificationState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        final error = state.errorMessage;
        if (error == null || error.trim().isEmpty) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
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
                : ListView.separated(
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
                      return _NotificationTile(notification: item);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount:
                        state.items.length +
                        (state.status == NotificationStatus.loadingMore
                            ? 1
                            : 0),
                  ),
          ),
        );
      },
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

  const _NotificationTile({required this.notification});

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _openingTarget = false;

  AppNotification get notification => widget.notification;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    final colors = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.coralAlt,
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
                              color: AppColors.coralAlt,
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
    setState(() => _openingTarget = true);
    unawaited(context.read<NotificationCubit>().markAsRead(notification));
    try {
      if (_isDmNotification(notification)) {
        final senderId =
            notification.payload['senderId']?.toString().trim() ?? '';
        if (senderId.isEmpty) return;
        final args = await _resolveDmChatArgs(notification, senderId);
        if (!context.mounted) return;
        await Navigator.of(
          context,
        ).pushNamed(AppRoutes.dmChat, arguments: args);
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
    } finally {
      if (mounted) setState(() => _openingTarget = false);
    }
  }

  bool _isDmNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'DM' || notification.type.startsWith('DM');
  }

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
  ) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.collabDiscovery,
      arguments: CollabDiscoveryRouteArgs.fromNotificationPayload(
        notification.payload,
      ),
    );
  }

  bool _isStudioNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'STUDIO' ||
        notification.type.startsWith('STUDIO_RESERVATION');
  }

  Future<void> _openStudioReservationTarget(
    BuildContext context,
    AppNotification notification,
  ) async {
    final roomId = notification.payload['roomId']?.toString().trim() ?? '';
    final studioProfileId =
        notification.payload['studioProfileId']?.toString().trim() ?? '';
    if (studioProfileId.isEmpty) return;
    final action = notification.payload['action']?.toString().trim() ?? '';
    if (action == 'CANCELLED_BY_STUDIO_ROOM_ARCHIVED') {
      await Navigator.of(context).pushNamed(
        AppRoutes.studioPublicProfile,
        arguments: PublicProfileArgs(profileId: studioProfileId),
      );
      return;
    }
    if (roomId.isEmpty) return;
    final ownerMode =
        notification.type == 'STUDIO_RESERVATION_CREATED' ||
        notification.type == 'STUDIO_RESERVATION_CONFLICTING_REQUESTS' ||
        notification.type == 'STUDIO_RESERVATION_CANCELLED_BY_CUSTOMER';
    final zoneId =
        notification.payload['zoneId']?.toString().trim() ?? 'Europe/Istanbul';
    final reservationDate = DateTime.tryParse(
      notification.payload['localDate']?.toString().trim() ?? '',
    );
    final reservationId = notification.payload['reservationId']
        ?.toString()
        .trim();
    await Navigator.of(context).pushNamed(
      AppRoutes.studioReservationCalendar,
      arguments: StudioReservationCalendarArgs(
        roomId: roomId,
        studioProfileId: studioProfileId,
        ownerMode: ownerMode,
        timeZone: zoneId.isEmpty ? 'Europe/Istanbul' : zoneId,
        reservationDate: reservationDate,
        reservationId: reservationId?.isEmpty == true ? null : reservationId,
      ),
    );
  }

  Future<DmChatScreenArgs> _resolveDmChatArgs(
    AppNotification notification,
    String senderId,
  ) async {
    final senderUsername =
        notification.payload['senderUsername']?.toString().trim() ?? '';
    final senderAvatarUrl = _senderAvatarUrl(notification.payload);
    final senderVisibilityMode = parseContextualListenerVisibilityMode(
      notification.payload['senderVisibilityMode'],
    );
    final conversationId = _cleanNullable(
      notification.payload['conversationId']?.toString(),
    );

    if (senderVisibilityMode.isGhost) {
      // Ghost notification payloads are sanitized by the backend at publish
      // and read time. Do not allow a stale resolver/cache result to replace
      // that authoritative identity or visibility marker.
      return DmChatScreenArgs(
        conversationId: conversationId,
        otherUserId: senderId,
        otherUsername: _cleanNullable(senderUsername),
        otherUserProfilePicture: _cleanNullable(senderAvatarUrl),
        otherUserVisibilityMode: senderVisibilityMode,
      );
    }

    try {
      final targets = await serviceLocator<DmUserProfileResolver>()
          .resolveByUserId(userId: senderId, usernameHint: senderUsername);
      final target = _preferredDmTarget(targets);
      if (target != null) {
        return DmChatScreenArgs(
          conversationId: conversationId,
          otherUserId: senderId,
          otherUsername: target.displayName,
          otherUserProfilePicture: _cleanNullable(target.imageUrl),
          otherUserVisibilityMode: target.visibilityMode,
        );
      }
    } catch (_) {
      // Bildirimden mesaja giris, profil cozumu basarisiz olsa da calismali.
    }

    return DmChatScreenArgs(
      conversationId: conversationId,
      otherUserId: senderId,
      otherUsername: _cleanNullable(senderUsername),
      otherUserProfilePicture: _cleanNullable(senderAvatarUrl),
      otherUserVisibilityMode: senderVisibilityMode,
    );
  }

  DmProfileTarget? _preferredDmTarget(List<DmProfileTarget> targets) {
    for (final target in targets) {
      if (target.type == DmProfileTargetType.venue) {
        return target;
      }
    }
    return targets.isEmpty ? null : targets.first;
  }

  String? _cleanNullable(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isArtistVenueNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'ARTIST_VENUE' ||
        notification.type.startsWith('ARTIST_VENUE');
  }

  bool _isEventPerformerNotification(AppNotification notification) {
    final module =
        notification.payload['module']?.toString().trim().toUpperCase() ?? '';
    final type = notification.type.trim().toUpperCase();
    return module == 'EVENT_PERFORMER' || type.startsWith('EVENT_PERFORMER_');
  }

  Future<void> _openEventPerformerTarget(
    BuildContext context,
    AppNotification notification,
  ) async {
    final type = notification.type.trim().toUpperCase();
    final action =
        notification.payload['action']?.toString().trim().toUpperCase() ?? '';
    if (type == 'EVENT_PERFORMER_APPROVAL_REQUESTED' ||
        action == 'APPROVAL_REQUESTED') {
      final target = _performerInvitationTarget(notification);
      if (target == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Davetin ait olduğu profil doğrulanamadı.'),
          ),
        );
        return;
      }
      await openEventInvitations(
        context,
        targetType: target.type,
        targetId: target.id,
      );
      return;
    }

    final eventId = notification.payload['eventId']?.toString().trim() ?? '';
    if (eventId.isEmpty) {
      final target = _performerInvitationTarget(notification);
      if (target == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Davetin ait olduğu profil doğrulanamadı.'),
          ),
        );
        return;
      }
      await openEventInvitations(
        context,
        targetType: target.type,
        targetId: target.id,
      );
      return;
    }

    Result<VenueEventDetail> result;
    try {
      result = await serviceLocator<VenueEventRepository>().getDetail(eventId);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etkinlik ayrıntıları açılamadı.')),
      );
      return;
    }
    if (!context.mounted) return;
    final detail = result.data;
    if (!result.isSuccess || detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.error?.message ?? 'Etkinlik ayrıntıları açılamadı.',
          ),
        ),
      );
      return;
    }

    // The event detail is the current authorization source of truth. Never
    // revive a performer link from a potentially stale notification payload.
    final performerIdentity = detail.performerIdentity;
    final musicianId = performerIdentity.musicianProfileId;
    final bandId = performerIdentity.bandId;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeeklyEventDetailScreen(
          event: WeeklyCalendarEvent(
            id: eventId,
            title:
                _firstNonBlank(detail.title, notification.title) ?? 'Etkinlik',
            artistName:
                _firstNonBlank(
                  detail.performerName,
                  notification.payload['performerName']?.toString(),
                ) ??
                'Sanatçı',
            artistProfileId: musicianId,
            bandProfileId: bandId,
            performerType: performerIdentity.performerType,
            venueName:
                _firstNonBlank(
                  detail.venueName,
                  notification.payload['venueName']?.toString(),
                ) ??
                'Mekan',
            // Only live event data may authorize a venue link; an old
            // notification can still contain a pending or rejected target.
            venueId: _cleanNullable(detail.venueId),
            city: detail.venueCity ?? '-',
            district: detail.venueDistrict ?? '-',
            neighborhood: detail.venueNeighborhood ?? '-',
            eventDate: _notificationEventDate(detail.eventDate),
            startTime: _shortEventTime(detail.startTime) ?? '-',
            endTime: _shortEventTime(detail.endTime) ?? '-',
            imageAssetPath: detail.posterImage,
            description: detail.description?.trim() ?? '',
          ),
        ),
      ),
    );
  }

  ({EventPerformerTargetType? type, String? id})? _performerInvitationTarget(
    AppNotification notification,
  ) {
    final payload = notification.payload;
    const identityFields = [
      'performerType',
      'targetType',
      'musicianProfileId',
      'bandId',
      'targetId',
    ];
    // Truly legacy notifications resolve to the authenticated musician's own
    // profile in the shared navigation guard, never to an aggregate band inbox.
    if (identityFields.every((field) => payload[field] == null)) {
      return (type: null, id: null);
    }
    if (identityFields.any(
      (field) => payload[field] != null && payload[field] is! String,
    )) {
      return null;
    }
    final declared = _cleanNullable(
      payload['performerType'] as String?,
    )?.toUpperCase();
    final alternate = _cleanNullable(
      payload['targetType'] as String?,
    )?.toUpperCase();
    if (declared != null && alternate != null && declared != alternate) {
      return null;
    }
    final type = declared ?? alternate;
    final musicianId = _cleanNullable(payload['musicianProfileId'] as String?);
    final bandId = _cleanNullable(payload['bandId'] as String?);
    final targetId = _cleanNullable(payload['targetId'] as String?);
    if (type == 'MUSICIAN' &&
        musicianId != null &&
        bandId == null &&
        (targetId == null || targetId == musicianId)) {
      return (type: EventPerformerTargetType.musician, id: musicianId);
    }
    if (type == 'BAND' &&
        bandId != null &&
        musicianId == null &&
        (targetId == null || targetId == bandId)) {
      return (type: EventPerformerTargetType.band, id: bandId);
    }
    return null;
  }

  String? _firstNonBlank(String? first, String? second) {
    final normalizedFirst = first?.trim() ?? '';
    if (normalizedFirst.isNotEmpty) return normalizedFirst;
    final normalizedSecond = second?.trim() ?? '';
    return normalizedSecond.isEmpty ? null : normalizedSecond;
  }

  String _notificationEventDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String? _shortEventTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final pieces = value.split(':');
    if (pieces.length < 2) return value;
    return '${pieces[0].padLeft(2, '0')}:${pieces[1].padLeft(2, '0')}';
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
  ) async {
    final type = notification.type;
    final payload = notification.payload;
    if (type == 'OVERTHINKING_REVEAL_REQUEST_RECEIVED') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const OverthinkingManageScreen(initialTabIndex: 1),
        ),
      );
      return;
    }

    if (type == 'OVERTHINKING_REVEAL_REQUEST_REJECTED') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const OverthinkingManageScreen(initialTabIndex: 2),
        ),
      );
      return;
    }

    final postId = payload['postId']?.toString().trim() ?? '';
    if (postId.isEmpty) {
      await Navigator.of(context).pushNamed(AppRoutes.overthinkingFeed);
      return;
    }

    final result = await serviceLocator<OverthinkingRepository>().getDetail(
      postId: postId,
    );
    if (!context.mounted) return;
    if (!result.isSuccess || result.data == null) {
      await Navigator.of(context).pushNamed(AppRoutes.overthinkingFeed);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  serviceLocator<OverthinkingFeedCubit>()
                    ..refreshPost(result.data!.id),
            ),
            BlocProvider(
              create: (_) => serviceLocator<CommentThreadCubit>()
                ..load(
                  targetType: OverthinkingFeedCubit.targetType,
                  targetId: result.data!.id,
                ),
            ),
          ],
          child: OverthinkingDetailScreen(
            post: result.data!,
            revealRequesting: false,
          ),
        ),
      ),
    );
  }

  Future<void> _openArtistVenueTarget(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final requestByType = payload['requestByType']?.toString().trim() ?? '';
    final action = payload['action']?.toString().trim() ?? '';
    final bandId = payload['bandId']?.toString().trim() ?? '';

    if (requestByType == 'BAND' &&
        bandId.isNotEmpty &&
        action != 'REQUEST_CREATED') {
      await Navigator.of(context).pushNamed(
        AppRoutes.bandMemberProfile,
        arguments: BandProfileScreenArgs(
          bandId: bandId,
          viewMode: BandProfileViewMode.member,
        ),
      );
      return;
    }

    if (action == 'REQUEST_CREATED' &&
        (requestByType == 'ARTIST' || requestByType == 'BAND')) {
      await Navigator.of(context).pushNamed(
        AppRoutes.venueProfile,
        arguments: const VenueProfileArgs(openIncomingApplications: true),
      );
      return;
    }

    if (requestByType == 'VENUE') {
      await Navigator.of(context).pushNamed(
        action == 'REQUEST_CREATED'
            ? AppRoutes.musicianProfile
            : AppRoutes.venueProfile,
        arguments: action == 'REQUEST_CREATED'
            ? const MusicianProfileScreenArgs(
                openIncomingVenueApplications: true,
              )
            : null,
      );
      return;
    }

    await Navigator.of(context).pushNamed(
      action == 'REQUEST_CREATED'
          ? AppRoutes.venueProfile
          : AppRoutes.musicianProfile,
    );
  }

  Future<void> _openTableTarget(
    BuildContext context,
    AppNotification notification,
  ) async {
    final payload = notification.payload;
    if (_shouldOpenTableList(notification.type)) {
      await Navigator.of(context).pushNamed(AppRoutes.tableGroupList);
      return;
    }
    final tableGroupId = payload['tableGroupId']?.toString().trim() ?? '';
    if (tableGroupId.isEmpty) {
      await Navigator.of(context).pushNamed(AppRoutes.tableGroupList);
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.tableGroupDetail,
      arguments: TableGroupDetailArgs(tableGroupId: tableGroupId),
    );
  }

  bool _shouldOpenTableList(String type) {
    return type == 'TABLE_JOIN_REQUEST_REJECTED' ||
        type == 'TABLE_REMOVED' ||
        type == 'TABLE_CANCELLED' ||
        type == 'TABLE_EXPIRED';
  }

  Future<void> _openSocialTarget(
    BuildContext context,
    AppNotification notification,
  ) async {
    final payload = notification.payload;
    final action = payload['action']?.toString().trim() ?? '';
    final bandId = payload['bandId']?.toString().trim() ?? '';
    if (action == 'NEW_BAND_FOLLOWER' && bandId.isNotEmpty) {
      await Navigator.of(context).pushNamed(
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
    if (!context.mounted) return;
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
    if (!context.mounted || selected == null) return;
    await _navigateToProfileTarget(context, selected);
  }

  Future<void> _navigateToProfileTarget(
    BuildContext context,
    DmProfileTarget target,
  ) async {
    final route = dmProfileRouteFor(target);
    if (route == null) return;
    await Navigator.of(
      context,
    ).pushNamed(route.routeName, arguments: route.arguments);
  }

  Future<void> _openBandTarget(
    BuildContext context,
    AppNotification notification,
  ) async {
    final action = notification.payload['action']?.toString().trim() ?? '';
    final bandId = notification.payload['bandId']?.toString().trim() ?? '';
    if (action == 'INVITE_RECEIVED' && bandId.isNotEmpty) {
      final bandName =
          notification.payload['bandName']?.toString().trim() ?? '';
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BandInviteDecisionScreen(
            args: BandInviteDecisionScreenArgs(
              bandId: bandId,
              bandName: bandName.isEmpty ? null : bandName,
              title: notification.title,
              message: notification.message,
            ),
          ),
        ),
      );
      return;
    }

    if (action == 'INVITE_RECEIVED' || action == 'MEMBER_REMOVED') {
      await Navigator.of(context).pushNamed(AppRoutes.myBands);
      return;
    }
    if (bandId.isEmpty) {
      await Navigator.of(context).pushNamed(AppRoutes.myBands);
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.bandMemberProfile,
      arguments: BandProfileScreenArgs(
        bandId: bandId,
        viewMode: BandProfileViewMode.auto,
      ),
    );
  }

  String _senderAvatarUrl(Map<String, dynamic> payload) {
    for (final key in const [
      'senderAvatarUrl',
      'senderProfilePictureUrl',
      'senderProfilePicture',
      'profilePictureUrl',
      'avatarUrl',
    ]) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

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
