part of 'band_profile_screen.dart';

extension _BandProfileMembershipActions on _BandProfileViewState {
  String? get _membershipSessionKey {
    final session = _membershipSessionManager?.session;
    if (session == null ||
        !session.isAuthenticated ||
        !session.isActive ||
        !session.hasAnyRole(const ['MUSICIAN', 'ROLE_MUSICIAN'])) {
      return null;
    }
    final userId = session.userId?.trim() ?? '';
    if (userId.isEmpty) return null;
    return '$userId:${session.token}:${session.accountStatus}';
  }

  bool _canLeaveBand(BandProfile profile) {
    if (_membershipSessionKey == null) return false;
    final userId = _membershipSessionManager?.session.userId?.trim();
    final ownMemberships = profile.members
        .where((member) => member.userId.trim() == userId)
        .toList(growable: false);
    // Founders must not lose ownership through a member-only action, even if a
    // malformed response includes another membership for the same user.
    return ownMemberships.length == 1 &&
        !ownMemberships.any((member) => member.isFounder) &&
        ownMemberships.any(
          (member) => member.status.trim().toUpperCase() == 'ACTIVE',
        );
  }

  Future<void> _leaveBand() async {
    final profile = _profile;
    if (!mounted ||
        _leavingBand ||
        profile == null ||
        !_canLeaveBand(profile)) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final session = _membershipSessionKey;
    final userId = _membershipSessionManager!.session.userId!.trim();
    final bandId = profile.id;
    final membershipVersion = profile.members
        .singleWhere((member) => member.userId.trim() == userId)
        .titleVersion;
    bool isCurrent() =>
        mounted && _membershipSessionKey == session && _bandId == bandId;

    _updateState(() => _leavingBand = true);
    try {
      var decisionDelivered = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => _LeaveBandDialog(
          bandName: profile.name,
          onDecision: (decision) {
            if (decisionDelivered ||
                !dialogContext.mounted ||
                ModalRoute.of(dialogContext)?.isCurrent == false) {
              return;
            }
            decisionDelivered = true;
            Navigator.of(dialogContext).pop(decision);
          },
        ),
      );
      if (!isCurrent() || confirmed != true || route?.isCurrent == false) {
        return;
      }
      final currentProfile = _profile;
      if (currentProfile == null || !_canLeaveBand(currentProfile)) return;

      _updateState(() => _leaveRequestPending = true);
      final result = await _bandRepository.leaveBand(
        bandId: bandId,
        expectedSessionKey: userId,
        expectedTitleVersion: membershipVersion,
      );
      // A completed leave must also clear an already mounted personal calendar
      // if the user backed out of this profile while the request was pending.
      if (result.isSuccess &&
          _membershipSessionKey == session &&
          serviceLocator.isRegistered<MusicianCalendarRepository>()) {
        serviceLocator<MusicianCalendarRepository>().invalidate();
      }
      if (!mounted || !isCurrent()) return;
      if (!result.isSuccess) {
        if (result.error?.code == '9221') {
          final refreshed = await _bandRepository.getPublicBandById(bandId);
          if (!isCurrent()) return;
          if (refreshed.isSuccess && refreshed.data?.id == bandId) {
            ++_profileLoadGeneration;
            _updateState(() => _profile = refreshed.data);
          }
        }
        if (route?.isCurrent != false) {
          _showLeaveBandFeedback(
            result.error?.code == '9221'
                ? 'Üyelik bilgileri değişti. Güncel üyeliğini kontrol edip tekrar dene.'
                : result.error?.message ??
                      'Gruptan ayrılamadın. Lütfen tekrar dene.',
            error: true,
          );
        }
        return;
      }

      // Fence pre-leave profile reads before updating the local membership.
      // The server also revokes this member's personal event publications.
      ++_profileLoadGeneration;
      _updateState(() {
        _loading = false;
        _profile = BandProfile(
          id: currentProfile.id,
          name: currentProfile.name,
          description: currentProfile.description,
          profilePictureUrl: currentProfile.profilePictureUrl,
          instagramUrl: currentProfile.instagramUrl,
          youtubeUrl: currentProfile.youtubeUrl,
          soundCloudUrl: currentProfile.soundCloudUrl,
          spotifyEmbedUrl: currentProfile.spotifyEmbedUrl,
          spotifyArtistId: currentProfile.spotifyArtistId,
          spotifyTrackIds: currentProfile.spotifyTrackIds,
          members: currentProfile.members
              .where((member) => member.userId.trim() != userId)
              .toList(growable: false),
        );
      });
      if (route?.isCurrent != false) {
        _showLeaveBandFeedback('Gruptan ayrıldın.');
        final navigator = Navigator.of(context);
        // MyBandsScreen consumes this result to remove the former membership.
        if (navigator.canPop()) navigator.pop(true);
      }
    } catch (_) {
      if (isCurrent() && route?.isCurrent != false) {
        _showLeaveBandFeedback(
          'Gruptan ayrılamadın. Lütfen tekrar dene.',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        _updateState(() {
          _leavingBand = false;
          _leaveRequestPending = false;
        });
      }
    }
  }

  void _showLeaveBandFeedback(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: error ? AppSnackBarTone.error : AppSnackBarTone.success,
        content: Text(message),
      ),
    );
  }
}

class _LeaveBandDialog extends StatelessWidget {
  const _LeaveBandDialog({required this.bandName, required this.onDecision});

  final String bandName;
  final ValueChanged<bool> onDecision;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      key: const Key('band-leave-confirmation'),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          padding: const EdgeInsets.all(.8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: AppColors.brandGradient),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(23.2),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const ExcludeSemantics(
                        child: BrandGradientIcon(
                          Icons.logout_rounded,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    namesRoute: true,
                    child: Text(
                      'Gruptan ayrılmak istiyor musun?',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 21,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$bandName üyeliğin sona erecek. Bu gruba ait etkinlikler kişisel profilinden kaldırılacak.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GradientOutlineButton(
                    key: const Key('confirm-band-leave'),
                    label: 'Gruptan ayrıl',
                    strokeWidth: .8,
                    horizontalPadding: 12,
                    onPressed: () => onDecision(true),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('cancel-band-leave'),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => onDecision(false),
                    child: const Text('Vazgeç'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
