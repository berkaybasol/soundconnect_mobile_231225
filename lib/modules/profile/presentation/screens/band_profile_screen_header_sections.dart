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

    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final item = items[index];
          final String? avatarUrl = _resolveBandMemberAvatarUrl(
            avatarUrlOf?.call(item) ?? item.profilePictureUrl,
          );

          return Container(
            width: 168,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainer,
                  child: ClipOval(
                    child: avatarUrl != null
                        ? AppCachedNetworkImage(
                            imageUrl: avatarUrl,
                            width: 36,
                            height: 36,
                            cacheWidth: 108,
                            cacheHeight: 108,
                            errorBuilder: (context) => Icon(
                              Icons.person_outline,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Icon(
                            Icons.person_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onOpenMember == null
                        ? null
                        : () => onOpenMember!(item),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            item.localizedRoleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
        separatorBuilder: (_, __) => SizedBox(width: 10),
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
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Text(
          'Henüz bir mekan eklenmedi.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20),
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
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surfaceContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
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
                          ? AppCachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              cacheWidth: 108,
                              cacheHeight: 108,
                              errorBuilder: (context) => Icon(
                                Icons.storefront_outlined,
                                color: AppColors.coralAlt,
                                size: 20,
                              ),
                            )
                          : Icon(
                              Icons.storefront_outlined,
                              color: AppColors.coralAlt,
                              size: 20,
                            ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: GradientText(
                      text: venue.venueName,
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppColors.brandGradient,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => SizedBox(width: 12),
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
