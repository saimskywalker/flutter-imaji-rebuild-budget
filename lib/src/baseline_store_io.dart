import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Resolves [path] against the directory of the running test file, the way
/// golden files are, falling back to the working directory.
String resolveBaselinePath(String path) {
  final uri = Uri.file(path);
  if (uri.isAbsolute || File(path).isAbsolute) return path;
  final comparator = goldenFileComparator;
  final base = comparator is LocalFileComparator
      ? comparator.basedir
      : Directory.current.uri.resolve('./');
  return base.resolveUri(uri).toFilePath();
}

/// Reads the baseline at [resolvedPath], or `null` if it does not exist.
///
/// Throws a [FormatException] when the file is not a JSON object of
/// objects of integers.
Map<String, Map<String, int>>? readBaseline(String resolvedPath) {
  final file = File(resolvedPath);
  if (!file.existsSync()) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    throw FormatException(
      'Rebuild baseline $resolvedPath is not valid JSON: ${error.message}',
    );
  }
  FormatException shape(String detail) => FormatException(
        'Rebuild baseline $resolvedPath must map each key to an object of '
        'widget type names and integer budgets; $detail.',
      );
  if (decoded is! Map<String, Object?>) throw shape('the top level is not');
  return {
    for (final entry in decoded.entries)
      entry.key: switch (entry.value) {
        final Map<String, Object?> budgets => {
            for (final budget in budgets.entries)
              budget.key: switch (budget.value) {
                final int n when n >= 0 => n,
                _ => throw shape('"${entry.key}" -> "${budget.key}" is not'),
              },
          },
        _ => throw shape('"${entry.key}" is not'),
      },
  };
}

/// Writes [baseline] to [resolvedPath] with sorted keys and two-space
/// indentation, so a changed budget is a one-line diff.
void writeBaseline(
  String resolvedPath,
  Map<String, Map<String, int>> baseline,
) {
  final sorted = {
    for (final key in baseline.keys.toList()..sort())
      key: {
        for (final type in baseline[key]!.keys.toList()..sort())
          type: baseline[key]![type],
      },
  };
  final file = File(resolvedPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(sorted)}\n',
  );
}
