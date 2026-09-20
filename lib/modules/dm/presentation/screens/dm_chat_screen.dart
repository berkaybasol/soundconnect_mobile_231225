import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../profile/domain/entities/listener_visibility_context.dart';
import '../../../profile/domain/entities/listener_visibility_mode.dart';
import '../../domain/dm_user_profile_resolver.dart';
import '../../domain/entities/dm_message.dart';
import '../../domain/entities/dm_profile_target.dart';
import '../../../notification/presentation/cubit/notification_cubit.dart';
import '../cubit/dm_chat_cubit.dart';
import '../cubit/dm_chat_state.dart';
import '../dm_profile_navigation.dart';
import '../dm_visual_theme.dart';
import '../widgets/dm_visual_components.dart';

class DmChatScreenArgs {
  final String otherUserId;
  final String? otherUsername;
  final String? otherUserProfilePicture;
  final String? currentUserId;
  final String? otherMusicianProfileId;
  final String? conversationId;
  final ListenerVisibilityMode otherUserVisibilityMode;
  final bool otherUserDeleted;

  DmChatScreenArgs({
    required this.otherUserId,
    this.otherUsername,
    this.otherUserProfilePicture,
    this.currentUserId,
    this.otherMusicianProfileId,
    this.conversationId,
    this.otherUserVisibilityMode = ListenerVisibilityMode.standard,
    this.otherUserDeleted = false,
  });
}

class DmChatScreen extends StatelessWidget {
  DmChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return BlocProvider(
      create: (_) => serviceLocator<DmChatCubit>(),
      child: DmVisualThemeScope(child: _DmChatView()),
    );
  }
}

class _DmChatView extends StatefulWidget {
  _DmChatView();

  @override
  State<_DmChatView> createState() => _DmChatViewState();
}

class _DmChatViewState extends State<_DmChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DmChatScreenArgs? _args;
  int _lastMessageCount = 0;
  String? _lastNewestMessageId;
  bool _identityHydrationStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args != null) return;
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    if (rawArgs is DmChatScreenArgs) {
      _args = rawArgs;
    } else if (rawArgs is Map<String, dynamic>) {
      final userId = rawArgs['otherUserId']?.toString() ?? '';
      if (userId.trim().isNotEmpty) {
        _args = DmChatScreenArgs(
          otherUserId: userId,
          otherUsername: rawArgs['otherUsername']?.toString(),
          otherUserProfilePicture: rawArgs['otherUserProfilePicture']
              ?.toString(),
          currentUserId: rawArgs['currentUserId']?.toString(),
          otherMusicianProfileId: rawArgs['otherMusicianProfileId']?.toString(),
          conversationId: rawArgs['conversationId']?.toString(),
          otherUserDeleted: rawArgs['otherUserDeleted'] == true,
          otherUserVisibilityMode: parseContextualListenerVisibilityMode(
            rawArgs['otherUserVisibilityMode'],
          ),
        );
      }
    }
    final args = _args;
    if (args == null || args.otherUserId.trim().isEmpty) return;
    context.read<DmChatCubit>().openOrCreateConversation(
      otherUserId: args.otherUserId,
      currentUserId: args.currentUserId,
      recipientDeleted: args.otherUserDeleted,
    );
    if (!_identityHydrationStarted) {
      _identityHydrationStarted = true;
      unawaited(_hydrateGhostIdentity(args));
    }
  }

  Future<void> _hydrateGhostIdentity(DmChatScreenArgs args) async {
    if (args.otherUserDeleted || args.otherUserVisibilityMode.isGhost) return;
    if (!serviceLocator.isRegistered<DmUserProfileResolver>()) return;
    final targets = await serviceLocator<DmUserProfileResolver>()
        .resolveByUserId(
          userId: args.otherUserId,
          usernameHint: args.otherUsername,
        );
    DmProfileTarget? ghostTarget;
    for (final target in targets) {
      if (target.isGhostListener) {
        ghostTarget = target;
        break;
      }
    }
    final resolvedGhostTarget = ghostTarget;
    if (!mounted ||
        resolvedGhostTarget == null ||
        context.read<DmChatCubit>().state.recipientDeleted) {
      return;
    }
    setState(() {
      _args = DmChatScreenArgs(
        otherUserId: args.otherUserId,
        otherUsername: resolvedGhostTarget.displayName,
        otherUserProfilePicture: resolvedGhostTarget.imageUrl,
        currentUserId: args.currentUserId,
        conversationId: args.conversationId,
        otherUserVisibilityMode: resolvedGhostTarget.visibilityMode,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 140) {
      context.read<DmChatCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    final args = _args;
    final deleted = context.select<DmChatCubit, bool>(
      (cubit) => cubit.state.recipientDeleted,
    );
    final resolvedUsername = args?.otherUsername?.trim() ?? '';
    final resolvedUserId = args?.otherUserId.trim() ?? '';
    final title = deleted
        ? 'Silinmiş hesap'
        : resolvedUsername.isNotEmpty
        ? resolvedUsername
        : (resolvedUserId.isNotEmpty ? resolvedUserId : 'Mesajlar');
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final toolbarHeight = textScale > 1.8
        ? 112.0
        : textScale > 1.4
        ? 88.0
        : 70.0;
    final actionVerticalPadding = (toolbarHeight - 48) / 2;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: toolbarHeight,
        leadingWidth: 64,
        leading: Padding(
          padding: EdgeInsets.only(
            left: 16,
            top: actionVerticalPadding,
            bottom: actionVerticalPadding,
          ),
          child: DmHeaderAction(
            tooltip: 'Mesajlara dön',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icons.arrow_back_rounded,
          ),
        ),
        titleSpacing: 4,
        title: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: deleted ? null : _openRelatedProfile,
          child: Row(
            children: [
              DmAvatar(
                size: 38,
                imageUrl: !deleted ? args?.otherUserProfilePicture : null,
                fallbackText: deleted ? null : title,
                fallbackIcon: deleted
                    ? Icons.person_off_outlined
                    : Icons.person_outline_rounded,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            deleted ? 'Mesaj geçmişi' : 'Doğrudan mesaj',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (!deleted &&
                            args?.otherUserVisibilityMode.isGhost == true) ...[
                          const SizedBox(width: 7),
                          const GhostProfileBadge(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(
              right: 16,
              top: actionVerticalPadding,
              bottom: actionVerticalPadding,
            ),
            child: DmHeaderAction(
              tooltip: 'Sohbeti yenile',
              onPressed: () => context.read<DmChatCubit>().refresh(),
              icon: Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocConsumer<DmChatCubit, DmChatState>(
                listener: (context, state) {
                  if (state.status == DmChatStatus.failure &&
                      state.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      appSnackBar(
                        context,
                        tone: AppSnackBarTone.error,
                        content: Text(state.error!.message),
                      ),
                    );
                  }
                  final conversationId =
                      state.conversationId?.trim() ??
                      args?.conversationId?.trim() ??
                      '';
                  if (conversationId.isNotEmpty &&
                      state.status == DmChatStatus.success) {
                    if (serviceLocator.isRegistered<NotificationCubit>()) {
                      serviceLocator<NotificationCubit>()
                          .markDmConversationAsReadLocally(conversationId);
                    }
                  }
                  final newestMessageId = state.messages.isEmpty
                      ? null
                      : state.messages.last.messageId;
                  final shouldScrollToBottom =
                      state.messages.length != _lastMessageCount &&
                      newestMessageId != null &&
                      newestMessageId != _lastNewestMessageId;
                  _lastNewestMessageId = newestMessageId;
                  if (shouldScrollToBottom) {
                    _lastMessageCount = state.messages.length;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_scrollController.hasClients) return;
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      );
                    });
                  } else {
                    _lastMessageCount = state.messages.length;
                  }
                },
                builder: (context, state) {
                  if (state.status == DmChatStatus.loading &&
                      state.messages.isEmpty) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (state.messages.isEmpty) {
                    return _ChatEmptyState();
                  }
                  return NotificationListener<ScrollNotification>(
                    onNotification: (_) {
                      _onScroll();
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                      itemCount:
                          state.messages.length +
                          (state.status == DmChatStatus.loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 0 &&
                            state.status == DmChatStatus.loadingMore) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final messageIndex =
                            state.status == DmChatStatus.loadingMore
                            ? index - 1
                            : index;
                        if (messageIndex < 0 ||
                            messageIndex >= state.messages.length) {
                          return SizedBox.shrink();
                        }
                        final item = state.messages[messageIndex];
                        final previous = messageIndex > 0
                            ? state.messages[messageIndex - 1]
                            : null;
                        final showDateHeader = !_isSameDay(
                          previous?.sentAt,
                          item.sentAt,
                        );
                        final isMine =
                            args != null && item.senderId != args.otherUserId;
                        final senderAvatarUrl = isMine
                            ? null
                            : args?.otherUserProfilePicture;
                        return Column(
                          children: [
                            if (showDateHeader) _DateHeader(date: item.sentAt),
                            _DmMessageBubble(
                              message: item,
                              isMine: isMine,
                              senderAvatarUrl: senderAvatarUrl,
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (deleted)
              Container(
                key: Key('dm-deleted-account-readonly'),
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outline),
                ),
                child: const Text(
                  'Bu hesap silindi. Mesaj geçmişini okuyabilirsin; yeni mesaj gönderemezsin.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              _composer(),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outline),
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                cursorColor: AppColors.coralLight,
                style: const TextStyle(fontSize: 14.5, height: 1.25),
                decoration: const InputDecoration(
                  hintText: 'Mesaj yaz…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          BlocBuilder<DmChatCubit, DmChatState>(
            builder: (context, state) {
              return GradientOutline(
                enabled: AppColors.isLight,
                radius: 23,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppColors.isLight
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: AppColors.actionSocialGradient,
                          ),
                    shape: BoxShape.circle,
                    boxShadow: AppColors.isLight
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.socialPink.withValues(
                                alpha: 0.22,
                              ),
                              blurRadius: 16,
                              spreadRadius: -4,
                            ),
                          ],
                  ),
                  child: IconButton(
                    onPressed: state.sending ? null : _send,
                    icon: state.sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.actionForeground,
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            color: AppColors.actionForeground,
                            size: 21,
                          ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final sent = await context.read<DmChatCubit>().send(text);
    if (sent) {
      _messageController.clear();
    }
  }

  Future<void> _openRelatedProfile() async {
    final args = _args;
    if (args == null ||
        !mounted ||
        context.read<DmChatCubit>().state.recipientDeleted) {
      return;
    }
    final musicianProfileId = args.otherMusicianProfileId?.trim() ?? '';
    if (musicianProfileId.isNotEmpty) {
      _navigateToProfile(
        DmProfileTarget(
          type: DmProfileTargetType.musician,
          id: musicianProfileId,
          displayName: args.otherUsername?.trim().isNotEmpty == true
              ? args.otherUsername!.trim()
              : 'Müzisyen',
          imageUrl: args.otherUserProfilePicture,
        ),
      );
      return;
    }
    final resolver = serviceLocator<DmUserProfileResolver>();
    final resolved = await resolver.resolveByUserId(
      userId: args.otherUserId,
      usernameHint: args.otherUsername,
    );
    if (!mounted) return;
    final navigable = resolved
        .where((target) => dmProfileRouteFor(target) != null)
        .toList(growable: false);
    if (navigable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: const Text(
            'Bu kullanıcı için görüntülenebilir profil bulunamadı.',
          ),
        ),
      );
      return;
    }
    if (navigable.length == 1) {
      _navigateToProfile(navigable.first);
      return;
    }
    final selected = await showModalBottomSheet<DmProfileTarget>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ProfileTargetSheet(items: navigable),
    );
    if (!mounted || selected == null) return;
    _navigateToProfile(selected);
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    final aa = a.toLocal();
    final bb = b.toLocal();
    return aa.year == bb.year && aa.month == bb.month && aa.day == bb.day;
  }

  void _navigateToProfile(DmProfileTarget target) {
    final route = dmProfileRouteFor(target);
    if (route == null) return;
    Navigator.of(
      context,
    ).pushNamed(route.routeName, arguments: route.arguments);
  }
}

class _ChatEmptyState extends StatelessWidget {
  _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DmGradientIconPanel(icon: Icons.mark_chat_unread_outlined),
              const SizedBox(height: 18),
              const Text(
                'Sohbet burada başlıyor',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'İlk mesajını göndererek müziğin etrafında yeni bir bağlantı kur.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  _DateHeader({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    final text = _formatDate(date);
    if (text.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 8, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(height: 1, color: Theme.of(context).dividerColor),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 10),
            padding: EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Divider(height: 1, color: Theme.of(context).dividerColor),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'Bugun';
    if (day == today.subtract(Duration(days: 1))) return 'Dun';
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yy = local.year.toString();
    return '$dd.$mm.$yy';
  }
}

class _DmMessageBubble extends StatelessWidget {
  final DmMessage message;
  final bool isMine;
  final String? senderAvatarUrl;

  _DmMessageBubble({
    required this.message,
    required this.isMine,
    required this.senderAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    final timeText = _formatTime(message.sentAt);
    final colors = Theme.of(context).colorScheme;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: isMine
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.isLight
                    ? AppColors.actionGradient
                    : [AppColors.gradientA, AppColors.gradientC],
              )
            : null,
        color: isMine ? null : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 6),
          bottomRight: Radius.circular(isMine ? 6 : 18),
        ),
        border: Border.all(color: isMine ? Colors.transparent : colors.outline),
        boxShadow: isMine
            ? [
                BoxShadow(
                  color: AppColors.socialPink.withValues(alpha: 0.12),
                  blurRadius: 14,
                  spreadRadius: -5,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: TextStyle(
              color: isMine && colors.brightness == Brightness.light
                  ? AppColors.onAccent
                  : colors.onSurface,
              height: 1.32,
            ),
          ),
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeText,
                style: TextStyle(
                  color: isMine
                      ? AppColors.actionForeground.withValues(alpha: 0.84)
                      : colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              if (isMine) ...[
                SizedBox(width: 6),
                Icon(
                  message.readAt == null
                      ? Icons.done_rounded
                      : Icons.done_all_rounded,
                  size: 14,
                  color: message.readAt == null
                      ? AppColors.actionForeground.withValues(alpha: 0.78)
                      : AppColors.actionForeground,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: isMine
            ? bubble
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DmAvatar(
                    size: 28,
                    imageUrl: senderAvatarUrl,
                    fallbackIcon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(width: 7),
                  bubble,
                ],
              ),
      ),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '--:--';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _ProfileTargetSheet extends StatelessWidget {
  final List<DmProfileTarget> items;

  _ProfileTargetSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: Text(
              'Profili görüntüle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Material(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.outline),
                  ),
                  leading: DmAvatar(
                    size: 42,
                    imageUrl: item.imageUrl,
                    fallbackText: item.displayName,
                    fallbackIcon: switch (item.type) {
                      DmProfileTargetType.musician =>
                        Icons.person_outline_rounded,
                      DmProfileTargetType.venue => Icons.storefront_outlined,
                      DmProfileTargetType.listener => Icons.headphones_outlined,
                      DmProfileTargetType.studio => Icons.graphic_eq_outlined,
                    },
                  ),
                  title: Text(
                    item.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: item.isGhostListener
                      ? Row(
                          children: [
                            Text(item.type.displayLabel),
                            const SizedBox(width: 7),
                            const GhostProfileBadge(),
                          ],
                        )
                      : Text(item.type.displayLabel),
                  trailing: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  onTap: () => Navigator.of(context).pop(item),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
