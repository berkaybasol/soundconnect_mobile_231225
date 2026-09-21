import 'package:flutter/services.dart';

/// Groups TL digits while retaining an explicit, optional kuruş separator.
/// Existing grouping dots must not become decimals when adjacent digits change.
class MarketplacePriceInputFormatter extends TextInputFormatter {
  // Keep one instance per field so an IME commit can be compared with the last
  // formatted value rather than its temporarily unformatted composing text.
  TextEditingValue? _beforeComposition;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length > 64) return oldValue;
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      _beforeComposition ??= oldValue;
      return newValue;
    }
    if (_beforeComposition != null &&
        oldValue.composing.isValid &&
        !oldValue.composing.isCollapsed) {
      oldValue = _beforeComposition!;
    }
    _beforeComposition = null;
    if (newValue.text.isEmpty) return newValue;
    final raw = newValue.text;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const TextEditingValue();
    if (!RegExp(r'^[0-9.,]+$').hasMatch(trimmed)) return oldValue;

    // Identify the replaced range, including select-all pastes which can share
    // a prefix with the old value but supply a different decimal convention.
    var start = 0;
    var oldEnd = oldValue.text.length;
    var newEnd = raw.length;
    final selection = oldValue.selection;
    if (selection.isValid &&
        !selection.isCollapsed &&
        selection.end <= oldEnd &&
        raw.length >= oldEnd - (selection.end - selection.start) &&
        raw.startsWith(oldValue.text.substring(0, selection.start)) &&
        raw.endsWith(oldValue.text.substring(selection.end))) {
      start = selection.start;
      oldEnd = selection.end;
      newEnd = raw.length - (oldValue.text.length - oldEnd);
    } else {
      while (start < oldEnd &&
          start < newEnd &&
          oldValue.text[start] == raw[start]) {
        start++;
      }
      while (oldEnd > start &&
          newEnd > start &&
          oldValue.text[oldEnd - 1] == raw[newEnd - 1]) {
        oldEnd--;
        newEnd--;
      }
    }

    final left = raw.indexOf(trimmed);
    final oldHasGrouping =
        (oldValue.composing.isCollapsed || !oldValue.composing.isValid) &&
        RegExp(r'^\d{1,3}(\.\d{3})+(,\d{0,2})?$').hasMatch(oldValue.text);
    var characters = <({String char, int source})>[];
    for (var i = left; i < left + trimmed.length; i++) {
      // Dots outside the replacement came from our previous formatted value.
      if (oldHasGrouping && raw[i] == '.' && (i < start || i >= newEnd)) {
        continue;
      }
      characters.add((char: raw[i], source: i));
    }
    var text = characters.map((item) => item.char).join();
    final typedDecimalDot = newEnd - start == 1 && raw[start] == '.';
    if (!typedDecimalDot &&
        RegExp(r'^\d{1,3}(\.\d{3})+(,\d{0,2})?$').hasMatch(text)) {
      characters.removeWhere((item) => item.char == '.');
    } else if (RegExp(r'^\d*\.\d{0,2}$').hasMatch(text)) {
      characters = [
        for (final item in characters)
          (char: item.char == '.' ? ',' : item.char, source: item.source),
      ];
    }
    text = characters.map((item) => item.char).join();
    if (!RegExp(r'^\d*(,\d{0,2})?$').hasMatch(text)) return oldValue;
    if (text.startsWith(',')) {
      characters.insert(0, (char: '0', source: -1));
    }
    while (characters.length > 1 &&
        characters[0].char == '0' &&
        characters[1].char != ',') {
      characters.removeAt(0);
    }
    final comma = characters.indexWhere((item) => item.char == ',');
    final wholeLength = comma < 0 ? characters.length : comma;
    if (wholeLength > 10) return oldValue;

    final formatted = StringBuffer();
    final boundaries = <int>[0];
    for (var i = 0; i < characters.length; i++) {
      if (i > 0 && i < wholeLength && (wholeLength - i) % 3 == 0) {
        formatted.write('.');
      }
      formatted.write(characters[i].char);
      boundaries.add(formatted.length);
    }
    final result = formatted.toString();
    int remap(int offset) {
      if (offset <= 0) return 0;
      final retained = characters.where((item) => item.source < offset).length;
      return boundaries[retained];
    }

    var nextSelection = newValue.selection.isValid
        ? TextSelection(
            baseOffset: remap(newValue.selection.baseOffset),
            extentOffset: remap(newValue.selection.extentOffset),
            affinity: newValue.selection.affinity,
            isDirectional: newValue.selection.isDirectional,
          )
        : TextSelection.collapsed(offset: result.length);

    // Delete before a grouping dot crosses it instead of getting stuck as the
    // dot is reinserted. Backspace already lands on its left-hand boundary.
    if (oldEnd - start == 1 &&
        newEnd == start &&
        oldValue.text[start] == '.' &&
        selection.isCollapsed &&
        selection.baseOffset == start &&
        nextSelection.isCollapsed &&
        nextSelection.baseOffset < result.length &&
        result[nextSelection.baseOffset] == '.') {
      nextSelection = TextSelection.collapsed(
        offset: nextSelection.baseOffset + 1,
      );
    }
    return TextEditingValue(text: result, selection: nextSelection);
  }
}
