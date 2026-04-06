part of 'venue_profile_screen.dart';

extension _VenueProfileViewStateConnectedArtistActions
    on _MusicianPublicProfileViewState {
  Future<void> _editConnectedArtists(String venueId) async {
    try {
      final acceptedIntro =
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const MusicianIntroScreen(),
            ),
          ) ??
          false;
      if (!acceptedIntro || !mounted) return;

      final accepted = await _fetchArtistConnectionsByStatus(
        venueId,
        status: 'ACCEPTED',
      );
      final pending = await _fetchArtistConnectionsByStatus(
        venueId,
        status: 'PENDING',
      );
      if (!mounted) return;

      final acceptedIds = accepted
          .map((item) => item.musicianProfileId)
          .toSet();
      final pendingIds = pending.map((item) => item.musicianProfileId).toSet();
      final selected = await showConnectedArtistRequestBottomSheet(
        context: context,
        acceptedIds: acceptedIds,
        pendingIds: pendingIds,
        searchMusicians: (query) async {
          final result = await _musicianSearchRepository.search(query);
          return result.data ?? const <MusicianSearchOption>[];
        },
      );

      if (selected == null) return;

      final requestResult = await _artistVenueRepository.createVenueRequest(
        musicianProfileId: selected.musicianProfileId,
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
}
