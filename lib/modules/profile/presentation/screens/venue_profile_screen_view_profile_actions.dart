part of 'venue_profile_screen.dart';

extension _VenueProfileViewStateProfileActions
    on _MusicianPublicProfileViewState {
  Future<void> _editProfilePhoto(VenueOwnerProfile profile) async {
    if (_photoUploading) return;
    final session = ProfileActionSession(roles: const ['VENUE', 'ROLE_VENUE']);
    bool current() =>
        mounted && session.isCurrent && session.userId == profile.ownerUserId;
    if (!current()) return;
    _updateState(() => _photoUploading = true);
    try {
      final uploaded = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: _imagePicker,
        ownerType: 'VENUE_PROFILE',
        ownerId: profile.venueProfileId,
        profilePhotoTargetId: profile.venueId,
        isCurrent: current,
      );
      if (!mounted || uploaded == null || !current()) return;
      final result = await context.read<VenueProfileCubit>().updateOwnerProfile(
        VenueProfileSaveRequest(profilePicture: uploaded.assetId),
        venueId: profile.venueId,
        expectedSessionKey: session.userId,
      );
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: result.isSuccess
              ? AppSnackBarTone.success
              : AppSnackBarTone.error,
          content: Text(
            result.isSuccess
                ? 'Profil fotoğrafı güncellendi'
                : result.error?.message ?? 'Profil fotoğrafı güncellenemedi.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: const Text('Fotoğraf yüklenemedi. Lütfen tekrar dene.'),
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
