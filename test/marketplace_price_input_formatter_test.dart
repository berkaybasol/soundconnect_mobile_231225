import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/domain/marketplace_models.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/marketplace_price_input_formatter.dart';

late MarketplacePriceInputFormatter formatter;
TextEditingValue value(String text, [int? caret]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret ?? text.length),
);
TextEditingValue edit(String old, String next, {int? before, int? after}) =>
    formatter.formatEditUpdate(value(old, before), value(next, after));

void main() {
  setUp(() => formatter = MarketplacePriceInputFormatter());
  test('groups typed whole TL and keeps explicit kuruş exact', () {
    var current = value('');
    for (final digit in '12500'.split('')) {
      current = formatter.formatEditUpdate(
        current,
        value('${current.text}$digit'),
      );
    }
    expect(current.text, '12.500');
    expect(current.selection.baseOffset, 6);
    for (final digit in ',50'.split('')) {
      current = formatter.formatEditUpdate(
        current,
        value('${current.text}$digit'),
      );
    }
    expect(current.text, '12.500,50');
    expect(parseMarketplacePriceMinor(current.text), 1250050);
  });

  test('deleting adjacent digits never turns grouping into a decimal', () {
    final result = edit('12.500', '12.50');
    expect(result.text, '1.250');
    expect(parseMarketplacePriceMinor(result.text), 125000);
    expect(result.selection.baseOffset, 5);
    expect(edit('1.234', '1.23').text, '123');
    expect(edit('12.500,50', '12.50,50', before: 6, after: 5).text, '1.250,50');
  });

  test('backspace and forward delete traverse a grouping separator', () {
    final backspace = edit('12.500', '12500', before: 3, after: 2);
    expect(backspace.text, '12.500');
    expect(backspace.selection.baseOffset, 2);
    expect(edit(backspace.text, '1.500', before: 2, after: 1).text, '1.500');
    final forward = edit('12.500', '12500', before: 2, after: 2);
    expect(forward.text, '12.500');
    expect(forward.selection.baseOffset, 3);
    expect(edit(forward.text, '12.00', before: 3, after: 3).text, '1.200');
  });

  test('middle edits keep the caret next to the edited digit', () {
    final result = edit('12.500', '192.500', before: 1, after: 2);
    expect(result.text, '192.500');
    expect(result.selection.baseOffset, 2);
    final replacement = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '12.500',
        selection: TextSelection(baseOffset: 1, extentOffset: 4),
      ),
      value('1900', 2),
    );
    expect(replacement.text, '1.900');
    expect(replacement.selection.baseOffset, 3);
  });

  test(
    'select-all paste recognizes Turkish groups and decimal-dot numbers',
    () {
      for (final entry in {
        '12.500,50': '12.500,50',
        '12500.50': '12.500,50',
        '1.234': '1.234',
        '0.01': '0,01',
        ' 12500,5 ': '12.500,5',
      }.entries) {
        final result = formatter.formatEditUpdate(
          const TextEditingValue(
            text: '12.500',
            selection: TextSelection(baseOffset: 0, extentOffset: 6),
          ),
          value(entry.key),
        );
        expect(result.text, entry.value, reason: entry.key);
        expect(result.selection.baseOffset, result.text.length);
      }
      final decimal = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '12.500',
          selection: TextSelection(baseOffset: 0, extentOffset: 6),
        ),
        value('12.50'),
      );
      expect(decimal.text, '12,50');
    },
  );

  test(
    'a newly typed decimal dot works after automatically grouped digits',
    () {
      expect(edit('12.500', '12.500.').text, '12.500,');
      expect(edit('12.500,', '12.500,5').text, '12.500,5');
      expect(parseMarketplacePriceMinor('12.500,'), 1250000);
      expect(edit('', ',').text, '0,');
      expect(edit('', ',50').text, '0,50');
    },
  );

  test(
    'invalid paste and excess cents are rejected without changing amount',
    () {
      final old = value('12.500,50');
      for (final text in [
        '-100',
        '1e6',
        '12abc',
        '12,345',
        '12..500',
        '1,234.56',
        '1.23.456',
        '99999999999',
        '12.500,501',
      ]) {
        final result = formatter.formatEditUpdate(
          old.copyWith(
            selection: const TextSelection(baseOffset: 0, extentOffset: 9),
          ),
          value(text),
        );
        expect(result.text, old.text, reason: text);
      }
    },
  );

  test('clear, leading zeros and selection ranges remain editable', () {
    expect(edit('12.500', '').text, '');
    expect(edit('', '00012500').text, '12.500');
    expect(edit('0', '05').text, '5');
    final selected = formatter.formatEditUpdate(
      value(''),
      const TextEditingValue(
        text: '12500',
        selection: TextSelection(
          baseOffset: 5,
          extentOffset: 1,
          isDirectional: true,
        ),
      ),
    );
    expect(
      selected.selection,
      const TextSelection(baseOffset: 6, extentOffset: 1, isDirectional: true),
    );
  });

  test('IME composition is left intact and normalized only after commit', () {
    const composing = TextEditingValue(
      text: '12500.50',
      selection: TextSelection.collapsed(offset: 8),
      composing: TextRange(start: 0, end: 8),
    );
    expect(formatter.formatEditUpdate(value(''), composing), composing);
    expect(
      formatter
          .formatEditUpdate(
            composing,
            composing.copyWith(composing: TextRange.empty),
          )
          .text,
      '12.500,50',
    );
  });

  test(
    'initial values and boundary amounts round-trip without floating point',
    () {
      expect(marketplacePriceInput(null), '');
      for (final minor in [
        1,
        50,
        100,
        123400,
        2850050,
        99999999999,
        100000000000,
      ]) {
        final text = marketplacePriceInput(minor);
        expect(formatter.formatEditUpdate(value(''), value(text)).text, text);
        expect(parseMarketplacePriceMinor(text), minor);
      }
      expect(marketplacePriceInput(100000000000), '1.000.000.000,00');
    },
  );

  test(
    'IME digit deletion preserves the meaning of an existing grouping dot',
    () {
      final initial = value('12.500');
      const composing = TextEditingValue(
        text: '12.50',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 3, end: 5),
      );
      expect(formatter.formatEditUpdate(initial, composing), composing);
      final committed = formatter.formatEditUpdate(
        composing,
        composing.copyWith(composing: TextRange.empty),
      );
      expect(committed.text, '1.250');
      expect(parseMarketplacePriceMinor(committed.text), 125000);
      expect(committed.selection.baseOffset, 5);
    },
  );

  test('controller replacement discards an abandoned composing edit', () {
    formatter.formatEditUpdate(
      value('12.500'),
      const TextEditingValue(
        text: '12.50',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 3, end: 5),
      ),
    );
    expect(edit('9.000', '9.0000').text, '90.000');
  });
}
