import '../../../core/error/app_error.dart';
import '../../event/domain/venue_suggestion_repository.dart';
import '../../studio/data/models/studio_json.dart';
import '../domain/admin_panel_access.dart';
import 'admin_list_repository.dart';

class AdminVenueSuggestion {
  const AdminVenueSuggestion({
    required this.venueName,
    required this.cityName,
    required this.districtName,
    required this.liveMusic,
  });

  final String venueName;
  final String cityName;
  final String districtName;
  final VenueSuggestionLiveMusic liveMusic;

  factory AdminVenueSuggestion.fromJson(Object? value) {
    final json = studioJsonObject(value, 'venue suggestion');
    final answer = studioJsonString(json, 'liveMusic');
    return AdminVenueSuggestion(
      venueName: studioJsonString(json, 'venueName'),
      cityName: studioJsonString(json, 'cityName'),
      districtName: studioJsonString(json, 'districtName'),
      liveMusic: VenueSuggestionLiveMusic.values.firstWhere(
        (choice) => choice.name.toUpperCase() == answer,
        orElse: () => throw const FormatException('Invalid live music answer'),
      ),
    );
  }
}

class AdminVenueSuggestionRepository
    extends AdminListRepository<AdminVenueSuggestion> {
  AdminVenueSuggestionRepository(super.api, super.sessions)
    : super(
        path: '/api/v1/admin/venue-suggestions',
        canRead: canReadVenueSuggestions,
        accessError: const AppError(
          code: 'venue_suggestion_access_changed',
          message:
              'Mekân önerilerini görüntüleme yetkin veya oturumun değişti.',
        ),
        listError: const AppError(
          code: 'venue_suggestion_list_failed',
          message: 'Mekân önerileri yüklenemedi. Lütfen tekrar dene.',
        ),
        decodeRow: AdminVenueSuggestion.fromJson,
      );
}
