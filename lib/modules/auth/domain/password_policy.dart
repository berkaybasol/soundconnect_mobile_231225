import 'dart:convert';

abstract final class PasswordPolicy {
  static const int registrationMinimumLength = 8;
  static const int bcryptMaximumUtf8Bytes = 72;

  static bool isBlank(String value) => value.trim().isEmpty;

  static int utf8ByteLength(String value) => utf8.encode(value).length;

  static bool exceedsBcryptLimit(String value) {
    return utf8ByteLength(value) > bcryptMaximumUtf8Bytes;
  }

  static bool isValidForLogin(String value) {
    return !isBlank(value) && !exceedsBcryptLimit(value);
  }

  static bool isValidForRegistration(String value) {
    return !isBlank(value) &&
        value.length >= registrationMinimumLength &&
        !exceedsBcryptLimit(value);
  }
}
