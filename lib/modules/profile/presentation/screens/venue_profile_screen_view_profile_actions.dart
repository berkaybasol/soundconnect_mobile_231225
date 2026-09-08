part of 'venue_profile_screen.dart';

extension _VenueProfileViewStateProfileActions
    on _MusicianPublicProfileViewState {
  Future<void> _editProfilePhoto(VenueOwnerProfile profile) async {
    _updateState(() => _photoUploading = true);
    try {
      final uploaded = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: _imagePicker,
        ownerType: 'VENUE_PROFILE',
        ownerId: profile.venueProfileId,
        profilePhotoTargetId: profile.venueId,
      );
      if (uploaded == null) return;
      if (!mounted) return;
      await context.read<VenueProfileCubit>().updateOwnerProfile(
        VenueProfileSaveRequest(profilePicture: uploaded.assetId),
        venueId: profile.venueId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: const Text('Profil fotoğrafı güncellendi'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text('Fotoğraf yüklenemedi: $e'),
        ),
      );
    } finally {
      if (mounted) {
        _updateState(() => _photoUploading = false);
      }
    }
  }

  void _onEditProfilePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: AppSnackBarTone.info,
        content: const Text(
          'Aşağıdaki alanlardan profilini düzenleyebilirsin.',
        ),
      ),
    );
  }
}
