part of 'profile_owner_video_tab.dart';

extension _ProfileOwnerVideoTabStateMethods on _ProfileOwnerVideoTabState {
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
    _updateState(() {
      _processingVideoIds.add(assetId.trim());
    });
    _pollAttempt = 0;
    _startPolling();
  }

  void _startPolling() {
    if (_processingPollTimer != null) return;
    _processingPollTimer = Timer.periodic(Duration(seconds: 8), (_) async {
      if (!mounted) return;
      if (_processingVideoIds.isEmpty) {
        _processingPollTimer?.cancel();
        _processingPollTimer = null;
        return;
      }
      _pollAttempt++;
      if (_pollAttempt > _ProfileOwnerVideoTabState._maxPollAttempt) {
        _processingPollTimer?.cancel();
        _processingPollTimer = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Video isleme beklenenden uzun surdu. Biraz sonra tekrar kontrol et.',
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
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      withData: false,
      withReadStream: true,
      allowMultiple: false,
      allowedExtensions: ['mp4', 'mov', 'mkv'],
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
        SnackBar(content: Text('Once bir video dosyasi sec.')),
      );
      return;
    }

    if (!mounted) return;
    _updateState(() {
      _videoUploading = true;
      _videoUploadProgress = 0;
      _videoUploadStatus = 'Video hazirlaniyor';
    });

    var step = 'dosya hazirlama';
    try {
      final source = await createProfileUploadSource(
        filePath: file.readStream == null ? pickedPath : null,
        bytes: pickedBytes,
        readStream: file.readStream,
        sizeBytes: file.size,
      );
      final mimeType = _mimeFromVideoFileName(pickedName);

      step = 'init-upload';
      final completed = await uploadProfileMediaAsset(
        source: source,
        ownerType: widget.uploadOwnerType,
        ownerId: widget.profileId,
        mediaKind: 'VIDEO',
        mimeType: mimeType,
        originalFileName: pickedName,
        attachmentIntent: ProfileUploadAttachmentIntent.gallery(
          profileType: widget.profileType,
        ),
        onStageChanged: (stage) {
          final label = switch (stage) {
            ProfileUploadStage.initializing => 'Yukleme hazirlaniyor',
            ProfileUploadStage.uploading => 'Video yukleniyor',
            ProfileUploadStage.verifying => 'Video dogrulaniyor',
            ProfileUploadStage.attaching => 'Video profile ekleniyor',
            ProfileUploadStage.backgroundProcessing =>
              'Video arka planda hazirlaniyor',
            ProfileUploadStage.completed => 'Video isleme alindi',
          };
          _updateState(() => _videoUploadStatus = label);
        },
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          final next = (sent / total).clamp(0.0, 1.0).toDouble();
          if ((next - _videoUploadProgress).abs() < 0.01 && next < 1) return;
          _updateState(() => _videoUploadProgress = next);
        },
      );

      final assetId = completed.uuid.trim();
      if (assetId.isEmpty) {
        throw Exception('Yukleme sonrasi assetId alinmadi');
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
        SnackBar(
          content: Text(
            'Video yuklendi, isleniyor. Kisa sure sonra gorunecek.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Yukleme basarisiz ($step): $e')),
      );
    } finally {
      if (mounted) {
        _updateState(() {
          _videoUploading = false;
          _videoUploadProgress = 0;
          _videoUploadStatus = null;
        });
      }
    }
  }

  Widget _buildProcessingCard() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _processingVideoIds.length == 1
                ? 'Video isleniyor'
                : '${_processingVideoIds.length} video isleniyor',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Isleme tamamlaninca video otomatik olarak gorunecek.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 10),
          LinearProgressIndicator(minHeight: 6),
        ],
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, MediaAsset item, int index) {
    final thumbnailRaw = item.thumbnailUrl;
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider.value(
                    value: context.read<InteractionStatsCubit>(),
                  ),
                  BlocProvider(
                    create: (_) => serviceLocator<CommentThreadCubit>(),
                  ),
                ],
                child: VideoReelScreen(
                  title: item.title ?? 'Video',
                  playbackUrl: (item.playbackUrl ?? item.sourceUrl ?? '')
                      .trim(),
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
            if (thumbnail != null)
              Positioned.fill(
                child: AppCachedNetworkImage(
                  imageUrl: thumbnail,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Positioned(
              left: 10,
              bottom: 10,
              child: ProfileCountRow(
                likeCount: likeCount,
                commentCount: commentCount,
                light: true,
              ),
            ),
            Center(
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
