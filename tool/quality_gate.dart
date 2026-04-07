import 'dart:convert';
import 'dart:io';

const String _baselinePath = 'tool/quality_baseline.json';
const String _coverageLcovPath = 'coverage/lcov.info';
const List<String> _scanRoots = <String>['lib', 'test'];

Future<void> main(List<String> args) async {
  final bool skipPubGet = args.contains('--skip-pub-get');
  final bool skipTests = args.contains('--skip-tests');
  final bool updateBaseline = args.contains('--update-baseline');

  final QualityMetrics metrics = await _collectMetrics();
  final Map<String, dynamic> currentBaseline = await _loadBaseline();
  final int ignoreForFileMax = _asInt(currentBaseline['ignore_for_file_max']);
  final int maxDartFileLines = _asInt(currentBaseline['max_dart_file_lines']);
  final double minLineCoveragePct = _asDouble(
    currentBaseline['min_line_coverage_pct'],
  );

  if (updateBaseline) {
    final Map<String, Object> baseline = <String, Object>{
      'ignore_for_file_max': metrics.ignoreForFileCount,
      'max_dart_file_lines': metrics.maxDartFileLines > 1200
          ? metrics.maxDartFileLines
          : 1200,
      'min_line_coverage_pct': minLineCoveragePct,
    };
    final String encoded = const JsonEncoder.withIndent('  ').convert(baseline);
    await File(_baselinePath).writeAsString('$encoded\n');
    stdout.writeln('Updated $_baselinePath');
    return;
  }

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
    await _runStep('flutter test --coverage', 'flutter', <String>[
      'test',
      '--coverage',
    ]);
    final CoverageSummary coverage = await _loadCoverageSummary(
      _coverageLcovPath,
    );
    _printCoverage(coverage, minLineCoveragePct);
    _enforceCoverage(coverage, minLineCoveragePct);
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
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.parse(value);
  }
  throw StateError('Expected integer value, got: $value');
}

double _asDouble(Object? value) {
  if (value == null) {
    return 0;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.parse(value);
  }
  throw StateError('Expected numeric value, got: $value');
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

Future<CoverageSummary> _loadCoverageSummary(String path) async {
  final File lcovFile = File(path);
  if (!await lcovFile.exists()) {
    throw StateError('Missing coverage report: $path');
  }

  int linesFound = 0;
  int linesHit = 0;
  final List<String> lines = await lcovFile.readAsLines();
  for (final String line in lines) {
    if (line.startsWith('LF:')) {
      linesFound += int.parse(line.substring(3));
      continue;
    }
    if (line.startsWith('LH:')) {
      linesHit += int.parse(line.substring(3));
    }
  }

  final double lineCoveragePct = linesFound == 0
      ? 0
      : (linesHit * 100.0) / linesFound;
  return CoverageSummary(
    linesFound: linesFound,
    linesHit: linesHit,
    lineCoveragePct: lineCoveragePct,
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

void _printCoverage(CoverageSummary coverage, double minLineCoveragePct) {
  stdout.writeln(
    '- line coverage: ${coverage.lineCoveragePct.toStringAsFixed(2)}% '
    '(min ${minLineCoveragePct.toStringAsFixed(2)}%)',
  );
  stdout.writeln(
    '- covered lines: ${coverage.linesHit}/${coverage.linesFound}',
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

void _enforceCoverage(CoverageSummary coverage, double minLineCoveragePct) {
  if (coverage.lineCoveragePct + 0.0001 >= minLineCoveragePct) {
    return;
  }
  throw StateError(
    'Line coverage regression: ${coverage.lineCoveragePct.toStringAsFixed(2)}% '
    'is below minimum ${minLineCoveragePct.toStringAsFixed(2)}%.',
  );
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

class CoverageSummary {
  const CoverageSummary({
    required this.linesFound,
    required this.linesHit,
    required this.lineCoveragePct,
  });

  final int linesFound;
  final int linesHit;
  final double lineCoveragePct;
}
