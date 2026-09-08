part of 'venue_management_panel_screen.dart';

extension _VenueApplicationsSheetStateTiles on _VenueApplicationsSheetState {
  Widget _buildApplicationItem(ArtistVenueApplication item) {
    final isBandRequest = item.bandId.trim().isNotEmpty;
    final applicantName = isBandRequest
        ? (item.bandName.trim().isNotEmpty ? item.bandName.trim() : 'Band')
        : (item.musicianDisplayName ??
              (item.musicianStageName.trim().isNotEmpty
                  ? item.musicianStageName.trim()
                  : 'Sanatçı'));
    final canCancel = _showOutgoing && item.status == 'PENDING';
    final canAccept =
        !_showConnections && !_showOutgoing && item.status == 'PENDING';
    final canReject =
        !_showConnections && !_showOutgoing && item.status == 'PENDING';
    final canDisconnect = item.status == 'ACCEPTED';
    final canOpenMusicianProfile =
        !isBandRequest && item.musicianProfileId.isNotEmpty;
    final canOpenBandProfile = isBandRequest && item.bandId.isNotEmpty;
    final applicantImageUrl = isBandRequest
        ? item.bandProfilePictureUrl
        : item.musicianProfilePictureUrl;

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
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
                          if (!_session.isCurrent) return;
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
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          child: ClipOval(
                            child: _isValidImageUrl(applicantImageUrl)
                                ? AppCachedNetworkImage(
                                    imageUrl: applicantImageUrl,
                                    width: 40,
                                    height: 40,
                                    cacheWidth: 120,
                                    cacheHeight: 120,
                                    errorBuilder: (context) => Icon(
                                      isBandRequest
                                          ? Icons.groups_2_outlined
                                          : Icons.person_outline,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : Icon(
                                    isBandRequest
                                        ? Icons.groups_2_outlined
                                        : Icons.person_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            applicantName,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
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
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(item.status).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _statusColor(item.status)),
                ),
                child: Text(
                  _showConnections ? 'Bağlı' : _statusLabel(item.status),
                  style: TextStyle(
                    color: _statusColor(item.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!_showConnections) ...[
            SizedBox(height: 8),
            _showOutgoing
                ? Text(
                    'Gönderen mekan: ${item.venueName}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  )
                : RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: isBandRequest
                              ? 'Band notu: '
                              : 'Sanatçının notu: ',
                        ),
                        TextSpan(
                          text:
                              item.message != null &&
                                  item.message!.trim().isNotEmpty
                              ? item.message!.trim()
                              : (isBandRequest
                                    ? 'Band notu yok'
                                    : 'Sanatçının notu yok'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
          SizedBox(height: 12),
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
                          methodLabel: 'Başvuru onaylandı.',
                          action: () => _artistVenueRepository.acceptRequest(
                            item.id,
                            expectedSessionKey: _session.userId,
                          ),
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
                          methodLabel: 'Başvuru reddedildi.',
                          action: () => _artistVenueRepository.rejectRequest(
                            item.id,
                            expectedSessionKey: _session.userId,
                          ),
                        ),
                ),
              if (canCancel)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          requestId: item.id,
                          methodLabel: 'Başvuru iptal edildi.',
                          action: () => _artistVenueRepository.cancelRequest(
                            item.id,
                            expectedSessionKey: _session.userId,
                          ),
                        ),
                  child: Text('İptal et'),
                ),
              if (canDisconnect)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          requestId: item.id,
                          methodLabel: 'Bağlantı kaldırıldı.',
                          action: () => _artistVenueRepository.disconnect(
                            item.id,
                            expectedSessionKey: _session.userId,
                          ),
                        ),
                  child: Text('Bağlantıyı Kaldır'),
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: AppColors.brandGradient,
                ).createShader(bounds),
                child: Icon(icon, size: 18, color: AppColors.white),
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
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
