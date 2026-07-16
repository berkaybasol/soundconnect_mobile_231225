part of 'venue_profile_screen.dart';

extension _VenueProfileViewStateConnectedArtistActions
    on _MusicianPublicProfileViewState {
  Future<void> _editConnectedArtists(String venueId) async {
    try {
      final acceptedIntro =
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => MusicianIntroScreen(),
            ),
          ) ??
          false;
      if (!acceptedIntro || !mounted) return;

      final applicationsResult = await _artistVenueRepository
          .listVenueApplications(venueId);
      if (!applicationsResult.isSuccess || applicationsResult.data == null) {
        throw applicationsResult.error?.message ?? 'Baglanti listesi alinamadi';
      }
      if (!mounted) return;

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
          final result = await _profileSearchRepository.searchProfiles(query);
          return (result.data ?? const <ProfileSearchResult>[])
              .where(
                (item) =>
                    item.type == ProfileSearchResultType.musician ||
                    item.type == ProfileSearchResultType.band,
              )
              .toList(growable: false);
        },
      );

      if (selected == null) return;

      final requestResult = selected.type == ConnectedArtistType.band
          ? await _artistVenueRepository.createVenueBandRequest(
              bandId: selected.targetId,
              venueId: venueId,
              message: selected.message,
            )
          : await _artistVenueRepository.createVenueRequest(
              musicianProfileId: selected.targetId,
              venueId: venueId,
              message: selected.message,
            );
      if (!requestResult.isSuccess) {
        throw requestResult.error?.message ?? 'Request failed';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sanatci baglanti istegi gonderildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sanatci baglantisi guncellenemedi: $e')),
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
