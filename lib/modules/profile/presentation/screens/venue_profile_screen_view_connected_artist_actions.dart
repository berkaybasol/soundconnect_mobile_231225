part of 'venue_profile_screen.dart';

extension _VenueProfileViewStateConnectedArtistActions
    on _MusicianPublicProfileViewState {
  Future<void> _editConnectedArtists(String venueId) async {
    final session = ProfileActionSession(roles: const ['VENUE', 'ROLE_VENUE']);
    if (!mounted || !session.isCurrent) return;
    try {
      final acceptedIntro =
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => MusicianIntroScreen(),
            ),
          ) ??
          false;
      if (!acceptedIntro || !mounted || !session.isCurrent) return;

      final applicationsResult = await _artistVenueRepository
          .listVenueApplications(venueId);
      if (!mounted || !session.isCurrent) return;
      if (!applicationsResult.isSuccess || applicationsResult.data == null) {
        throw applicationsResult.error?.message ?? 'Bağlantı listesi alınamadı';
      }
      if (!mounted || !session.isCurrent) return;

      final acceptedIds = applicationsResult.data!
          .where((item) => item.status.trim().toUpperCase() == 'ACCEPTED')
          .map(_connectionKeyForApplication)
          .where((id) => id.isNotEmpty)
          .toSet();
      final pendingIds = applicationsResult.data!
          .where((item) => item.status.trim().toUpperCase() == 'PENDING')
          .map(_connectionKeyForApplication)
          .where((id) => id.isNotEmpty)
          .toSet();
      final selected = await showConnectedArtistRequestBottomSheet(
        context: context,
        acceptedIds: acceptedIds,
        pendingIds: pendingIds,
        searchArtists: (query) async {
          if (!mounted || !session.isCurrent) {
            return const <ProfileSearchResult>[];
          }
          final result = await _profileSearchRepository.searchProfiles(query);
          if (!mounted || !session.isCurrent) {
            return const <ProfileSearchResult>[];
          }
          if (!result.isSuccess || result.data == null) {
            throw result.error?.message ?? 'Sanatçı araması yapılamadı.';
          }
          return (result.data ?? const <ProfileSearchResult>[])
              .where(
                (item) =>
                    item.type == ProfileSearchResultType.musician ||
                    item.type == ProfileSearchResultType.band,
              )
              .toList(growable: false);
        },
      );

      if (selected == null || !mounted || !session.isCurrent) return;

      final requestResult = selected.type == ConnectedArtistType.band
          ? await _artistVenueRepository.createVenueBandRequest(
              bandId: selected.targetId,
              venueId: venueId,
              message: selected.message,
              expectedSessionKey: session.userId,
            )
          : await _artistVenueRepository.createVenueRequest(
              musicianProfileId: selected.targetId,
              venueId: venueId,
              message: selected.message,
              expectedSessionKey: session.userId,
            );
      if (!mounted || !session.isCurrent) return;
      if (!requestResult.isSuccess) {
        throw requestResult.error?.message ?? 'Request failed';
      }

      if (!mounted || !session.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: const Text('Sanatçı bağlantı isteği gönderildi.'),
        ),
      );
    } catch (e) {
      if (!mounted || !session.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text('Sanatçı bağlantısı güncellenemedi: $e'),
        ),
      );
    }
  }

  String _connectionKeyForApplication(ArtistVenueApplication application) {
    final bandId = application.bandId.trim();
    if (bandId.isNotEmpty) return 'BAND:$bandId';
    final musicianId = application.musicianProfileId.trim();
    if (musicianId.isNotEmpty) return 'MUSICIAN:$musicianId';
    return '';
  }
}
