import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../../dm/presentation/screens/dm_chat_screen.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../overthinking/domain/overthinking_repository.dart';
import '../../../overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import '../../../overthinking/presentation/screens/overthinking_feed_screen.dart';
import '../../../overthinking/presentation/screens/overthinking_manage_screen.dart';
import '../../../profile/presentation/screens/band_invite_decision_screen.dart';
import '../../../profile/presentation/screens/band_profile_screen.dart';
import '../../../profile/presentation/screens/musician_profile_screen.dart';
import '../../../profile/presentation/screens/profile_route_args.dart';
import '../../../tablegroup/presentation/screens/table_group_detail_screen.dart';
import '../../domain/entities/app_notification.dart';
import '../cubit/notification_cubit.dart';
import '../cubit/notification_state.dart';

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

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

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
        onTap: () => _handleTap(context),
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
    await context.read<NotificationCubit>().markAsRead(notification);
    if (!context.mounted) return;
    if (_isDmNotification(notification)) {
      final senderId =
          notification.payload['senderId']?.toString().trim() ?? '';
      if (senderId.isEmpty) return;
      final args = await _resolveDmChatArgs(notification, senderId);
      if (!context.mounted) return;
      Navigator.of(context).pushNamed(AppRoutes.dmChat, arguments: args);
      return;
    }
    if (_isArtistVenueNotification(notification)) {
      _openArtistVenueTarget(context, notification.payload);
      return;
    }
    if (_isOverthinkingNotification(notification)) {
      await _openOverthinkingTarget(context, notification);
      return;
    }
    if (_isTableNotification(notification)) {
      _openTableTarget(context, notification);
      return;
    }
    if (_isSocialNotification(notification)) {
      await _openSocialTarget(context, notification);
      return;
    }
    if (_isBandNotification(notification)) {
      _openBandTarget(context, notification);
    }
  }

  bool _isDmNotification(AppNotification notification) {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'DM' || notification.type.startsWith('DM');
  }

  Future<DmChatScreenArgs> _resolveDmChatArgs(
    AppNotification notification,
    String senderId,
  ) async {
    final senderUsername =
        notification.payload['senderUsername']?.toString().trim() ?? '';
    final senderAvatarUrl = _senderAvatarUrl(notification.payload);

    try {
      final targets = await serviceLocator<DmUserProfileResolver>()
          .resolveByUserId(userId: senderId, usernameHint: senderUsername);
      final target = _preferredDmTarget(targets);
      if (target != null) {
        return DmChatScreenArgs(
          conversationId: _cleanNullable(
            notification.payload['conversationId']?.toString(),
          ),
          otherUserId: senderId,
          otherUsername: target.displayName,
          otherUserProfilePicture: _cleanNullable(target.imageUrl),
        );
      }
    } catch (_) {
      // Bildirimden mesaja giris, profil cozumu basarisiz olsa da calismali.
    }

    return DmChatScreenArgs(
      conversationId: _cleanNullable(
        notification.payload['conversationId']?.toString(),
      ),
      otherUserId: senderId,
      otherUsername: _cleanNullable(senderUsername),
      otherUserProfilePicture: _cleanNullable(senderAvatarUrl),
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

  void _openArtistVenueTarget(
    BuildContext context,
    Map<String, dynamic> payload,
  ) {
    final requestByType = payload['requestByType']?.toString().trim() ?? '';
    final action = payload['action']?.toString().trim() ?? '';
    final bandId = payload['bandId']?.toString().trim() ?? '';

    if (requestByType == 'BAND' &&
        bandId.isNotEmpty &&
        action != 'REQUEST_CREATED') {
      Navigator.of(context).pushNamed(
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
      Navigator.of(context).pushNamed(
        AppRoutes.venueProfile,
        arguments: const VenueProfileArgs(openIncomingApplications: true),
      );
      return;
    }

    if (requestByType == 'VENUE') {
      Navigator.of(context).pushNamed(
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

    Navigator.of(context).pushNamed(
      action == 'REQUEST_CREATED'
          ? AppRoutes.venueProfile
          : AppRoutes.musicianProfile,
    );
  }

  void _openTableTarget(BuildContext context, AppNotification notification) {
    final payload = notification.payload;
    if (_shouldOpenTableList(notification.type)) {
      Navigator.of(context).pushNamed(AppRoutes.tableGroupList);
      return;
    }
    final tableGroupId = payload['tableGroupId']?.toString().trim() ?? '';
    if (tableGroupId.isEmpty) {
      Navigator.of(context).pushNamed(AppRoutes.tableGroupList);
      return;
    }
    Navigator.of(context).pushNamed(
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
      Navigator.of(context).pushNamed(
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
    final resolver = serviceLocator<DmUserProfileResolver>();
    final targets = await resolver.resolveByUserId(
      userId: followerId,
      usernameHint: followerUsername,
    );
    if (!context.mounted || targets.isEmpty) return;
    if (targets.length == 1) {
      _navigateToProfileTarget(context, targets.first);
      return;
    }
    final selected = await showModalBottomSheet<DmProfileTarget>(
      context: context,
      showDragHandle: true,
      builder: (_) => _SocialProfileTargetSheet(items: targets),
    );
    if (!context.mounted || selected == null) return;
    _navigateToProfileTarget(context, selected);
  }

  void _navigateToProfileTarget(BuildContext context, DmProfileTarget target) {
    switch (target.type) {
      case DmProfileTargetType.musician:
        Navigator.of(context).pushNamed(
          AppRoutes.musicianPublicProfile,
          arguments: {'profileId': target.id},
        );
        return;
      case DmProfileTargetType.venue:
        Navigator.of(context).pushNamed(
          AppRoutes.venuePublicProfile,
          arguments: {'venueId': target.id},
        );
        return;
    }
  }

  void _openBandTarget(BuildContext context, AppNotification notification) {
    final action = notification.payload['action']?.toString().trim() ?? '';
    final bandId = notification.payload['bandId']?.toString().trim() ?? '';
    if (action == 'INVITE_RECEIVED' && bandId.isNotEmpty) {
      final bandName =
          notification.payload['bandName']?.toString().trim() ?? '';
      Navigator.of(context).push(
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
      Navigator.of(context).pushNamed(AppRoutes.myBands);
      return;
    }
    if (bandId.isEmpty) {
      Navigator.of(context).pushNamed(AppRoutes.myBands);
      return;
    }
    Navigator.of(context).pushNamed(
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

class _NotificationTypeIcon extends StatelessWidget {
  final AppNotification notification;
  final bool unread;

  const _NotificationTypeIcon({
    required this.notification,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _notificationAvatarUrl;
    if ((_isDmNotification ||
            _isSocialNotification ||
            _isArtistVenueNotification) &&
        avatarUrl.isNotEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: unread
              ? LinearGradient(colors: AppColors.brandGradient)
              : null,
        ),
        padding: unread ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackIcon(context),
          ),
        ),
      );
    }
    return _iconContainer(context, _iconForType);
  }

  bool get _isDmNotification {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'DM' || notification.type.startsWith('DM');
  }

  bool get _isSocialNotification {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'SOCIAL' || notification.type.startsWith('SOCIAL');
  }

  bool get _isArtistVenueNotification {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'ARTIST_VENUE' ||
        notification.type.startsWith('ARTIST_VENUE');
  }

  String get type => notification.type;

  String get _notificationAvatarUrl {
    for (final key in const [
      'actorAvatarUrl',
      'actorProfilePictureUrl',
      'actorProfilePicture',
      'senderAvatarUrl',
      'senderProfilePictureUrl',
      'senderProfilePicture',
      'applicantAvatarUrl',
      'applicantProfilePictureUrl',
      'applicantProfilePicture',
      'venueAvatarUrl',
      'venueProfilePictureUrl',
      'venueProfilePicture',
      'followerAvatarUrl',
      'followerProfilePictureUrl',
      'followerProfilePicture',
      'profilePictureUrl',
      'avatarUrl',
    ]) {
      final value = notification.payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Widget _fallbackIcon(BuildContext context) {
    return _iconContainer(context, _iconForType);
  }

  IconData get _iconForType {
    return switch (type) {
      final value when value.startsWith('OVERTHINKING') =>
        Icons.psychology_alt_outlined,
      final value when value.startsWith('BAND') => Icons.album_outlined,
      final value when value.startsWith('TABLE') => Icons.groups_2_outlined,
      final value when value.startsWith('MEDIA') => Icons.play_circle_outline,
      final value when value.startsWith('DM') => Icons.forum_outlined,
      final value when value.startsWith('ARTIST_VENUE') =>
        Icons.handshake_outlined,
      final value when value.startsWith('SOCIAL') =>
        Icons.person_add_alt_outlined,
      _ => Icons.notifications_none_outlined,
    };
  }

  Widget _iconContainer(BuildContext context, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unread
            ? LinearGradient(colors: AppColors.brandGradient)
            : null,
        color: unread
            ? null
            : Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        icon,
        color: unread ? Colors.white : Theme.of(context).colorScheme.onSurface,
        size: 21,
      ),
    );
  }
}

class _SocialProfileTargetSheet extends StatelessWidget {
  final List<DmProfileTarget> items;

  const _SocialProfileTargetSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: _hasImage(item.imageUrl)
                  ? NetworkImage(item.imageUrl!.trim())
                  : null,
              child: _hasImage(item.imageUrl)
                  ? null
                  : const Icon(Icons.person_outline_rounded),
            ),
            title: Text(item.displayName),
            subtitle: Text(
              item.type == DmProfileTargetType.musician ? 'Müzisyen' : 'Mekân',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pop(item),
          );
        },
      ),
    );
  }

  bool _hasImage(String? value) {
    final url = value?.trim() ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }
}

class _NotificationLoadingList extends StatelessWidget {
  const _NotificationLoadingList();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
      children: [
        Icon(
          Icons.notifications_none_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 14),
        Text(
          'Bildirim yok',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
