abstract final class StudioRegistrationPolicy {
  static const int studioNameMaxLength = 100;
  static const int studioAddressMaxLength = 255;

  static final RegExp _phoneCharacters = RegExp(r'^(?:\+)?[0-9() .-]+$');
  static final RegExp _nonPhoneDigits = RegExp(r'\D');

  static bool isValid({
    required String studioName,
    required String studioAddress,
    required String phone,
  }) {
    return validationMessage(
          studioName: studioName,
          studioAddress: studioAddress,
          phone: phone,
        ) ==
        null;
  }

  static String? validationMessage({
    required String studioName,
    required String studioAddress,
    required String phone,
  }) {
    final normalizedName = studioName.trim();
    if (normalizedName.isEmpty) return 'Stüdyo adı zorunludur.';
    if (normalizedName.length > studioNameMaxLength) {
      return 'Stüdyo adı en fazla $studioNameMaxLength karakter olabilir.';
    }
    final normalizedAddress = studioAddress.trim();
    if (normalizedAddress.isEmpty) return 'Açık adres zorunludur.';
    if (normalizedAddress.length > studioAddressMaxLength) {
      return 'Açık adres en fazla $studioAddressMaxLength karakter olabilir.';
    }
    if (normalizePhone(phone).isEmpty) {
      return 'Geçerli bir Türkiye telefonu gir (örn. 05551234567).';
    }
    return null;
  }

  static String normalizePhone(String rawPhone) {
    final normalized = rawPhone.trim();
    if (normalized.isEmpty || !_phoneCharacters.hasMatch(normalized)) return '';
    var digits = normalized.replaceAll(_nonPhoneDigits, '');
    if (digits.length == 10 && digits.startsWith('5')) {
      digits = '0$digits';
    } else if (digits.length == 12 && digits.startsWith('90')) {
      digits = '0${digits.substring(2)}';
    }
    return digits.length == 11 && digits.startsWith('0') ? digits : '';
  }
}
