part of 'musician_profile_screen.dart';

class _ProfileHeader extends StatelessWidget {
  final MusicianProfile profile;
  final VoidCallback? onEditPhoto;
  final bool uploading;
  final String? uploadedPhotoUrl;

  const _ProfileHeader({
    required this.profile,
    this.onEditPhoto,
    this.uploading = false,
    this.uploadedPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final candidate = (uploadedPhotoUrl?.trim().isNotEmpty == true)
        ? uploadedPhotoUrl!.trim()
        : (profile.profilePicture?.trim() ?? '');
    final hasRemotePhoto = candidate.startsWith('http');

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 0),
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.inputFill,
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient[2].withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: hasRemotePhoto
                    ? Image.network(candidate, fit: BoxFit.cover)
                    : const Icon(
                        Icons.person_outline,
                        color: AppColors.textMuted,
                        size: 40,
                      ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: uploading ? null : onEditPhoto,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.brandGradient,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.navBlueDeep, width: 2),
                  ),
                  child: uploading
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(
                          Icons.edit,
                          size: 14,
                          color: AppColors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
