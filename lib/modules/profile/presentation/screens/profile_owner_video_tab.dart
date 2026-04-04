import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/profile_media_management_repository.dart';
import '../cubit/profile_media_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'profile_count_row.dart';
import 'profile_screen_support.dart';
import 'video_reel_screen.dart';

class ProfileOwnerVideoTab extends StatefulWidget {
  final List<MediaAsset> items;
  final String profileId;
  final bool ownerMode;
  final String profileType;
  final String uploadOwnerType;

  const ProfileOwnerVideoTab({
    super.key,
    required this.items,
    required this.profileId,
    required this.ownerMode,
    required this.profileType,
    required this.uploadOwnerType,
  });

  @override
  State<ProfileOwnerVideoTab> createState() => _ProfileOwnerVideoTabState();
}

class _ProfileOwnerVideoTabState extends State<ProfileOwnerVideoTab> {
  final Set<String> _processingVideoIds = <String>{};
  Timer? _processingPollTimer;
  bool _pollBusy = false;
  int _pollAttempt = 0;
  static const int _maxPollAttempt = 45;
  bool _videoUploading = false;

  @override
  void initState() {
    super.initState();
    _syncProcessingState();
  }

  @override
  void didUpdateWidget(covariant ProfileOwnerVideoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncProcessingState();
  }

  @override
  void dispose() {
    _processingPollTimer?.cancel();
    super.dispose();
  }

  void _syncProcessingState() {
    if (_processingVideoIds.isEmpty) return;
    final readyIds = widget.items
        .where((item) {
          final hasPlayable =
              (item.playbackUrl?.trim().isNotEmpty ?? false) ||
              (item.sourceUrl?.trim().isNotEmpty ?? false);
          return item.id.isNotEmpty && hasPlayable;
        })
        .map((item) => item.id)
        .toSet();
    _processingVideoIds.removeWhere(readyIds.contains);
    if (_processingVideoIds.isEmpty) {
      _processingPollTimer?.cancel();
      _processingPollTimer = null;
    } else {
      _startPolling();
    }
  }

  void _addProcessingVideo(String assetId) {
    if (assetId.trim().isEmpty) return;
    setState(() {
      _processingVideoIds.add(assetId.trim());
    });
    _pollAttempt = 0;
    _startPolling();
  }

  void _startPolling() {
    if (_processingPollTimer != null) return;
    _processingPollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!mounted) return;
      if (_processingVideoIds.isEmpty) {
        _processingPollTimer?.cancel();
        _processingPollTimer = null;
        return;
      }
      _pollAttempt++;
      if (_pollAttempt > _maxPollAttempt) {
        _processingPollTimer?.cancel();
        _processingPollTimer = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Video işleme beklenenden uzun sürdü. Biraz sonra tekrar kontrol et.',
              ),
            ),
          );
        }
        return;
      }
      if (_pollBusy) return;
      _pollBusy = true;
      try {
        await context.read<ProfileMediaCubit>().loadMedia(
          profileType: widget.profileType,
          profileId: widget.profileId,
        );
      } catch (_) {
      } finally {
        _pollBusy = false;
      }
    });
  }

  String _mimeFromVideoFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    return 'video/mp4';
  }

  String _fileNameFromPath(String path, {String fallback = 'video.mp4'}) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final name = parts.isNotEmpty ? parts.last.trim() : '';
    return name.isEmpty ? fallback : name;
  }

  Future<void> _pickAndUploadVideo() async {
    if (_videoUploading) return;
    final messenger = ScaffoldMessenger.of(context);
    final mediaCubit = context.read<ProfileMediaCubit>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: false,
      allowMultiple: false,
      allowedExtensions: const ['mp4', 'mov', 'mkv'],
    );
    final file = result?.files.isNotEmpty == true ? result!.files.first : null;
    if (file == null) return;

    final pickedPath = file.path;
    final pickedBytes = file.bytes;
    final pickedName = file.name.trim().isNotEmpty
        ? file.name.trim()
        : (file.path != null ? _fileNameFromPath(file.path!) : 'video.mp4');
    if ((pickedPath == null && pickedBytes == null) || pickedName.isEmpty) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Önce bir video dosyası seç.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _videoUploading = true;
    });

    var step = 'dosya okuma';
    try {
      final bytes = pickedBytes ?? await File(pickedPath!).readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Dosya okunamadı');
      }
      final mimeType = _mimeFromVideoFileName(pickedName);

      step = 'init-upload';
      final completed = await uploadProfileMediaAsset(
        bytes: bytes,
        ownerType: widget.uploadOwnerType,
        ownerId: widget.profileId,
        mediaKind: 'VIDEO',
        mimeType: mimeType,
        originalFileName: pickedName,
      );

      step = 'profile-media';
      final profileMediaRepository =
          serviceLocator<ProfileMediaManagementRepository>();
      final assetId = completed.uuid.trim();
      if (assetId.isEmpty) {
        throw Exception('Yukleme sonrasi assetId alinmadi');
      }
      final addResult = await profileMediaRepository.addGalleryMedia(
        profileType: widget.profileType,
        profileId: widget.profileId,
        mediaAssetId: assetId,
      );
      if (!addResult.isSuccess) {
        throw Exception(
          addResult.error?.message ?? 'Video profile galerisine eklenemedi',
        );
      }

      step = 'refresh';
      if (assetId.isNotEmpty && mounted) {
        _addProcessingVideo(assetId);
      }

      await mediaCubit.loadMedia(
        profileType: widget.profileType,
        profileId: widget.profileId,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Video yüklendi, işleniyor. Kısa süre sonra görünecek.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Yükleme başarısız ($step): $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _videoUploading = false;
        });
      }
    }
  }

  Widget _buildProcessingCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _processingVideoIds.length == 1
                ? 'Video işleniyor'
                : '${_processingVideoIds.length} video işleniyor',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'İşleme tamamlanınca video otomatik olarak görünecek.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ownerMode) {
      final hasAny = widget.items.isNotEmpty;
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, hasAny ? 8 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _videoUploading ? null : _pickAndUploadVideo,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0x1AFFFFFF),
                      Color(0x1A8A5CFF),
                      Color(0x1AFF7A3D),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.inputFill,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasAny ? 'Video ekle' : 'Henüz video eklemediniz',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'SoundConnect üzerinden video yüklemek için dokun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    if (_videoUploading) ...[
                      const SizedBox(height: 10),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_processingVideoIds.isNotEmpty) _buildProcessingCard(),
          if (widget.items.isEmpty && _processingVideoIds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Henüz video eklemediniz.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else if (widget.items.isNotEmpty)
            GridView.builder(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: widget.items.length,
              itemBuilder: (context, index) =>
                  _buildVideoCard(context, widget.items[index], index),
            ),
        ],
      );
    }

    if (widget.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Kullanıcı henüz video eklemedi.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, index) =>
          _buildVideoCard(context, widget.items[index], index),
    );
  }

  Widget _buildVideoCard(BuildContext context, MediaAsset item, int index) {
    final thumbnailRaw = item.thumbnailUrl ?? item.playbackUrl;
    final thumbnail = isValidNetworkImageUrl(thumbnailRaw)
        ? thumbnailRaw!.trim()
        : null;
    final fallbackLikeCount = 210 + (index * 9);
    final fallbackCommentCount = 44 + (index * 4);
    final targetType = 'MEDIA';
    final targetId = item.id;
    final statsState = context.watch<InteractionStatsCubit>().state;
    final statsKey = '$targetType:$targetId';
    if (targetId.isNotEmpty && !statsState.items.containsKey(statsKey)) {
      context.read<InteractionStatsCubit>().load(
        targetType: targetType,
        targetId: targetId,
      );
    }
    final stats = statsState.items[statsKey];
    final likeCount = stats?.likeCount ?? fallbackLikeCount;
    final commentCount = stats?.commentCount ?? fallbackCommentCount;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        image: thumbnail != null
            ? DecorationImage(image: NetworkImage(thumbnail), fit: BoxFit.cover)
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: context.read<InteractionStatsCubit>()),
                  BlocProvider(
                    create: (_) => serviceLocator<CommentThreadCubit>(),
                  ),
                ],
                child: VideoReelScreen(
                  title: item.title ?? 'Video',
                  playbackUrl: (item.playbackUrl ?? item.sourceUrl ?? '').trim(),
                  sourceUrl: item.sourceUrl,
                  thumbnailUrl: thumbnail,
                  framePreset: null,
                  targetType: targetType,
                  targetId: item.id,
                  initialLikeCount: likeCount,
                  initialCommentCount: commentCount,
                ),
              ),
            ),
          );
        },
        child: Stack(
          children: [
            Positioned(
              left: 10,
              bottom: 10,
              child: ProfileCountRow(
                likeCount: likeCount,
                commentCount: commentCount,
                light: true,
              ),
            ),
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: AppColors.white,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
