import '../../../core/error/result.dart';

enum VenueSuggestionLiveMusic {
  yes('Evet'),
  no('Hayır'),
  unknown('Bilmiyorum');

  const VenueSuggestionLiveMusic(this.label);
  final String label;
}

abstract class VenueSuggestionRepository {
  Future<Result<void>> submit({
    required String requestId,
    required String venueName,
    required String cityId,
    required String districtId,
    required VenueSuggestionLiveMusic liveMusic,
  });
}
