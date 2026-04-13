import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/dm_user_profile_resolver.dart';
import '../../domain/entities/dm_message.dart';
import '../../domain/entities/dm_profile_target.dart';
import '../cubit/dm_chat_cubit.dart';
import '../cubit/dm_chat_state.dart';

class DmChatScreenArgs {
  final String otherUserId;
  final String? otherUsername;
  final String? otherUserProfilePicture;
  final String? currentUserId;
  final String? otherMusicianProfileId;

  const DmChatScreenArgs({
    required this.otherUserId,
    this.otherUsername,
    this.otherUserProfilePicture,
    this.currentUserId,
    this.otherMusicianProfileId,
  });
}

class DmChatScreen extends StatelessWidget {
  const DmChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<DmChatCubit>(),
      child: const _DmChatView(),
    );
  }
}

class _DmChatView extends StatefulWidget {
  const _DmChatView();

  @override
  State<_DmChatView> createState() => _DmChatViewState();
}

class _DmChatViewState extends State<_DmChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DmChatScreenArgs? _args;
  int _lastMessageCount = 0;

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
                backgroundColor: AppColors.navBlueSoft,
                backgroundImage: _hasAvatar(args?.otherUserProfilePicture)
                    ? NetworkImage(args!.otherUserProfilePicture!.trim())
                    : null,
                child: _hasAvatar(args?.otherUserProfilePicture)
                    ? null
                    : const Icon(Icons.person_outline, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    const Text(
                      'Dogrudan mesaj',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
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
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
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
                    if (state.messages.length != _lastMessageCount) {
                      _lastMessageCount = state.messages.length;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!_scrollController.hasClients) return;
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      });
                    }
                  },
                  builder: (context, state) {
                    if (state.status == DmChatStatus.loading &&
                        state.messages.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.messages.isEmpty) {
                      return const _ChatEmptyState();
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final item = state.messages[index];
                        final previous = index > 0
                            ? state.messages[index - 1]
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.navBlueDeep,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
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
          const SizedBox(width: 8),
          BlocBuilder<DmChatCubit, DmChatState>(
            builder: (context, state) {
              return DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.gradientA, AppColors.gradientC],
                  ),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: state.sending ? null : _send,
                  icon: state.sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: AppColors.white),
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
        const SnackBar(
          content: Text('Bu kullanici icin acik profil bulunamadi'),
        ),
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
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.inputFill,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.mark_chat_unread_outlined,
                color: AppColors.textMuted,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Henuz mesaj yok',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sohbeti baslatmak icin ilk mesaji gonderebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final text = _formatDate(date);
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1, color: AppColors.border)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          const Expanded(child: Divider(height: 1, color: AppColors.border)),
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
    if (day == today.subtract(const Duration(days: 1))) return 'Dun';
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

  const _DmMessageBubble({
    required this.message,
    required this.isMine,
    required this.senderAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = _formatTime(message.sentAt);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 296),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: isMine
            ? const LinearGradient(
                colors: [AppColors.gradientA, AppColors.gradientC],
              )
            : null,
        color: isMine ? null : AppColors.inputFill,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(isMine ? 14 : 6),
          bottomRight: Radius.circular(isMine ? 6 : 14),
        ),
        border: Border.all(
          color: isMine ? Colors.transparent : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeText,
                style: TextStyle(
                  color: isMine
                      ? AppColors.white.withValues(alpha: 0.84)
                      : AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 6),
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
      margin: const EdgeInsets.only(bottom: 8),
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
                    backgroundColor: AppColors.navBlueSoft,
                    backgroundImage: _hasAvatar(senderAvatarUrl)
                        ? NetworkImage(senderAvatarUrl!.trim())
                        : null,
                    child: _hasAvatar(senderAvatarUrl)
                        ? null
                        : const Icon(
                            Icons.person_outline,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                  ),
                  const SizedBox(width: 6),
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

  const _ProfileTargetSheet({required this.items});

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
              backgroundColor: AppColors.navBlueSoft,
              backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
              child: hasImage
                  ? null
                  : Icon(
                      item.type == DmProfileTargetType.musician
                          ? Icons.person_outline
                          : Icons.storefront_outlined,
                      color: AppColors.textMuted,
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
