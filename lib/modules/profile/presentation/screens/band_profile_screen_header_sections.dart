part of 'band_profile_screen.dart';

class _BandHeader extends StatelessWidget {
  final BandProfile profile;
  final String? uploadedPhotoUrl;
  final bool uploading;
  final VoidCallback onEditPhoto;

  const _BandHeader({
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
      padding: const EdgeInsets.only(top: 8),
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
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.groups_2_outlined,
                          color: AppColors.textMuted,
                          size: 42,
                        ),
                      )
                    : const Icon(
                        Icons.groups_2_outlined,
                        color: AppColors.textMuted,
                        size: 42,
                      ),
              ),
            ),
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
                    gradient: const LinearGradient(
                      colors: AppColors.brandGradient,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.navBlueDeep, width: 2),
                  ),
                  child: uploading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Colors.white,
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

  const _BandMembersRow({
    required this.items,
    this.avatarUrlOf,
    this.onOpenMember,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Bandde henüz üye görünmüyor.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final item = items[index];
          final String? avatarUrl = _resolveBandMemberAvatarUrl(
            avatarUrlOf?.call(item) ?? item.profilePictureUrl,
          );

          return Container(
            width: 168,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.navBlueSoft,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl != null
                      ? null
                      : const Icon(
                          Icons.person_outline,
                          color: AppColors.textMuted,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onOpenMember == null
                        ? null
                        : () => onOpenMember!(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.localizedRoleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: items.length,
      ),
    );
  }
}

String? _resolveBandMemberAvatarUrl(String? raw) {
  final String value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  if (value.startsWith('//')) return 'https:$value';

  final Uri? parsed = Uri.tryParse(value);
  if (parsed == null) return null;

  final bool isHttp = parsed.hasScheme &&
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

  const _BandVenuesRow({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Text(
          'Henüz bir mekan eklenmedi.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final venue = items[index];
          final imageUrl = _resolveBandVenueImageUrl(venue.profileImageUrl);
          final hasImage = imageUrl != null;
          final canOpen = venue.venueId.trim().isNotEmpty;

          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: canOpen
                ? () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.venuePublicProfile,
                      arguments: VenuePublicProfileArgs(venueId: venue.venueId),
                    );
                  }
                : null,
            child: Container(
              width: 170,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.inputFill, AppColors.navBlueSoft],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.navBlueSoft,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.white.withValues(alpha: 0.08),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: hasImage
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : const Icon(
                              Icons.storefront_outlined,
                              color: AppColors.coralAlt,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GradientText(
                      text: venue.venueName,
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppColors.brandGradient,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}

String? _resolveBandVenueImageUrl(String? raw) {
  final String value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  if (value.startsWith('//')) return 'https:$value';

  final Uri? parsed = Uri.tryParse(value);
  if (parsed == null) return null;

  final bool isHttp = parsed.hasScheme &&
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
