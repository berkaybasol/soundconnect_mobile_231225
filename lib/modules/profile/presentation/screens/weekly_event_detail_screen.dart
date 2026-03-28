import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class WeeklyCalendarEvent {
  final String id;
  final String title;
  final String artistName;
  final String venueName;
  final String city;
  final String district;
  final String neighborhood;
  final String eventDate;
  final String startTime;
  final String endTime;
  final String? imageAssetPath;
  final String description;

  const WeeklyCalendarEvent({
    required this.id,
    required this.title,
    required this.artistName,
    required this.venueName,
    required this.city,
    required this.district,
    required this.neighborhood,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    this.imageAssetPath,
    required this.description,
  });
}

class WeeklyEventDetailScreen extends StatefulWidget {
  final WeeklyCalendarEvent event;

  const WeeklyEventDetailScreen({
    super.key,
    required this.event,
  });

  @override
  State<WeeklyEventDetailScreen> createState() => _WeeklyEventDetailScreenState();
}

class _WeeklyEventDetailScreenState extends State<WeeklyEventDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final List<_EventComment> _comments = <_EventComment>[
    _EventComment(
      author: 'Mert Y.',
      text: 'Mekan ve lineup cok iyi duruyor, biletler ne zaman aciliyor?',
      timeLabel: '12 dk once',
      likeCount: 4,
      isLiked: false,
      replies: [
        _EventReply(
          author: 'Mekan',
          text: 'Yarin 18:00 gibi biletleri aciyoruz.',
          timeLabel: '5 dk once',
        ),
      ],
    ),
    _EventComment(
      author: 'Ece K.',
      text: 'Gecen haftaki set harikaydi, bu etkinlige de gelecegim.',
      timeLabel: '35 dk once',
      likeCount: 2,
      isLiked: true,
      replies: const [],
    ),
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _comments.insert(
        0,
        _EventComment(
          author: 'Sen',
          text: text,
          timeLabel: 'simdi',
          likeCount: 0,
          isLiked: false,
          replies: const [],
        ),
      );
    });
    _commentController.clear();
  }

  void _toggleLike(int index) {
    final current = _comments[index];
    setState(() {
      _comments[index] = current.copyWith(
        isLiked: !current.isLiked,
        likeCount: current.isLiked
            ? (current.likeCount - 1).clamp(0, 1 << 20)
            : current.likeCount + 1,
      );
    });
  }

  Future<void> _showReplySheet(int index) async {
    final replyController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            14,
            14,
            MediaQuery.of(sheetContext).viewInsets.bottom + 14,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: replyController,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => Navigator.of(sheetContext).pop(),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Yanita yaz...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Ekle'),
              ),
            ],
          ),
        );
      },
    );

    final replyText = replyController.text.trim();
    replyController.dispose();
    if (replyText.isEmpty) return;
    final current = _comments[index];
    setState(() {
      final nextReplies = <_EventReply>[
        ...current.replies,
        _EventReply(author: 'Sen', text: replyText, timeLabel: 'simdi'),
      ];
      _comments[index] = current.copyWith(replies: nextReplies);
    });
  }

  void _openPosterFullScreen() {
    final imagePath = widget.event.imageAssetPath;
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Poster',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      pageBuilder: (context, _, __) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: imagePath != null
                        ? Image.asset(
                            imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _imageFallback(),
                          )
                        : _imageFallback(),
                  ),
                ),
              ),
              Positioned(
                top: 44,
                right: 12,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Scaffold(
      backgroundColor: AppColors.navBlueDeep,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _HeroHeader(
                      event: event,
                      onImageTap: _openPosterFullScreen,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaChip(
                            icon: Icons.music_note_outlined,
                            text: event.artistName,
                          ),
                          _MetaChip(
                            icon: Icons.storefront_outlined,
                            text: event.venueName,
                          ),
                          _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            text: event.eventDate,
                          ),
                          _MetaChip(
                            icon: Icons.schedule_outlined,
                            text: '${event.startTime} - ${event.endTime}',
                          ),
                          _MetaChip(
                            icon: Icons.place_outlined,
                            text:
                                '${event.city} / ${event.district} / ${event.neighborhood}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.map_outlined,
                              label: 'Haritada Ac',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Backendde lokasyon linki geldigi an haritaya yonlendirecegiz.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.ios_share_outlined,
                              label: 'Paylas',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Backendde paylasim deeplinki ile native share acilacak.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Text(
                        event.description,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                      child: _SectionTitle(text: 'Sorular&Yorumlar'),
                    ),
                  ),
                  if (_comments.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
                        child: Text(
                          'Henuz yorum yok. Ilk yorumu sen yaz.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final comment = _comments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CommentTile(
                              comment: comment,
                              onLikeTap: () => _toggleLike(index),
                              onReplyTap: () => _showReplySheet(index),
                            ),
                          );
                        },
                        childCount: _comments.length,
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 14),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.navBlue,
                border: Border(
                  top: BorderSide(
                    color: AppColors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _addComment(),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Yorum yaz...',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        prefixIcon: const Icon(
                          Icons.mode_comment_outlined,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: AppColors.brandGradient,
                      ),
                    ),
                    child: IconButton(
                      onPressed: _addComment,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final WeeklyCalendarEvent event;
  final VoidCallback onImageTap;

  const _HeroHeader({
    required this.event,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InkWell(
            onTap: onImageTap,
            child: event.imageAssetPath != null
                ? Image.asset(
                    event.imageAssetPath!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imageFallback(),
                  )
                : _imageFallback(),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0xCC0B1321)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '${event.eventDate} - ${event.startTime} - ${event.endTime}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Material(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _imageFallback() {
  return Container(
    color: AppColors.inputFill,
    alignment: Alignment.center,
    child: const Icon(
      Icons.image_outlined,
      color: AppColors.textMuted,
      size: 42,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.coralAlt),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.inputFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final _EventComment comment;
  final VoidCallback onLikeTap;
  final VoidCallback onReplyTap;

  const _CommentTile({
    required this.comment,
    required this.onLikeTap,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(colors: AppColors.brandGradient),
              ),
              alignment: Alignment.center,
              child: Text(
                comment.author.isNotEmpty ? comment.author[0] : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.author,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        comment.timeLabel,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    comment.text,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      InkWell(
                        onTap: onLikeTap,
                        child: Row(
                          children: [
                            Icon(
                              comment.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 15,
                              color: comment.isLiked
                                  ? AppColors.coralAlt
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Like (${comment.likeCount})',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      InkWell(
                        onTap: onReplyTap,
                        child: const Text(
                          'Reply',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (comment.replies.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...comment.replies.map(
                      (reply) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.navBlueSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      reply.author,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    reply.timeLabel,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reply.text,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}

class _EventComment {
  final String author;
  final String text;
  final String timeLabel;
  final int likeCount;
  final bool isLiked;
  final List<_EventReply> replies;

  const _EventComment({
    required this.author,
    required this.text,
    required this.timeLabel,
    required this.likeCount,
    required this.isLiked,
    required this.replies,
  });

  _EventComment copyWith({
    String? author,
    String? text,
    String? timeLabel,
    int? likeCount,
    bool? isLiked,
    List<_EventReply>? replies,
  }) {
    return _EventComment(
      author: author ?? this.author,
      text: text ?? this.text,
      timeLabel: timeLabel ?? this.timeLabel,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      replies: replies ?? this.replies,
    );
  }
}

class _EventReply {
  final String author;
  final String text;
  final String timeLabel;

  const _EventReply({
    required this.author,
    required this.text,
    required this.timeLabel,
  });
}
