Uri? profileHttpUri(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty || RegExp(r'\s').hasMatch(value)) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.scheme.toLowerCase() != 'http' &&
          uri.scheme.toLowerCase() != 'https') ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

String? normalizeProfileHttpUrl(String? raw, {bool assumeHttps = false}) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  final candidate = assumeHttps && !value.contains('://')
      ? 'https://$value'
      : value;
  return profileHttpUri(candidate)?.toString();
}

String? canonicalProfilePhoneDigits(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty || !RegExp(r'^[+0-9() .-]+$').hasMatch(value)) return null;
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10 && digits.startsWith('5')) {
    digits = '0$digits';
  } else if (digits.length == 12 && digits.startsWith('90')) {
    digits = '0${digits.substring(2)}';
  }
  return digits.length == 11 && digits.startsWith('0') ? digits : null;
}

Uri? profilePhoneUri(String? raw) {
  final digits = canonicalProfilePhoneDigits(raw);
  return digits == null ? null : Uri(scheme: 'tel', path: digits);
}

Uri? profileWhatsAppUri(String? raw) {
  final digits = canonicalProfilePhoneDigits(raw);
  if (digits == null) return null;
  return Uri.https('wa.me', '/90${digits.substring(1)}');
}
