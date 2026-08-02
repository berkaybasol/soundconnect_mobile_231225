import '../../domain/entities/password_reset_account.dart';

class PasswordResetAccountResponse {
  const PasswordResetAccountResponse({
    required this.username,
    this.profilePictureUrl,
  });

  final String username;
  final String? profilePictureUrl;

  factory PasswordResetAccountResponse.fromJson(Map<String, dynamic> json) {
    return PasswordResetAccountResponse(
      username: json['username']?.toString() ?? '',
      profilePictureUrl: _nonBlank(json['profilePictureUrl']),
    );
  }

  PasswordResetAccount toEntity() {
    return PasswordResetAccount(
      username: username,
      profilePictureUrl: profilePictureUrl,
    );
  }

  static String? _nonBlank(Object? value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
