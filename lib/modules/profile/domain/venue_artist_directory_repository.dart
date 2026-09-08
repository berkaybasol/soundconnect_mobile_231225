import '../../../core/error/result.dart';

enum VenueArtistKind { musician, band }

class VenueArtistDirectoryItem {
  const VenueArtistDirectoryItem({
    required this.id,
    required this.kind,
    required this.displayName,
    this.profileImageUrl,
  });

  final String id;
  final VenueArtistKind kind;
  final String displayName;
  final String? profileImageUrl;
}

class VenueArtistDirectoryPage {
  const VenueArtistDirectoryPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  final List<VenueArtistDirectoryItem> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;
}

abstract class VenueArtistDirectoryRepository {
  /// Lists public profiles with an active connection to the requested venue.
  /// Type filtering, literal name search and pagination happen on the server.
  Future<Result<VenueArtistDirectoryPage>> list({
    required String venueId,
    required VenueArtistKind kind,
    String query = '',
    int page = 0,
    int size = 20,
    String? expectedSessionKey,
  });
}
