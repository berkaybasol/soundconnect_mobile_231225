import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/venue_artist_directory_repository.dart';

class VenueArtistDirectoryRepositoryImpl
    implements VenueArtistDirectoryRepository {
  VenueArtistDirectoryRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<VenueArtistDirectoryPage>> list({
    required String venueId,
    required VenueArtistKind kind,
    String query = '',
    int page = 0,
    int size = 20,
    String? expectedSessionKey,
  }) async {
    final normalizedId = venueId.trim();
    final normalizedQuery = query.trim();
    if (normalizedId.isEmpty ||
        normalizedQuery.length > 100 ||
        page < 0 ||
        page > 10000 ||
        size < 1 ||
        size > 50) {
      return const Result.failure(
        AppError(
          code: 'venue_artist_directory_invalid_query',
          message: 'Arama bilgileri geçersiz. Yeniden dene.',
        ),
      );
    }
    try {
      final response = await _apiClient.request<VenueArtistDirectoryPage>(
        ApiHttpMethod.get,
        '/api/v1/public/venue-profiles/${Uri.encodeComponent(normalizedId)}/active-artists',
        query: {
          'type': kind == VenueArtistKind.musician ? 'MUSICIAN' : 'BAND',
          if (normalizedQuery.isNotEmpty) 'q': normalizedQuery,
          'page': page,
          'size': size,
        },
        requestContext: expectedSessionKey == null
            ? null
            : ApiRequestContext(expectedSessionKey: expectedSessionKey),
        decoder: _decodePage,
      );
      if (response.page != page ||
          response.size != size ||
          response.items.any((item) => item.kind != kind)) {
        throw const FormatException('Artist directory scope mismatch');
      }
      return Result.success(response);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'venue_artist_directory_malformed_response',
          message: 'Liste alınamadı. Yeniden dene.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'venue_artist_directory_failed',
          message: 'Liste şu anda yüklenemiyor. Yeniden dene.',
        ),
      );
    }
  }

  static VenueArtistDirectoryPage _decodePage(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid artist directory page');
    }
    int integer(String field) {
      final value = json[field];
      if (value is! int || value < 0) {
        throw FormatException('Invalid $field');
      }
      return value;
    }

    final page = integer('page');
    final size = integer('size');
    final total = integer('totalElements');
    final pages = integer('totalPages');
    final last = json['last'];
    final content = json['content'];
    if (size < 1 ||
        size > 50 ||
        page > 10000 ||
        content is! List ||
        content.length > size ||
        content.length != (total - page * size).clamp(0, size) ||
        last is! bool ||
        pages != (total / size).ceil() ||
        last != (page + 1 >= pages) ||
        (json['number'] != null && json['number'] != page) ||
        (json['first'] != null && json['first'] != (page == 0))) {
      throw const FormatException('Invalid artist directory metadata');
    }
    final identities = <(VenueArtistKind, String)>{};
    final items = <VenueArtistDirectoryItem>[];
    for (final raw in content) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid artist directory item');
      }
      final id = raw['id'];
      final name = raw['name'];
      final image = raw['profilePictureUrl'];
      final kind = switch (raw['type']) {
        'MUSICIAN' => VenueArtistKind.musician,
        'BAND' => VenueArtistKind.band,
        _ => throw const FormatException('Invalid artist type'),
      };
      if (id is! String ||
          id.trim().isEmpty ||
          name is! String ||
          name.trim().isEmpty ||
          (image != null && image is! String) ||
          !identities.add((kind, id.trim()))) {
        throw const FormatException('Invalid artist directory identity');
      }
      final normalizedImage = (image as String?)?.trim();
      items.add(
        VenueArtistDirectoryItem(
          id: id.trim(),
          kind: kind,
          displayName: name.trim(),
          profileImageUrl: normalizedImage?.isEmpty == true
              ? null
              : normalizedImage,
        ),
      );
    }
    return VenueArtistDirectoryPage(
      items: List.unmodifiable(items),
      page: page,
      size: size,
      totalElements: total,
      totalPages: pages,
      last: last,
    );
  }
}
