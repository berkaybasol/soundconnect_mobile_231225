// ignore_for_file: use_build_context_synchronously

part of 'venue_profile_screen.dart';

class _MediaContent extends StatelessWidget {
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

  Future<void> _addGalleryPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 94,
      maxWidth: 2400,
    );
    if (picked == null) return;

    try {
      final bytes = await File(picked.path).readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Secilen fotograf okunamadi');
      }
      final fileName = fileNameFromPath(picked.path, fallback: picked.name);
      final uploaded = await uploadProfileMediaAsset(
        bytes: bytes,
        ownerType: 'VENUE_PROFILE',
        ownerId: galleryOwnerId,
        mediaKind: 'IMAGE',
        mimeType: inferImageMimeType(fileName),
        originalFileName: fileName,
      );
      final assetId = uploaded.uuid.trim();
      if (assetId.isEmpty) {
        throw Exception('Medya kimligi alinamadi');
      }

      final profileMediaRepository =
          serviceLocator<ProfileMediaManagementRepository>();
      final attachResult = await profileMediaRepository.addGalleryMedia(
        profileType: 'VENUE',
        profileId: galleryOwnerId,
        mediaAssetId: assetId,
      );
      if (!attachResult.isSuccess) {
        throw Exception(
          attachResult.error?.message ?? 'Fotograf galeriye eklenemedi',
        );
      }

      await context.read<ProfileMediaCubit>().loadMedia(
        profileType: 'VENUE',
        profileId: galleryOwnerId,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageItems = media.videos
        .where((item) => (item.kind ?? '').toUpperCase() == 'IMAGE')
        .toList(growable: false);
    final featuredVideo = media.featuredVideo;
    final videoItems = <MediaAsset>[
      if (featuredVideo != null) featuredVideo,
      ...media.videos.where(
        (item) =>
            (item.kind ?? '').toUpperCase() == 'VIDEO' &&
            (featuredVideo == null || item.id != featuredVideo.id),
      ),
    ];

    return ProfileMediaContentSwitcher(
      firstTab: ProfilePhotoGalleryTab(
        items: imageItems,
        ownerMode: ownerMode,
        onAddPhoto: ownerMode ? () => _addGalleryPhoto(context) : null,
      ),
      videoItems: videoItems,
      videoProfileId: galleryOwnerId,
      ownerMode: ownerMode,
      profileType: 'VENUE',
      uploadOwnerType: 'VENUE_PROFILE',
    );
  }
}
