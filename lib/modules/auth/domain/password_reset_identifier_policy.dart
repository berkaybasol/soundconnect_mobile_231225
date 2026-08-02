import 'username_policy.dart';

abstract final class PasswordResetIdentifierPolicy {
  static const int maximumEmailLength = 254;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool looksLikeEmail(String value) => value.trim().contains('@');

  static String normalize(String value) {
    if (isValidEmail(value)) {
      return value.trim().toLowerCase();
    }
    return UsernamePolicy.normalize(value);
  }

  static bool isValidEmail(String value) {
    final normalized = value.trim();
    return normalized.length <= maximumEmailLength &&
        _emailPattern.hasMatch(normalized);
  }

  static bool isValid(String value) {
    return isValidEmail(value) || UsernamePolicy.isValid(value);
  }
}
