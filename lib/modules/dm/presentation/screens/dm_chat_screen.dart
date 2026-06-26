import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/dm_user_profile_resolver.dart';
import '../../domain/entities/dm_message.dart';
import '../../domain/entities/dm_profile_target.dart';
import '../../../notification/presentation/cubit/notification_cubit.dart';
import '../cubit/dm_chat_cubit.dart';
import '../cubit/dm_chat_state.dart';

class DmChatScreenArgs {
  final String otherUserId;
  final String? otherUsername;
  final String? otherUserProfilePicture;
  final String? currentUserId;
  final String? otherMusicianProfileId;
  final String? conversationId;

  DmChatScreenArgs({
    required this.otherUserId,
    this.otherUsername,
    this.otherUserProfilePicture,
    this.currentUserId,
    this.otherMusicianProfileId,
    this.conversationId,
  });
}

class DmChatScreen extends StatelessWidget {
  DmChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<DmChatCubit>(),
      child: _DmChatView(),
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
        );
      }
    }
    final args = _args;
    if (args == null || args.otherUserId.trim().isEmpty) return;
    context.read<DmChatCubit>().openOrCreateConversation(
      otherUserId: args.otherUserId,
      currentUserId: args.currentUserId,
    );
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
    final args = _args;
    final resolvedUsername = args?.otherUsername?.trim() ?? '';
    final resolvedUserId = args?.otherUserId.trim() ?? '';
    final title = resolvedUsername.isNotEmpty
        ? resolvedUsername
        : (resolvedUserId.isNotEmpty ? resolvedUserId : 'Mesajlar');
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openRelatedProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                backgroundImage: _hasAvatar(args?.otherUserProfilePicture)
                    ? NetworkImage(args!.otherUserProfilePicture!.trim())
                    : null,
                child: _hasAvatar(args?.otherUserProfilePicture)
                    ? null
                    : Icon(Icons.person_outline, size: 18),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 2),
                    Text(
                      'Dogrudan mesaj',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.read<DmChatCubit>().refresh(),
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navBlueDeep, AppColors.navBlue],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: BlocConsumer<DmChatCubit, DmChatState>(
                  listener: (context, state) {
                    if (state.status == DmChatStatus.failure &&
                        state.error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.error!.message)),
                      );
                    }
                    final conversationId = state.conversationId?.trim() ??
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
                        padding: EdgeInsets.fromLTRB(12, 14, 12, 10),
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
                              if (showDateHeader)
                                _DateHeader(date: item.sentAt),
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
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.navBlueDeep,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          BlocBuilder<DmChatCubit, DmChatState>(
            builder: (context, state) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.gradientA, AppColors.gradientC],
                  ),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: state.sending ? null : _send,
                  icon: state.sending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.send_rounded, color: AppColors.white),
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
    if (args == null || !mounted) return;
    final resolver = serviceLocator<DmUserProfileResolver>();
    final resolved = await resolver.resolveByUserId(
      userId: args.otherUserId,
      usernameHint: args.otherUsername,
    );
    if (!mounted) return;
    if (resolved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bu kullanici icin acik profil bulunamadi')),
      );
      return;
    }
    if (resolved.length == 1) {
      _navigateToProfile(resolved.first);
      return;
    }
    final selected = await showModalBottomSheet<DmProfileTarget>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ProfileTargetSheet(items: resolved),
    );
    if (!mounted || selected == null) return;
    _navigateToProfile(selected);
  }

  bool _hasAvatar(String? value) {
    final url = value?.trim() ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    final aa = a.toLocal();
    final bb = b.toLocal();
    return aa.year == bb.year && aa.month == bb.month && aa.day == bb.day;
  }

  void _navigateToProfile(DmProfileTarget target) {
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
}

class _ChatEmptyState extends StatelessWidget {
  _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Icon(
                Icons.mark_chat_unread_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 32,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Henuz mesaj yok',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Sohbeti baslatmak icin ilk mesaji gonderebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
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
    final timeText = _formatTime(message.sentAt);
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: 296),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: isMine
            ? LinearGradient(colors: [AppColors.gradientA, AppColors.gradientC])
            : null,
        color: isMine
            ? null
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
          bottomLeft: Radius.circular(isMine ? 14 : 6),
          bottomRight: Radius.circular(isMine ? 6 : 14),
        ),
        border: Border.all(
          color: isMine ? Colors.transparent : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeText,
                style: TextStyle(
                  color: isMine
                      ? AppColors.white.withValues(alpha: 0.84)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
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
                      ? AppColors.white.withValues(alpha: 0.78)
                      : AppColors.white,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: isMine
            ? bubble
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer,
                    backgroundImage: _hasAvatar(senderAvatarUrl)
                        ? NetworkImage(senderAvatarUrl!.trim())
                        : null,
                    child: _hasAvatar(senderAvatarUrl)
                        ? null
                        : Icon(
                            Icons.person_outline,
                            size: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                  ),
                  SizedBox(width: 6),
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

  bool _hasAvatar(String? value) {
    final url = value?.trim() ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }
}

class _ProfileTargetSheet extends StatelessWidget {
  final List<DmProfileTarget> items;

  _ProfileTargetSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 1),
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
                  : Icon(
                      item.type == DmProfileTargetType.musician
                          ? Icons.person_outline
                          : Icons.storefront_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
            title: Text(item.displayName),
            subtitle: Text(
              item.type == DmProfileTargetType.musician ? 'Muzisyen' : 'Mekan',
            ),
            onTap: () => Navigator.of(context).pop(item),
          );
        },
      ),
    );
  }
}
