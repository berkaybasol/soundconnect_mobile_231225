abstract final class UsernamePolicy {
  static const int minimumLength = 3;
  static const int maximumLength = 30;

  static final RegExp _leadingBoundaryWhitespace = RegExp(
    r'^[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A'
    r'\u2028\u2029\u202F\u205F\u3000\uFEFF]+',
    unicode: true,
  );
  static final RegExp _trailingBoundaryWhitespace = RegExp(
    r'[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A'
    r'\u2028\u2029\u202F\u205F\u3000\uFEFF]+$',
    unicode: true,
  );

  static String normalize(String value) {
    final withoutBoundaryWhitespace = value
        .replaceFirst(_leadingBoundaryWhitespace, '')
        .replaceFirst(_trailingBoundaryWhitespace, '');
    return _simpleLowercase(withoutBoundaryWhitespace);
  }

  // This per-code-point lowercase is part of the shared Java/SQL contract.
  // Whole-string lowercase is intentionally avoided because contextual/full
  // mappings can differ for U+0130 and Greek final sigma.
  static String _simpleLowercase(String value) {
    final result = StringBuffer();
    for (final codePoint in value.runes) {
      if (codePoint == 0x0130) {
        result.write('i');
        continue;
      }
      result.write(String.fromCharCode(codePoint).toLowerCase());
    }
    return result.toString();
  }

  static bool isValid(String value) {
    final normalized = normalize(value);
    return normalized.length >= minimumLength &&
        normalized.length <= maximumLength;
  }
}
