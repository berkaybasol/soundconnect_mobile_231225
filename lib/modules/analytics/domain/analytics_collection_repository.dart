import '../../../core/error/result.dart';
import 'analytics_observation.dart';

abstract class AnalyticsCollectionRepository {
  /// A null user ID requires the transport to remain anonymous until dispatch.
  Future<Result<List<String>>> collect({
    required String clientId,
    required List<AnalyticsObservation> observations,
    required String? expectedUserId,
  });
}
