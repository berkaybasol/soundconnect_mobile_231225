import '../../../core/error/result.dart';

enum VenueSuggestionLiveMusic { yes, no, unknown }

abstract class VenueSuggestionRepository {
  Future<Result<void>> submit({
    required String requestId,
    required String venueName,
    required String cityId,
    required String districtId,
    required VenueSuggestionLiveMusic liveMusic,
  });
}
