import 'package:characters/characters.dart';

/// Display-only, per-membership text. Never use this value for authorization.
abstract final class BandMemberTitlePolicy {
  static const maxCharacters = 20;
  static const maxCodePoints = 256;
  static final _controlOrFormat = RegExp(
    r'[\p{Cc}\p{Cf}\p{Cs}]',
    unicode: true,
  );
  static final _visibleBase = RegExp(r'[\p{L}\p{N}\p{P}\p{S}]', unicode: true);

  static String? normalize(String? value) {
    final title = value?.trim();
    return title == null || title.isEmpty ? null : title;
  }

  static String? validationMessage(String? value) {
    if (value == null) return null;
    // Bound work even when one visible grapheme contains many combining marks.
    if (value.length > maxCodePoints * 2 ||
        value.runes.length > maxCodePoints) {
      return 'En fazla 20 karakter kullanabilirsin.';
    }
    for (final rune in value.runes) {
      // Joiners are needed by normal scripts and joined emoji sequences.
      if (rune == 0x200c || rune == 0x200d) continue;
      if (rune == 0x2028 ||
          rune == 0x2029 ||
          _controlOrFormat.hasMatch(String.fromCharCode(rune))) {
        return 'Rolü tek satırda, görünür karakterlerle yaz.';
      }
    }
    final title = normalize(value);
    if (title != null && !_visibleBase.hasMatch(title)) {
      return 'Görünür bir karakter kullan.';
    }
    if (title != null && title.characters.length > maxCharacters) {
      return 'En fazla 20 karakter kullanabilirsin.';
    }
    return null;
  }
}
