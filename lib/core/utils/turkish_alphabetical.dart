const String _turkishAlphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';

int compareTurkishAlphabetical(String left, String right) {
  final normalizedLeft = _normalizeTurkish(left);
  final normalizedRight = _normalizeTurkish(right);
  var leftIndex = 0;
  var rightIndex = 0;

  while (leftIndex < normalizedLeft.length &&
      rightIndex < normalizedRight.length) {
    final leftIsDigit = _isAsciiDigit(normalizedLeft.codeUnitAt(leftIndex));
    final rightIsDigit = _isAsciiDigit(normalizedRight.codeUnitAt(rightIndex));
    if (leftIsDigit && rightIsDigit) {
      final leftEnd = _digitRunEnd(normalizedLeft, leftIndex);
      final rightEnd = _digitRunEnd(normalizedRight, rightIndex);
      final numericComparison = _compareDigitRuns(
        normalizedLeft,
        leftIndex,
        leftEnd,
        normalizedRight,
        rightIndex,
        rightEnd,
      );
      if (numericComparison != 0) return numericComparison;
      leftIndex = leftEnd;
      rightIndex = rightEnd;
      continue;
    }
    if (leftIsDigit != rightIsDigit) return leftIsDigit ? -1 : 1;

    final leftEnd = _nonDigitRunEnd(normalizedLeft, leftIndex);
    final rightEnd = _nonDigitRunEnd(normalizedRight, rightIndex);
    final textComparison = _compareTurkishTextRun(
      normalizedLeft,
      leftIndex,
      leftEnd,
      normalizedRight,
      rightIndex,
      rightEnd,
    );
    if (textComparison != 0) return textComparison;
    leftIndex = leftEnd;
    rightIndex = rightEnd;
  }

  final lengthComparison = normalizedLeft.length.compareTo(
    normalizedRight.length,
  );
  if (lengthComparison != 0) return lengthComparison;
  return left.compareTo(right);
}

List<T> sortByTurkishName<T>(
  Iterable<T> values,
  String Function(T value) nameOf,
) {
  final sorted = List<T>.of(values);
  sorted.sort(
    (left, right) => compareTurkishAlphabetical(nameOf(left), nameOf(right)),
  );
  return sorted;
}

String _normalizeTurkish(String value) {
  return value
      .replaceAll('I', 'ı')
      .replaceAll('İ', 'i')
      .toLowerCase()
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u');
}

int _compareTurkishTextRun(
  String left,
  int leftStart,
  int leftEnd,
  String right,
  int rightStart,
  int rightEnd,
) {
  var leftIndex = leftStart;
  var rightIndex = rightStart;
  while (leftIndex < leftEnd && rightIndex < rightEnd) {
    final leftWeight = _turkishWeight(left.codeUnitAt(leftIndex));
    final rightWeight = _turkishWeight(right.codeUnitAt(rightIndex));
    final comparison = leftWeight.compareTo(rightWeight);
    if (comparison != 0) return comparison;
    leftIndex++;
    rightIndex++;
  }
  return (leftEnd - leftStart).compareTo(rightEnd - rightStart);
}

int _turkishWeight(int codeUnit) {
  final character = String.fromCharCode(codeUnit);
  final alphabetIndex = _turkishAlphabet.indexOf(character);
  if (alphabetIndex >= 0) return 1000 + alphabetIndex;
  if (codeUnit == 32) return 0;
  return 100 + codeUnit;
}

int _compareDigitRuns(
  String left,
  int leftStart,
  int leftEnd,
  String right,
  int rightStart,
  int rightEnd,
) {
  final leftSignificantStart = _skipLeadingZeros(left, leftStart, leftEnd);
  final rightSignificantStart = _skipLeadingZeros(right, rightStart, rightEnd);
  final leftSignificantLength = leftEnd - leftSignificantStart;
  final rightSignificantLength = rightEnd - rightSignificantStart;
  final lengthComparison = leftSignificantLength.compareTo(
    rightSignificantLength,
  );
  if (lengthComparison != 0) return lengthComparison;

  for (var index = 0; index < leftSignificantLength; index++) {
    final comparison = left
        .codeUnitAt(leftSignificantStart + index)
        .compareTo(right.codeUnitAt(rightSignificantStart + index));
    if (comparison != 0) return comparison;
  }
  return (leftEnd - leftStart).compareTo(rightEnd - rightStart);
}

int _skipLeadingZeros(String value, int start, int end) {
  var index = start;
  while (index < end - 1 && value.codeUnitAt(index) == 48) {
    index++;
  }
  return index;
}

int _digitRunEnd(String value, int start) {
  var index = start;
  while (index < value.length && _isAsciiDigit(value.codeUnitAt(index))) {
    index++;
  }
  return index;
}

int _nonDigitRunEnd(String value, int start) {
  var index = start;
  while (index < value.length && !_isAsciiDigit(value.codeUnitAt(index))) {
    index++;
  }
  return index;
}

bool _isAsciiDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
