import '../../domain/entities/username_availability.dart';

class UsernameAvailabilityResponse {
  const UsernameAvailabilityResponse({
    required this.username,
    required this.available,
  });

  final String username;
  final bool available;

  factory UsernameAvailabilityResponse.fromJson(Map<String, dynamic> json) {
    return UsernameAvailabilityResponse(
      username: json['username']?.toString() ?? '',
      available: json['available'] == true,
    );
  }

  UsernameAvailability toEntity() {
    return UsernameAvailability(username: username, available: available);
  }
}
