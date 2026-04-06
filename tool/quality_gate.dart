import 'dart:convert';
import 'dart:io';

const String _baselinePath = 'tool/quality_baseline.json';
const List<String> _scanRoots = <String>['lib', 'test'];

Future<void> main(List<String> args) async {
  final bool skipPubGet = args.contains('--skip-pub-get');
  final bool skipTests = args.contains('--skip-tests');
  final bool updateBaseline = args.contains('--update-baseline');

  final QualityMetrics metrics = await _collectMetrics();

  if (updateBaseline) {
    final Map<String, Object> baseline = <String, Object>{
      'ignore_for_file_max': metrics.ignoreForFileCount,
      'max_dart_file_lines': metrics.maxDartFileLines > 1200
          ? metrics.maxDartFileLines
          : 1200,
    };
    final String encoded = const JsonEncoder.withIndent('  ').convert(baseline);
    await File(_baselinePath).writeAsString('$encoded\n');
    stdout.writeln('Updated $_baselinePath');
    return;
  }

  final Map<String, dynamic> baseline = await _loadBaseline();
  final int ignoreForFileMax = _asInt(baseline['ignore_for_file_max']);
  final int maxDartFileLines = _asInt(baseline['max_dart_file_lines']);

  _printMetrics(metrics, ignoreForFileMax, maxDartFileLines);
  _enforceMetrics(metrics, ignoreForFileMax, maxDartFileLines);

  if (!skipPubGet) {
    await _runStep('flutter pub get', 'flutter', <String>['pub', 'get']);
  }

  await _runStep('dart format --set-exit-if-changed', 'dart', <String>[
    'format',
    '--output=none',
    '--set-exit-if-changed',
    'lib',
    'test',
  ]);
  await _runStep('flutter analyze', 'flutter', <String>['analyze']);
  if (!skipTests) {
    await _runStep('flutter test', 'flutter', <String>['test']);
  }

  stdout.writeln('Quality gate passed.');
}

Future<void> _runStep(
  String label,
  String executable,
  List<String> arguments,
) async {
  stdout.writeln('');
  stdout.writeln('==> $label');
  final Process process = await Process.start(
    executable,
    arguments,
    runInShell: true,
  );
  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);
  final int exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw ProcessException(executable, arguments, '$label failed', exitCode);
  }
}

Future<Map<String, dynamic>> _loadBaseline() async {
  final File file = File(_baselinePath);
  if (!await file.exists()) {
    throw StateError('Missing baseline file: $_baselinePath');
  }
  final String content = await file.readAsString();
  final Object? decoded = jsonDecode(content);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Invalid baseline JSON in $_baselinePath');
  }
  return decoded;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.parse(value);
  throw StateError('Expected integer value, got: $value');
}

Future<QualityMetrics> _collectMetrics() async {
  int ignoreForFileCount = 0;
  int temporaryCommentCount = 0;
  int maxDartFileLines = 0;
  String maxDartFilePath = '';

  final RegExp ignoreForFilePattern = RegExp(
    r'^\s*//\s*ignore_for_file:',
    multiLine: true,
  );
  final RegExp temporaryCommentPattern = RegExp(r'//\s*eklendi\b');

  for (final String root in _scanRoots) {
    final Directory dir = Directory(root);
    if (!await dir.exists()) {
      continue;
    }

    await for (final FileSystemEntity entity in dir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final String content = await entity.readAsString();
      final int lineCount = '\n'.allMatches(content).length + 1;
      if (lineCount > maxDartFileLines) {
        maxDartFileLines = lineCount;
        maxDartFilePath = entity.path.replaceAll('\\', '/');
      }

      ignoreForFileCount += ignoreForFilePattern.allMatches(content).length;
      temporaryCommentCount += temporaryCommentPattern
          .allMatches(content)
          .length;
    }
  }

  return QualityMetrics(
    ignoreForFileCount: ignoreForFileCount,
    temporaryCommentCount: temporaryCommentCount,
    maxDartFileLines: maxDartFileLines,
    maxDartFilePath: maxDartFilePath,
  );
}

void _printMetrics(
  QualityMetrics metrics,
  int ignoreForFileMax,
  int maxDartFileLines,
) {
  stdout.writeln('Quality metrics:');
  stdout.writeln(
    '- ignore_for_file count: ${metrics.ignoreForFileCount} (max $ignoreForFileMax)',
  );
  stdout.writeln(
    '- temporary comment count: ${metrics.temporaryCommentCount} (must be 0)',
  );
  stdout.writeln(
    '- largest dart file: ${metrics.maxDartFilePath} (${metrics.maxDartFileLines} lines, max $maxDartFileLines)',
  );
}

void _enforceMetrics(
  QualityMetrics metrics,
  int ignoreForFileMax,
  int maxDartFileLines,
) {
  final List<String> errors = <String>[];

  if (metrics.temporaryCommentCount > 0) {
    errors.add(
      'Found ${metrics.temporaryCommentCount} temporary "//eklendi" comment(s). Remove temporary markers before merge.',
    );
  }
  if (metrics.ignoreForFileCount > ignoreForFileMax) {
    errors.add(
      'ignore_for_file count increased to ${metrics.ignoreForFileCount} (baseline max: $ignoreForFileMax).',
    );
  }
  if (metrics.maxDartFileLines > maxDartFileLines) {
    errors.add(
      'Largest Dart file exceeds baseline max: ${metrics.maxDartFilePath} (${metrics.maxDartFileLines} > $maxDartFileLines).',
    );
  }

  if (errors.isEmpty) {
    return;
  }

  final StringBuffer buffer = StringBuffer('Quality guard failed:\n');
  for (final String error in errors) {
    buffer.writeln('- $error');
  }
  buffer.writeln('If this change is intentional, run:');
  buffer.writeln('dart run tool/quality_gate.dart --update-baseline');
  throw StateError(buffer.toString());
}

class QualityMetrics {
  const QualityMetrics({
    required this.ignoreForFileCount,
    required this.temporaryCommentCount,
    required this.maxDartFileLines,
    required this.maxDartFilePath,
  });

  final int ignoreForFileCount;
  final int temporaryCommentCount;
  final int maxDartFileLines;
  final String maxDartFilePath;
}
