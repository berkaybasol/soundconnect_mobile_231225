import 'dart:convert';

import '../../../core/error/result.dart';
import 'analytics_observation.dart';

// Matches the existing server collector's byte limit, including signed proofs.
const analyticsMaxBodyBytes = 16384;

Map<String, Object> analyticsRequestBody(
  String clientId,
  Iterable<AnalyticsObservation> observations,
) => {
  'clientId': clientId,
  'observations': observations.map((value) => value.toJson()).toList(),
};

int analyticsRequestBytes(
  String clientId,
  Iterable<AnalyticsObservation> observations,
) => utf8
    .encode(jsonEncode(analyticsRequestBody(clientId, observations)))
    .length;

abstract class AnalyticsCollectionRepository {
  /// A null user ID requires the transport to remain anonymous until dispatch.
  Future<Result<List<String>>> collect({
    required String clientId,
    required List<AnalyticsObservation> observations,
    required String? expectedUserId,
  });
}
