import 'dart:convert';
import 'dart:io';

const String _baselinePath = 'tool/quality_baseline.json';
const String _coverageLcovPath = 'coverage/lcov.info';
const List<String> _scanRoots = <String>['lib', 'test', 'tool'];
const int _absoluteIgnoreForFileMax = 0;
const int _absoluteDartFileLineMax = 1200;
const double _absoluteCoverageFloor = 19;
const Set<String> _allowedLegacyFormatExclusions = <String>{};
const Set<String> _allowedLegacyAnalyzerExclusions = <String>{};

Future<void> main(List<String> args) async {
  final bool skipPubGet = args.contains('--skip-pub-get');
  final bool skipTests = args.contains('--skip-tests');
  final bool metricsOnly = args.contains('--metrics-only');
  final bool formatOnly = args.contains('--format-only');
  final bool updateBaseline = args.contains('--update-baseline');

  final QualityMetrics metrics = await _collectMetrics();
  await _validateAnalyzerExclusions();
  final Map<String, dynamic> currentBaseline = await _loadBaseline();
  final int ignoreForFileMax = _asInt(currentBaseline['ignore_for_file_max']);
  final int maxDartFileLines = _asInt(currentBaseline['max_dart_file_lines']);
  final Map<String, int> legacyFileLineLimits = _asIntMap(
    currentBaseline['legacy_file_line_limits'],
  );
  final List<String> legacyFormatExclusions = _asStringList(
    currentBaseline['legacy_format_exclusions'],
  );
  final double minLineCoveragePct = _asDouble(
    currentBaseline['min_line_coverage_pct'],
  );
  _validatePolicyConfiguration(
    ignoreForFileMax: ignoreForFileMax,
    maxDartFileLines: maxDartFileLines,
    minLineCoveragePct: minLineCoveragePct,
    legacyFormatExclusions: legacyFormatExclusions,
  );

  if (updateBaseline) {
    _validateBaselineUpdate(
      metrics,
      ignoreForFileMax,
      maxDartFileLines,
      legacyFileLineLimits,
    );
    final legacyEntries =
        legacyFileLineLimits.entries
            .where((entry) {
              final currentLines = metrics.dartFileLines[entry.key];
              return currentLines != null && currentLines > maxDartFileLines;
            })
            .map(
              (entry) => MapEntry(entry.key, metrics.dartFileLines[entry.key]!),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final legacyKeys = legacyEntries.map((entry) => entry.key).toSet();
    final updatedFormatExclusions =
        legacyFormatExclusions.where(legacyKeys.contains).toList()..sort();
    final Map<String, Object> baseline = <String, Object>{
      'ignore_for_file_max': metrics.ignoreForFileCount,
      'max_dart_file_lines': maxDartFileLines,
      'legacy_file_line_limits': <String, int>{
        for (final entry in legacyEntries) entry.key: entry.value,
      },
      'legacy_format_exclusions': updatedFormatExclusions,
      'min_line_coverage_pct': minLineCoveragePct,
    };
    final String encoded = const JsonEncoder.withIndent('  ').convert(baseline);
    await File(_baselinePath).writeAsString('$encoded\n');
    stdout.writeln('Updated $_baselinePath');
    return;
  }

  _printMetrics(
    metrics,
    ignoreForFileMax,
    maxDartFileLines,
    legacyFileLineLimits,
  );
  _enforceMetrics(
    metrics,
    ignoreForFileMax,
    maxDartFileLines,
    legacyFileLineLimits,
    legacyFormatExclusions,
  );
  if (metricsOnly) {
    stdout.writeln('Metric guard passed.');
    return;
  }

  if (!skipPubGet && !formatOnly) {
    await _runStep('flutter pub get', 'flutter', <String>['pub', 'get']);
  }

  final changedDartFiles = await _collectChangedDartFiles(
    legacyFormatExclusions.toSet(),
  );
  if (changedDartFiles.isEmpty) {
    stdout.writeln('No changed Dart files require format verification.');
  } else {
    await _runStep(
      'dart format --set-exit-if-changed (${changedDartFiles.length} changed files)',
      'dart',
      <String>[
        'format',
        '--output=none',
        '--set-exit-if-changed',
        ...changedDartFiles,
      ],
    );
  }
  if (formatOnly) {
    stdout.writeln('Changed-file format guard passed.');
    return;
  }
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

Future<void> _validateAnalyzerExclusions() async {
  final file = File('analysis_options.yaml');
  if (!await file.exists()) {
    throw StateError('Missing analysis_options.yaml');
  }

  final excludedLibDartFiles = <String>{};
  final exclusionLine = RegExp(r'''^\s*-\s*["']?([^"']+\.dart)["']?\s*$''');
  for (final line in await file.readAsLines()) {
    final match = exclusionLine.firstMatch(line);
    final path = match?.group(1)?.replaceAll('\\', '/');
    if (path != null && path.startsWith('lib/')) {
      excludedLibDartFiles.add(path);
    }
  }

  final unexpected = excludedLibDartFiles.difference(
    _allowedLegacyAnalyzerExclusions,
  );
  final missing = _allowedLegacyAnalyzerExclusions.difference(
    excludedLibDartFiles,
  );
  if (unexpected.isNotEmpty || missing.isNotEmpty) {
    throw StateError(
      'Analyzer exclusion policy mismatch. '
      'Unexpected: ${unexpected.toList()..sort()}; '
      'missing: ${missing.toList()..sort()}',
    );
  }
}

Future<void> _runStep(
  String label,
  String executable,
  List<String> arguments,
) async {
  stdout.writeln('');
  stdout.writeln('==> $label');
  final resolvedExecutable = executable == 'dart'
      ? Platform.resolvedExecutable
      : executable;
  final Process process = await Process.start(
    resolvedExecutable,
    arguments,
    // Invoking the Dart VM through cmd.exe subjects changed-file format checks
    // to Windows' much smaller shell command-line limit. The VM path is already
    // absolute, so launch it directly; Flutter still needs shell resolution.
    runInShell: executable != 'dart',
  );
  final stdoutPump = stdout.addStream(process.stdout);
  final stderrPump = stderr.addStream(process.stderr);
  final int exitCode = await process.exitCode;
  await Future.wait<void>(<Future<void>>[stdoutPump, stderrPump]);
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

Map<String, int> _asIntMap(Object? value) {
  if (value == null) {
    return const <String, int>{};
  }
  if (value is! Map<String, dynamic>) {
    throw StateError('Expected string-to-integer map, got: $value');
  }
  return <String, int>{
    for (final MapEntry<String, dynamic> entry in value.entries)
      entry.key.replaceAll('\\', '/'): _asInt(entry.value),
  };
}

List<String> _asStringList(Object? value) {
  if (value == null) return <String>[];
  if (value is! List) {
    throw StateError('Expected string list, got: $value');
  }
  return value
      .map((item) => item.toString().replaceAll('\\', '/').trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Future<List<String>> _collectChangedDartFiles(
  Set<String> formatExclusions,
) async {
  final workingTreeFiles = <String>{
    ...await _runGitLines(<String>[
      'diff',
      '--name-only',
      '--diff-filter=ACMR',
      'HEAD',
    ]),
    ...await _runGitLines(<String>[
      'ls-files',
      '--others',
      '--exclude-standard',
    ]),
  };
  final candidates = workingTreeFiles.isNotEmpty
      ? workingTreeFiles
      : (await _runGitLines(<String>[
          'diff-tree',
          '--no-commit-id',
          '--name-only',
          '-r',
          '-m',
          '--root',
          'HEAD',
        ])).toSet();

  final changedDartFiles =
      candidates
          .map((path) => path.replaceAll('\\', '/').trim())
          .where(
            (path) =>
                path.endsWith('.dart') &&
                _scanRoots.any((root) => path.startsWith('$root/')) &&
                !formatExclusions.contains(path) &&
                File(path).existsSync(),
          )
          .toSet()
          .toList()
        ..sort();
  return changedDartFiles;
}

Future<List<String>> _runGitLines(List<String> arguments) async {
  final result = await Process.run('git', arguments, runInShell: true);
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      arguments,
      result.stderr.toString().trim(),
      result.exitCode,
    );
  }
  return const LineSplitter()
      .convert(result.stdout.toString())
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

void _validatePolicyConfiguration({
  required int ignoreForFileMax,
  required int maxDartFileLines,
  required double minLineCoveragePct,
  required List<String> legacyFormatExclusions,
}) {
  if (ignoreForFileMax > _absoluteIgnoreForFileMax) {
    throw StateError(
      'ignore_for_file baseline cannot exceed $_absoluteIgnoreForFileMax.',
    );
  }
  if (maxDartFileLines > _absoluteDartFileLineMax) {
    throw StateError(
      'Dart file line baseline cannot exceed $_absoluteDartFileLineMax.',
    );
  }
  if (minLineCoveragePct < _absoluteCoverageFloor) {
    throw StateError(
      'Coverage baseline cannot fall below $_absoluteCoverageFloor%.',
    );
  }
  final unsupportedExclusions = legacyFormatExclusions
      .where((path) => !_allowedLegacyFormatExclusions.contains(path))
      .toList(growable: false);
  if (unsupportedExclusions.isNotEmpty) {
    throw StateError(
      'Unsupported legacy format exclusion(s): '
      '${unsupportedExclusions.join(', ')}',
    );
  }
}

Future<QualityMetrics> _collectMetrics() async {
  int ignoreForFileCount = 0;
  int temporaryCommentCount = 0;
  int maxDartFileLines = 0;
  String maxDartFilePath = '';
  final Map<String, int> dartFileLines = <String, int>{};

  final RegExp ignoreForFilePattern = RegExp(
    r'^\s*//\s*ignore_for_file:',
    multiLine: true,
  );
  final RegExp temporaryCommentPattern = RegExp(
    r'^\s*//\s*eklendi\b',
    multiLine: true,
  );

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
      final String normalizedPath = entity.path.replaceAll('\\', '/');
      dartFileLines[normalizedPath] = lineCount;
      if (lineCount > maxDartFileLines) {
        maxDartFileLines = lineCount;
        maxDartFilePath = normalizedPath;
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
    dartFileLines: dartFileLines,
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
  Map<String, int> legacyFileLineLimits,
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
  stdout.writeln(
    '- legacy oversized files: ${legacyFileLineLimits.length} '
    '(each file may only stay at or below its recorded limit)',
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
  Map<String, int> legacyFileLineLimits,
  List<String> legacyFormatExclusions,
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
  for (final MapEntry<String, int> entry in metrics.dartFileLines.entries) {
    final int allowedLines =
        legacyFileLineLimits[entry.key] ?? maxDartFileLines;
    if (entry.value > allowedLines) {
      errors.add(
        'Dart file exceeds its line limit: ${entry.key} '
        '(${entry.value} > $allowedLines).',
      );
    }
  }
  for (final MapEntry<String, int> entry in legacyFileLineLimits.entries) {
    final int? currentLines = metrics.dartFileLines[entry.key];
    if (currentLines == null) {
      errors.add(
        'Legacy line-limit exception points to a missing file: ${entry.key}. '
        'Remove it from $_baselinePath.',
      );
    } else if (currentLines <= maxDartFileLines) {
      errors.add(
        'Legacy line-limit exception is no longer needed: ${entry.key} '
        '($currentLines <= $maxDartFileLines). Remove it from $_baselinePath.',
      );
    } else if (currentLines < entry.value) {
      errors.add(
        'Legacy line-limit improved: ${entry.key} '
        '($currentLines < ${entry.value}). Ratchet its baseline down to '
        '$currentLines with --update-baseline.',
      );
    }
  }
  for (final exclusion in legacyFormatExclusions) {
    if (!metrics.dartFileLines.containsKey(exclusion)) {
      errors.add(
        'Legacy format exclusion points to a missing file: $exclusion. '
        'Remove it from $_baselinePath.',
      );
    } else if (!legacyFileLineLimits.containsKey(exclusion)) {
      errors.add(
        'Legacy format exclusion is no longer backed by an oversized-file '
        'ratchet: $exclusion. Remove it from $_baselinePath.',
      );
    }
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

void _validateBaselineUpdate(
  QualityMetrics metrics,
  int ignoreForFileMax,
  int maxDartFileLines,
  Map<String, int> legacyFileLineLimits,
) {
  final errors = <String>[];
  if (metrics.temporaryCommentCount > 0) {
    errors.add('Temporary comments must be removed before updating baseline.');
  }
  if (metrics.ignoreForFileCount > ignoreForFileMax) {
    errors.add(
      'A baseline update cannot increase ignore_for_file '
      '(${metrics.ignoreForFileCount} > $ignoreForFileMax).',
    );
  }
  for (final entry in metrics.dartFileLines.entries) {
    final allowed = legacyFileLineLimits[entry.key] ?? maxDartFileLines;
    if (entry.value > allowed) {
      errors.add(
        'A baseline update cannot add or grow an oversized file: '
        '${entry.key} (${entry.value} > $allowed).',
      );
    }
  }
  if (errors.isEmpty) return;

  final buffer = StringBuffer('Monotonic baseline update rejected:\n');
  for (final error in errors) {
    buffer.writeln('- $error');
  }
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
    required this.dartFileLines,
  });

  final int ignoreForFileCount;
  final int temporaryCommentCount;
  final int maxDartFileLines;
  final String maxDartFilePath;
  final Map<String, int> dartFileLines;
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
