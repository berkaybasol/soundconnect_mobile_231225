part of 'studio_profile_screen.dart';

/// Public Studio composition is intentionally separate from the owner screen.
/// Shared leaf widgets keep the visual language consistent without coupling the
/// public layout to future owner-management changes.
class _StudioPublicDashboardContent extends StatelessWidget {
  final StudioProfile profile;
  final String location;
  final int? followersCount;
  final int? followingCount;
  final VoidCallback onBack;
  final VoidCallback onMessage;
  final VoidCallback onReservation;

  const _StudioPublicDashboardContent({
    required this.profile,
    required this.location,
    required this.followersCount,
    required this.followingCount,
    required this.onBack,
    required this.onMessage,
    required this.onReservation,
  });

  @override
  Widget build(BuildContext context) {
    final description = profile.description?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StudioTopChrome(onBack: onBack, onMenu: null),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudioHeroAvatar(
                imageUrl: profile.profilePictureUrl,
                uploading: false,
                onEditPhoto: null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF8C95A3),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFA3ABB8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFC1C8D2),
                            fontSize: 12,
                            height: 1.42,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _StudioProfileMetrics(
            followersCount: followersCount,
            followingCount: followingCount,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StudioActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Mesaj Gönder',
                  outlined: true,
                  onTap: onMessage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StudioActionButton(
                  icon: Icons.calendar_month_outlined,
                  label: 'Rezervasyon İste',
                  outlined: false,
                  onTap: onReservation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StudioPublicTabs(profileId: profile.id, phone: profile.phone),
        ],
      ),
    );
  }
}

class _StudioPublicTabs extends StatelessWidget {
  final String profileId;
  final String? phone;

  const _StudioPublicTabs({required this.profileId, required this.phone});

  @override
  Widget build(BuildContext context) {
    return _StudioTabsFrame(
      profileId: profileId,
      canReserve: true,
      ownerMode: false,
      phone: phone,
    );
  }
}
