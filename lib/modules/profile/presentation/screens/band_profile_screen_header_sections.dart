part of 'band_profile_screen.dart';

class _BandHeader extends StatelessWidget {
  final BandProfile profile;
  final String? uploadedPhotoUrl;
  final bool uploading;
  final VoidCallback? onEditPhoto;

  _BandHeader({
    required this.profile,
    required this.uploadedPhotoUrl,
    required this.uploading,
    required this.onEditPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = uploadedPhotoUrl?.trim().isNotEmpty == true
        ? uploadedPhotoUrl!.trim()
        : profile.profilePictureUrl?.trim();

    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient[2].withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? AppCachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 104,
                        height: 104,
                        fit: BoxFit.cover,
                        cacheWidth: 312,
                        cacheHeight: 312,
                        errorBuilder: (context) => Icon(
                          Icons.groups_2_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 42,
                        ),
                      )
                    : Icon(
                        Icons.groups_2_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 42,
                      ),
              ),
            ),
            if (onEditPhoto != null)
              Positioned(
                right: -4,
                bottom: -4,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: uploading ? null : onEditPhoto,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: AppColors.brandGradient),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.navBlueDeep,
                        width: 2,
                      ),
                    ),
                    child: uploading
                        ? Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : Icon(
                            Icons.edit_outlined,
                            size: 16,
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

class _BandMembersRow extends StatelessWidget {
  final List<BandMemberSummary> items;
  final String? Function(BandMemberSummary member)? avatarUrlOf;
  final Future<void> Function(BandMemberSummary member)? onOpenMember;

  _BandMembersRow({required this.items, this.avatarUrlOf, this.onOpenMember});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Bandde henüz üye görünmüyor.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ProfileMiniCarousel(
      itemCount: items.length,
      hasSubtitle: items.any((item) => item.displayTitle != null),
      itemBuilder: (context, index) {
        final item = items[index];
        return ProfileMiniCard(
          title: item.username,
          subtitle: item.displayTitle,
          imageUrl: _resolveBandMemberAvatarUrl(
            avatarUrlOf?.call(item) ?? item.profilePictureUrl,
          ),
          fallbackIcon: Icons.person_outline_rounded,
          onTap: onOpenMember == null ? null : () => onOpenMember!(item),
          titleBadge: item.isFounder
              ? Tooltip(
                  message: 'Kurucu',
                  excludeFromSemantics: true,
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: AppColors.brandGradient,
                    ).createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: const Icon(
                      Icons.verified_outlined,
                      size: 12,
                      semanticLabel: 'Kurucu',
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

String? _resolveBandMemberAvatarUrl(String? raw) {
  final String value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  if (value.startsWith('//')) return 'https:$value';

  final Uri? parsed = Uri.tryParse(value);
  if (parsed == null) return null;

  final bool isHttp =
      parsed.hasScheme &&
      (parsed.scheme.toLowerCase() == 'http' ||
          parsed.scheme.toLowerCase() == 'https') &&
      parsed.host.isNotEmpty;
  if (isHttp) return value;

  final Uri? baseUri = Uri.tryParse(NetworkConfig.baseUrl);
  if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
    return null;
  }

  final Uri resolved = value.startsWith('/')
      ? baseUri.resolve(value)
      : baseUri.resolve('/$value');
  final String scheme = resolved.scheme.toLowerCase();
  if ((scheme != 'http' && scheme != 'https') || resolved.host.isEmpty) {
    return null;
  }
  return resolved.toString();
}

class _BandVenuesRow extends StatelessWidget {
  final List<VenueConnection> items;

  _BandVenuesRow({required this.items});

  @override
  Widget build(BuildContext context) => VenueNameCarousel(
    items: items,
    emptyMessage: 'Henüz bir mekan eklenmedi.',
  );
}
