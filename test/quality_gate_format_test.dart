import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/quality_gate.dart' as gate;

const _executable = r'C:\Program Files\Flutter\bin\cache\dart-sdk\bin\dart.exe';
const _flags = ['format', '--output=none', '--set-exit-if-changed'];

// Independent Windows CRT quoting calculation; the production estimate is a
// conservative upper bound, while this counts escaped quotes and backslashes.
int _quotedLength(String value) {
  var length = 2;
  var slashes = 0;
  for (final unit in value.codeUnits) {
    if (unit == 92) {
      slashes++;
    } else {
      length += slashes * (unit == 34 ? 2 : 1) + (unit == 34 ? 2 : 1);
      slashes = 0;
    }
  }
  return length + slashes * 2;
}

int _commandLength(List<String> arguments) =>
    [_executable, ...arguments].map(_quotedLength).reduce((a, b) => a + b) +
    arguments.length +
    1;

Future<List<List<String>>> _capture(List<String> files) async {
  final calls = <List<String>>[];
  await gate.runDartFormatChecks(
    files,
    dartExecutable: _executable,
    runBatch: (_, arguments) async => calls.add(arguments),
  );
  return calls;
}

void main() {
  test('empty selection does not invoke a formatter', () async {
    expect(await _capture([]), isEmpty);
  });

  test(
    'small selection preserves verification flags and exact input order',
    () async {
      const files = ['lib/z.dart', 'test/a.dart'];
      expect(await _capture(files), [
        <String>[..._flags, ...files],
      ]);
    },
  );

  test(
    '821 long paths are covered once in deterministic bounded commands',
    () async {
      final files = List.generate(
        821,
        (i) => 'lib/modules/${'notification_feature/' * 7}file_$i.dart',
      );
      final first = await _capture(files);
      expect(first, await _capture(files));
      expect(first.length, greaterThan(2));
      expect(first.expand((batch) => batch.skip(_flags.length)), files);
      for (final batch in first) {
        expect(batch.take(_flags.length), _flags);
        expect(batch.length, greaterThan(_flags.length));
        expect(
          _commandLength(batch),
          lessThanOrEqualTo(gate.dartFormatCommandBudget),
        );
      }
    },
  );

  test(
    'spaces quotes backslashes and astral Unicode stay within the bound',
    () async {
      final files = List.generate(
        30,
        (i) => 'test/space ${'🎵' * 400}/quoted"name\\$i.dart\\',
      );
      final calls = await _capture(files);
      expect(calls.length, greaterThan(1));
      expect(calls.expand((batch) => batch.skip(_flags.length)), files);
      for (final batch in calls) {
        expect(
          _commandLength(batch),
          lessThanOrEqualTo(gate.dartFormatCommandBudget),
        );
      }
    },
  );

  test(
    'a single oversized path fails before any partial verification',
    () async {
      var calls = 0;
      await expectLater(
        gate.runDartFormatChecks(
          ['lib/normal.dart', 'x' * gate.dartFormatCommandBudget],
          dartExecutable: _executable,
          runBatch: (_, _) async => calls++,
        ),
        throwsArgumentError,
      );
      expect(calls, 0);
    },
  );

  test(
    'executable length is included in the complete command budget',
    () async {
      var calls = 0;
      await expectLater(
        gate.runDartFormatChecks(
          ['lib/a.dart'],
          dartExecutable: 'x' * gate.dartFormatCommandBudget,
          runBatch: (_, _) async => calls++,
        ),
        throwsArgumentError,
      );
      expect(calls, 0);
    },
  );

  test(
    'formatter failure propagates unchanged and no later batch starts',
    () async {
      final files = List.generate(821, (i) => '${'long_path/' * 12}$i.dart');
      final expected = await _capture(files);
      expect(expected.length, greaterThan(2));
      final started = <List<String>>[];
      final failure = ProcessException(
        _executable,
        expected[1],
        'format failed',
        1,
      );
      await expectLater(
        gate.runDartFormatChecks(
          files,
          dartExecutable: _executable,
          runBatch: (_, arguments) async {
            started.add(arguments);
            if (started.length == 2) throw failure;
          },
        ),
        throwsA(same(failure)),
      );
      expect(started, expected.take(2));
    },
  );

  test('later batches wait for the preceding formatter to finish', () async {
    final files = List.generate(100, (i) => '${'directory/' * 40}$i.dart');
    final events = <String>[];
    var active = 0;
    await gate.runDartFormatChecks(
      files,
      dartExecutable: _executable,
      runBatch: (label, _) async {
        expect(active, 0);
        active++;
        events.add('start $label');
        await Future<void>.delayed(Duration.zero);
        events.add('end $label');
        active--;
      },
    );
    expect(events.length, greaterThan(2));
    for (var i = 0; i < events.length; i += 2) {
      expect(events[i].substring(6), events[i + 1].substring(4));
    }
  });
}
