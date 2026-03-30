import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../engagement/data/models/comment_item_model.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/domain/entities/comment_item.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_state.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/venue_profile_repository.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/venue_public_profile.dart';
import 'musician_public_profile_screen.dart' as musician_public;
import 'venue_public_profile_screen.dart' as venue_public;

class WeeklyCalendarEvent {
  final String id;
  final String title;
  final String artistName;
  final String? artistProfileId;
  final String venueName;
  final String? venueId;
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
    required this.artistProfileId,
    required this.venueName,
    required this.venueId,
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

bool _isNetworkLikePath(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return false;
  final uri = Uri.tryParse(raw);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
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
  final CommentThreadCubit _commentCubit = CommentThreadCubit(
    serviceLocator<EngagementRepository>(),
  );
  MusicianProfile? _artistProfile;
  VenuePublicProfile? _venueProfile;
  String? _shareUrl;
  bool _isSharing = false;
  final Map<String, List<CommentItem>> _repliesByCommentId =
      <String, List<CommentItem>>{};
  final Set<String> _loadedReplyParents = <String>{};

  @override
  void initState() {
    super.initState();
    _loadProfileContext();
  }

  @override
  void dispose() {
    _commentCubit.close();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileContext() async {
    final futures = <Future<void>>[];
    final artistProfileId = widget.event.artistProfileId?.trim();
    final venueId = widget.event.venueId?.trim();

    futures.add(_loadShareUrl());

    if (artistProfileId != null && artistProfileId.isNotEmpty) {
      futures.add(_loadArtistProfile(artistProfileId));
    }
    if (venueId != null && venueId.isNotEmpty) {
      futures.add(_loadVenueProfile(venueId));
    }

    if (futures.isEmpty) return;
    await Future.wait(futures);
    await _loadComments();
  }

  Future<void> _loadShareUrl() async {
    final apiClient = serviceLocator<ApiClient>();
    try {
      final payload = await apiClient.get<Map<String, dynamic>>(
        '/api/v1/events/${widget.event.id}',
        decoder: (json) =>
            (json as Map<Object?, Object?>?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      );
      if (!mounted) return;
      final rawShareUrl = payload['shareUrl'];
      final shareUrl = rawShareUrl is String ? rawShareUrl.trim() : '';
      if (shareUrl.isEmpty) return;
      setState(() {
        _shareUrl = shareUrl;
      });
    } on ApiException {
      // Share butonu fallback metinle yine calisabilir.
    } catch (_) {
      // Share butonu fallback metinle yine calisabilir.
    }
  }

  Future<void> _loadArtistProfile(String profileId) async {
    final repository = serviceLocator<MusicianProfileRepository>();
    final result = await repository.getPublicProfileByProfileId(profileId);
    if (!mounted || !result.isSuccess || result.data == null) return;
    setState(() {
      _artistProfile = result.data;
    });
  }

  Future<void> _loadVenueProfile(String venueId) async {
    final repository = serviceLocator<VenueProfileRepository>();
    final result = await repository.getPublicVenueProfile(venueId: venueId);
    if (!mounted || !result.isSuccess || result.data == null) return;
    setState(() {
      _venueProfile = result.data;
    });
  }

  Future<void> _loadComments() async {
    await _commentCubit.load(
      targetType: 'EVENT',
      targetId: widget.event.id,
    );
  }

  Future<void> _syncReplies(List<CommentItem> comments) async {
    final futures = <Future<void>>[];
    for (final comment in comments) {
      if (comment.replyCount <= 0) continue;
      if (_loadedReplyParents.contains(comment.id)) continue;
      _loadedReplyParents.add(comment.id);
      futures.add(_loadReplies(comment.id));
    }
    if (futures.isEmpty) return;
    await Future.wait(futures);
  }

  Future<void> _loadReplies(String commentId) async {
    final apiClient = serviceLocator<ApiClient>();
    try {
      final items = await apiClient.get<List<CommentItem>>(
        '/api/v1/comments/replies/$commentId',
        decoder: (json) => _decodeCommentItems(json),
      );
      if (!mounted) return;
      setState(() {
        _repliesByCommentId[commentId] = items;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _repliesByCommentId[commentId] = const <CommentItem>[];
      });
    }
  }

  List<CommentItem> _decodeCommentItems(Object? json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(CommentItemModel.fromJson)
          .toList();
    }
    final map = json as Map<String, dynamic>? ?? <String, dynamic>{};
    final content = map['content'];
    if (content is List) {
      return content
          .whereType<Map<String, dynamic>>()
          .map(CommentItemModel.fromJson)
          .toList();
    }
    return const <CommentItem>[];
  }

  String _timeLabel(DateTime? createdAt) {
    if (createdAt == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'simdi';
    if (diff.inHours < 1) return '${diff.inMinutes} dk once';
    if (diff.inDays < 1) return '${diff.inHours} sa once';
    return '${diff.inDays} gun once';
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    await _commentCubit.create(
      targetType: 'EVENT',
      targetId: widget.event.id,
      text: text,
    );
    _commentController.clear();
  }

  void _openArtistProfile() {
    final profileId = widget.event.artistProfileId?.trim();
    if (profileId == null || profileId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(
          arguments: musician_public.PublicProfileArgs(profileId: profileId),
        ),
        builder: (_) => const musician_public.MusicianPublicProfileScreen(),
      ),
    );
  }

  void _openVenueProfile() {
    final venueId = widget.event.venueId?.trim();
    if (venueId == null || venueId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(
          arguments: venue_public.VenuePublicProfileArgs(venueId: venueId),
        ),
        builder: (_) => const venue_public.VenuePublicProfileScreen(),
      ),
    );
  }

  Future<void> _shareEvent() async {
    if (_isSharing) return;
    final shareUrl = _shareUrl?.trim();
    final shareText = shareUrl != null && shareUrl.isNotEmpty
        ? '${widget.event.title}\n$shareUrl'
        : '${widget.event.title}\n'
            '${widget.event.eventDate} ${widget.event.startTime} - ${widget.event.endTime}\n'
            '@${widget.event.venueName}';
    setState(() {
      _isSharing = true;
    });
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: widget.event.title,
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paylasim acilamadi.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _showReplySheet(int index) async {
    final comments = _commentCubit.state.comments;
    if (index < 0 || index >= comments.length) return;
    final targetComment = comments[index];
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
    await _commentCubit.create(
      targetType: 'EVENT',
      targetId: widget.event.id,
      text: replyText,
      parentCommentId: targetComment.id,
    );
    _loadedReplyParents.remove(targetComment.id);
    await _syncReplies(_commentCubit.state.comments);
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
                        ? _isNetworkLikePath(imagePath)
                              ? Image.network(
                                  imagePath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      _imageFallback(),
                                )
                              : Image.asset(
                                  imagePath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      _imageFallback(),
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
                            text: '@${event.artistName}',
                            imageUrl: _artistProfile?.profilePicture,
                            onTap: event.artistProfileId?.trim().isNotEmpty == true
                                ? _openArtistProfile
                                : null,
                          ),
                          _MetaChip(
                            icon: Icons.storefront_outlined,
                            text: '@${event.venueName}',
                            imageUrl: _venueProfile?.profilePictureUrl,
                            onTap: event.venueId?.trim().isNotEmpty == true
                                ? _openVenueProfile
                                : null,
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
                      child: _ActionButton(
                        icon: Icons.ios_share_outlined,
                        label: 'Paylas',
                        onPressed: _shareEvent,
                        isLoading: _isSharing,
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
                  SliverToBoxAdapter(
                    child: BlocConsumer<CommentThreadCubit, CommentThreadState>(
                      bloc: _commentCubit,
                      listener: (context, state) {
                        _syncReplies(state.comments);
                      },
                      builder: (context, state) {
                        if (state.loading && state.comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
                            child: LinearProgressIndicator(),
                          );
                        }
                        if (state.comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
                            child: Text(
                              'Henuz yorum yok. Ilk yorumu sen yaz.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          );
                        }
                        return Column(
                          children: List.generate(state.comments.length, (index) {
                            final comment = state.comments[index];
                            final replies =
                                _repliesByCommentId[comment.id] ??
                                const <CommentItem>[];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CommentTile(
                                comment: comment,
                                timeLabel: _timeLabel(comment.createdAt),
                                replies: replies,
                                replyTimeLabelBuilder: _timeLabel,
                                onReplyTap: () => _showReplySheet(index),
                              ),
                            );
                          }),
                        );
                      },
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
                  BlocBuilder<CommentThreadCubit, CommentThreadState>(
                    bloc: _commentCubit,
                    builder: (context, state) => Material(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: state.submitting ? null : _addComment,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: state.submitting
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textPrimary,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: AppColors.textPrimary,
                                ),
                        ),
                      ),
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
                ? _isNetworkLikePath(event.imageAssetPath)
                      ? Image.network(
                          event.imageAssetPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imageFallback(),
                        )
                      : Image.asset(
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
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
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
  final String? imageUrl;
  final VoidCallback? onTap;

  const _MetaChip({
    required this.icon,
    required this.text,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImage = imageUrl?.trim();
    final hasImage = _isNetworkLikePath(resolvedImage);
    final isInteractive = onTap != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isInteractive
                  ? AppColors.white.withValues(alpha: 0.14)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MetaLeadingVisual(
                icon: icon,
                imageUrl: hasImage ? resolvedImage : null,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: isInteractive
                    ? ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: AppColors.brandGradient,
                          ).createShader(bounds);
                        },
                        child: Text(
                          text,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Text(
                        text,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              if (isInteractive) ...[
                const SizedBox(width: 6),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.brandGradient,
                    ).createShader(bounds);
                  },
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLeadingVisual extends StatelessWidget {
  final IconData icon;
  final String? imageUrl;

  const _MetaLeadingVisual({
    required this.icon,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradientMetaIcon(icon: icon),
        ),
      );
    }
    return _gradientMetaIcon(icon: icon);
  }

  Widget _gradientMetaIcon({required IconData icon}) {
    return _GradientIcon(icon: icon, size: 16);
  }
}

class _GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _GradientIcon({
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ).createShader(bounds);
      },
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.inputFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: isLoading
          ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textPrimary,
              ),
            )
          : Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentItem comment;
  final String timeLabel;
  final List<CommentItem> replies;
  final String Function(DateTime? createdAt) replyTimeLabelBuilder;
  final VoidCallback onReplyTap;

  const _CommentTile({
    required this.comment,
    required this.timeLabel,
    required this.replies,
    required this.replyTimeLabelBuilder,
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
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: (comment.user.avatarUrl?.trim().isNotEmpty ?? false)
                  ? Image.network(
                      comment.user.avatarUrl!.trim(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(
                        comment.user.username.isNotEmpty
                            ? comment.user.username[0]
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Text(
                      comment.user.username.isNotEmpty
                          ? comment.user.username[0]
                          : '?',
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
                          '@${comment.user.username}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        timeLabel,
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
                        onTap: onReplyTap,
                        child: Text(
                          comment.replyCount > 0
                              ? 'Yanitla (${comment.replyCount})'
                              : 'Yanitla',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (replies.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...replies.map(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      gradient: const LinearGradient(
                                        colors: AppColors.brandGradient,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    alignment: Alignment.center,
                                    child:
                                        (reply.user.avatarUrl?.trim().isNotEmpty ??
                                                false)
                                            ? Image.network(
                                                reply.user.avatarUrl!.trim(),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Text(
                                                  reply.user.username.isNotEmpty
                                                      ? reply.user.username[0]
                                                      : '?',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                reply.user.username.isNotEmpty
                                                    ? reply.user.username[0]
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                ),
                                              ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '@${reply.user.username}',
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              replyTimeLabelBuilder(
                                                reply.createdAt,
                                              ),
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
                                ],
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
