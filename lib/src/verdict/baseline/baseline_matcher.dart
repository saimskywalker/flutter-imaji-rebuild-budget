import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../output/type_table.dart';
import '../../tally/build_record.dart';
import '../../tally/rebuild_window.dart';
import '../presence.dart';
import '../window_matcher.dart';
import 'baseline_file.dart';

/// Matches a closed [RebuildWindow] against budgets stored in a JSON file,
/// like a golden file.
///
/// The file at [path] (relative to the test file, or absolute) maps each
/// [key] to one budget per tracked entry: every type in [types], counted by
/// exact type, and every type name in [named]:
///
/// ```json
/// {
///   "scroll the feed": {"FeedTile": 12, "TabBar": 0, "_FeedHeader": 1}
/// }
/// ```
///
/// With [RebuildWindow.updateBaselines] on, the measured counts are written
/// under [key] instead and the matcher passes. A missing file, key or
/// budget fails, and so does a stored budget for an entry the test no
/// longer tracks. A tracked type that had no element in the window fails,
/// in update mode too, unless [allowAbsent] is set. A malformed file throws
/// a [FormatException].
///
/// Needs a file system: on the web it throws an [UnsupportedError].
Matcher matchesRebuildBaseline(
  String path, {
  required String key,
  List<Type> types = const [],
  List<String> named = const [],
  bool allowAbsent = false,
  int top = 10,
}) {
  final entries = <String, _Tracked>{};
  void track(String name, _Tracked tracked) {
    final existing = entries[name];
    if (existing != null) {
      if (existing.type != null && existing.type == tracked.type) {
        return;
      }
      throw ArgumentError(
        'Two tracked entries are named $name; a baseline file stores one '
        'budget per name. Track one of them by name in a separate baseline.',
      );
    }
    entries[name] = tracked;
  }

  for (final type in types) {
    track(typeLabel(type), _Tracked(type));
  }
  for (final name in named) {
    track(name, const _Tracked(null));
  }
  if (entries.isEmpty) {
    throw ArgumentError('matchesRebuildBaseline needs at least one entry in '
        'types or named.');
  }
  return _Baseline(path, key, entries, allowAbsent, top);
}

class _Tracked {
  const _Tracked(this.type);

  /// Null for an entry tracked by name.
  final Type? type;
}

const String _recordHint =
    'record it with flutter test --dart-define=UPDATE_REBUILD_BUDGETS=true';

class _Baseline extends WindowMatcher {
  const _Baseline(
      this.path, this.key, this.entries, this.allowAbsent, this.top);

  final String path;
  final String key;
  final Map<String, _Tracked> entries;
  final bool allowAbsent;
  final int top;

  @override
  String? judge(RebuildWindow window) {
    final file = locateBaselineFile(path);
    final problems = <String>[];
    final measured = <String, int>{};
    for (final MapEntry(key: name, value: tracked) in entries.entries) {
      final type = tracked.type;
      if (type != null) {
        final absent = allowAbsent ? null : absentTypeForBudget(window, type);
        if (absent != null) {
          problems.add(absent);
          continue;
        }
        measured[name] = window.countOf(type);
      } else {
        final absent = allowAbsent ? null : absentNameForBudget(window, name);
        final ambiguous = ambiguousName(window, name);
        if (absent != null || ambiguous != null) {
          problems.add((absent ?? ambiguous)!);
          continue;
        }
        measured[name] = window.countNamed(name);
      }
    }

    final stored = _read(file);
    if (RebuildWindow.updateBaselines) {
      if (problems.isNotEmpty) {
        return 'cannot record the rebuild baseline "$key":'
            '${_bullets(problems)}\nnothing was written to $file.';
      }
      final all = stored ?? <String, Map<String, int>>{};
      all[key] = measured;
      writeBaselineFile(file, _encode(all));
      return null;
    }

    if (stored == null) {
      return '$file does not exist; $_recordHint.';
    }
    final budgets = stored[key];
    if (budgets == null) {
      return '$file has no entry "$key"; $_recordHint.';
    }
    for (final MapEntry(key: name, value: count) in measured.entries) {
      final budget = budgets[name];
      if (RebuildWindow.printCounts && budget != null) {
        final where = window.label == null ? '' : ' in "${window.label}"';
        // ignore: avoid_print
        print(measurementLine('$name rebuilt$where', count, budget));
      }
      if (budget == null) {
        problems.add('$name is tracked but has no budget in $file; '
            '$_recordHint.');
      } else if (count > budget) {
        problems.add('$name rebuilt ${times(count)}, budget $budget '
            '(over by ${count - budget})');
      }
    }
    for (final name in budgets.keys) {
      if (!entries.containsKey(name)) {
        problems.add('$file stores a budget for $name, which this test no '
            'longer tracks. Remove it, or record the baseline again.');
      }
    }
    if (problems.isEmpty) {
      return null;
    }
    final table = formatTypeTable(
      window.rebuilds,
      top: top,
      budgets: {
        for (final name in entries.keys)
          if (budgets[name] != null) name: budgets[name]!,
      },
    );
    return 'does not match the rebuild baseline "$key" in $file:'
        '${_bullets(problems)}\n$table';
  }

  static String _bullets(List<String> lines) =>
      lines.map((line) => '\n  - $line').join();

  /// The parsed file, or null when it does not exist.
  static Map<String, Map<String, int>>? _read(String file) {
    final text = readBaselineFile(file);
    if (text == null) {
      return null;
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('$file must hold a JSON object.', text);
    }
    final result = <String, Map<String, int>>{};
    for (final MapEntry(key: entryKey, value: budgets) in decoded.entries) {
      if (budgets is! Map<String, Object?>) {
        throw FormatException(
          'Entry "$entryKey" in $file must be an object of budgets.',
          text,
        );
      }
      final parsed = <String, int>{};
      for (final MapEntry(key: name, value: budget) in budgets.entries) {
        if (budget is! int || budget < 0) {
          throw FormatException(
            'The budget for $name in entry "$entryKey" of $file must be a '
            'whole number of zero or more, not $budget.',
            text,
          );
        }
        parsed[name] = budget;
      }
      result[entryKey] = parsed;
    }
    return result;
  }

  static String _encode(Map<String, Map<String, int>> all) {
    final sorted = {
      for (final entryKey in all.keys.toList()..sort())
        entryKey: {
          for (final name in all[entryKey]!.keys.toList()..sort())
            name: all[entryKey]![name],
        },
    };
    return '${const JsonEncoder.withIndent('  ').convert(sorted)}\n';
  }

  @override
  Description describe(Description description) =>
      description.add('matches the rebuild baseline "$key" in $path');
}
