part of 'venue_profile_screen.dart';

class _MediaContent extends StatefulWidget {
  final ProfileMedia media;
  final String profileId;
  final String galleryOwnerId;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final bool ownerMode;

  const _MediaContent({
    required this.media,
    required this.profileId,
    required this.galleryOwnerId,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.ownerMode,
  });

  @override
  State<_MediaContent> createState() => _MediaContentState();
}

class _MediaContentState extends State<_MediaContent> {
  bool _photoUploading = false;
  double _photoUploadProgress = 0;
  String? _photoUploadStatus;

  Future<void> _addGalleryPhoto(BuildContext context) async {
    if (_photoUploading) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return;

    if (!mounted) return;
    setState(() {
      _photoUploading = true;
      _photoUploadProgress = 0;
      _photoUploadStatus = 'Fotograf hazirlaniyor';
    });

    try {
      final fileName = fileNameFromPath(picked.path, fallback: picked.name);
      final source = await createProfileUploadSource(filePath: picked.path);
      final uploaded = await uploadProfileMediaAsset(
        source: source,
        ownerType: 'VENUE_PROFILE',
        ownerId: widget.galleryOwnerId,
        mediaKind: 'IMAGE',
        mimeType: inferImageMimeType(fileName),
        originalFileName: fileName,
        attachmentIntent: const ProfileUploadAttachmentIntent.gallery(
          profileType: 'VENUE',
        ),
        onStageChanged: (stage) {
          if (!mounted) return;
          final label = switch (stage) {
            ProfileUploadStage.initializing => 'Yukleme hazirlaniyor',
            ProfileUploadStage.uploading => 'Fotograf yukleniyor',
            ProfileUploadStage.verifying => 'Fotograf dogrulaniyor',
            ProfileUploadStage.attaching => 'Fotograf galeriye ekleniyor',
            ProfileUploadStage.backgroundProcessing =>
              'Fotograf arka planda hazirlaniyor',
            ProfileUploadStage.completed => 'Fotograf hazir',
          };
          setState(() => _photoUploadStatus = label);
        },
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          final next = (sent / total).clamp(0.0, 1.0).toDouble();
          if ((next - _photoUploadProgress).abs() < 0.01 && next < 1) return;
          setState(() => _photoUploadProgress = next);
        },
      );
      final assetId = uploaded.uuid.trim();
      if (assetId.isEmpty) {
        throw Exception('Medya kimligi alinamadi');
      }

      if (!context.mounted) return;
      await context.read<ProfileMediaCubit>().loadMedia(
        profileType: 'VENUE',
        profileId: widget.galleryOwnerId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fotograf eklendi')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotograf eklenemedi: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _photoUploading = false;
          _photoUploadProgress = 0;
          _photoUploadStatus = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageItems = widget.media.videos
        .where((item) => (item.kind ?? '').toUpperCase() == 'IMAGE')
        .toList(growable: false);
    final featuredVideo = widget.media.featuredVideo;
    final videoItems = <MediaAsset>[
      if (featuredVideo != null) featuredVideo,
      ...widget.media.videos.where(
        (item) =>
            (item.kind ?? '').toUpperCase() == 'VIDEO' &&
            (featuredVideo == null || item.id != featuredVideo.id),
      ),
    ];

    return ProfileMediaContentSwitcher(
      firstTab: ProfilePhotoGalleryTab(
        items: imageItems,
        ownerMode: widget.ownerMode,
        uploading: _photoUploading,
        uploadProgress: _photoUploadProgress,
        uploadStatusLabel: _photoUploadStatus,
        onAddPhoto: widget.ownerMode ? () => _addGalleryPhoto(context) : null,
      ),
      videoItems: videoItems,
      videoProfileId: widget.galleryOwnerId,
      ownerMode: widget.ownerMode,
      profileType: 'VENUE',
      uploadOwnerType: 'VENUE_PROFILE',
    );
  }
}
