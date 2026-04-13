part of 'venue_management_panel_screen.dart';

extension _VenueApplicationsSheetStateTiles on _VenueApplicationsSheetState {
  Widget _buildApplicationItem(ArtistVenueApplication item) {
    final isBandRequest = item.requestByType == 'BAND';
    final musicianProfile = _musicianProfiles[item.musicianProfileId];
    final applicantName = isBandRequest
        ? (item.bandName.trim().isNotEmpty ? item.bandName.trim() : 'Band')
        : (musicianProfile?.displayName ??
              (item.musicianStageName.trim().isNotEmpty
                  ? item.musicianStageName.trim()
                  : 'Sanatci'));
    final canCancel = _showOutgoing && item.status == 'PENDING';
    final canAccept = !_showOutgoing && item.status == 'PENDING';
    final canReject = !_showOutgoing && item.status == 'PENDING';
    final canDisconnect = item.status == 'ACCEPTED';
    final canOpenMusicianProfile =
        !isBandRequest && item.musicianProfileId.isNotEmpty;
    final canOpenBandProfile = isBandRequest && item.bandId.isNotEmpty;
    final applicantImageUrl = isBandRequest
        ? item.bandProfilePictureUrl
        : musicianProfile?.profilePictureUrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: !(canOpenMusicianProfile || canOpenBandProfile)
                      ? null
                      : () {
                          if (canOpenBandProfile) {
                            Navigator.of(context).pushNamed(
                              AppRoutes.bandPublicProfile,
                              arguments: BandProfileScreenArgs(
                                bandId: item.bandId,
                                viewMode: BandProfileViewMode.public,
                              ),
                            );
                            return;
                          }
                          Navigator.of(context).pushNamed(
                            AppRoutes.musicianPublicProfile,
                            arguments: {'profileId': item.musicianProfileId},
                          );
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.navBlueSoft,
                          backgroundImage: _isValidImageUrl(applicantImageUrl)
                              ? NetworkImage(applicantImageUrl!)
                              : null,
                          child: !_isValidImageUrl(applicantImageUrl)
                              ? Icon(
                                  isBandRequest
                                      ? Icons.groups_2_outlined
                                      : Icons.person_outline,
                                  color: AppColors.textMuted,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            applicantName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(item.status).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _statusColor(item.status)),
                ),
                child: Text(
                  _statusLabel(item.status),
                  style: TextStyle(
                    color: _statusColor(item.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _showOutgoing
              ? Text(
                  'Hedef mekan: ${item.venueName}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                )
              : RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: isBandRequest
                            ? 'Band notu: '
                            : 'Sanatcinin notu: ',
                      ),
                      TextSpan(
                        text:
                            item.message != null &&
                                item.message!.trim().isNotEmpty
                            ? item.message!.trim()
                            : (isBandRequest
                                  ? 'Band notu yok'
                                  : 'Sanatcinin notu yok'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canAccept)
                _buildGradientActionButton(
                  icon: Icons.check_rounded,
                  label: 'Onayla',
                  onTap: _actionLoading
                      ? null
                      : () => _runAction(
                          requestId: item.id,
                          methodLabel: 'Basvuru onaylandi.',
                          action: () =>
                              _artistVenueRepository.acceptRequest(item.id),
                        ),
                ),
              if (canReject)
                _buildGradientActionButton(
                  icon: Icons.close_rounded,
                  label: 'Reddet',
                  onTap: _actionLoading
                      ? null
                      : () => _runAction(
                          requestId: item.id,
                          methodLabel: 'Basvuru reddedildi.',
                          action: () =>
                              _artistVenueRepository.rejectRequest(item.id),
                        ),
                ),
              if (canCancel)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          requestId: item.id,
                          methodLabel: 'Basvuru iptal edildi.',
                          action: () =>
                              _artistVenueRepository.cancelRequest(item.id),
                        ),
                  child: const Text('Iptal Et'),
                ),
              if (canDisconnect)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          requestId: item.id,
                          methodLabel: 'Baglanti kaldirildi.',
                          action: () =>
                              _artistVenueRepository.disconnect(item.id),
                        ),
                  child: const Text('Baglantiyi Kaldir'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradientActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: _GradientOutline(
        radius: 12,
        strokeWidth: 1,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.navBlueSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: AppColors.brandGradient,
                ).createShader(bounds),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
