// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously, invalid_use_of_protected_member

part of 'venue_management_panel_screen.dart';

extension _VenueApplicationsSheetStateActions on _VenueApplicationsSheetState {
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _artistVenueRepository.listVenueApplications(
        widget.venueId,
      );
      final response = result.data ?? const <ArtistVenueApplication>[];
      final filtered = response.where((item) {
        if (_showOutgoing) return item.requestByType == 'VENUE';
        return item.requestByType == 'ARTIST';
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final profileEntries = await Future.wait(
        filtered
            .map((item) => item.musicianProfileId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .map(_fetchMusicianProfile),
      );
      if (!mounted) return;
      setState(() {
        _items = filtered;
        _musicianProfiles = {
          for (final entry in profileEntries)
            if (entry != null) entry.key: entry.value,
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Basvurular getirilemedi: $e';
      });
    }
  }

  Future<MapEntry<String, _MusicianApplicationProfile>?> _fetchMusicianProfile(
    String profileId,
  ) async {
    try {
      final result = await _musicianProfileRepository.getPublicProfileByProfileId(
        profileId,
      );
      final data = result.data;
      if (data == null) return null;
      final stageName = data.stageName?.trim() ?? '';
      final username = data.username?.trim() ?? '';
      final displayName = stageName.isNotEmpty
          ? stageName
          : username.isNotEmpty
          ? username
          : 'Sanatci';
      final response = _MusicianApplicationProfile(
        displayName: displayName,
        profilePictureUrl: data.profilePicture,
      );
      return MapEntry(profileId, response);
    } catch (_) {
      return null;
    }
  }

  bool _isValidImageUrl(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.startsWith('http://') || normalized.startsWith('https://');
  }

  Future<void> _runAction({
    required String requestId,
    required String methodLabel,
    required Future<dynamic> Function() action,
  }) async {
    setState(() => _actionLoading = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(methodLabel)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Islem basarisiz: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACCEPTED':
        return const Color(0xFF4CD47A);
      case 'REJECTED':
        return AppColors.textMuted;
      default:
        return const Color(0xFFE7B65A);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ACCEPTED':
        return 'Onaylandi';
      case 'REJECTED':
        return 'Reddedildi';
      default:
        return 'Beklemede';
    }
  }

}
