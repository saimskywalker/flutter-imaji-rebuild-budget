import 'package:flutter_test/flutter_test.dart';

import 'baseline_store.dart';
import 'matchers.dart' show defaultTopTypes;
import 'rebuild_counter.dart';
import 'report.dart';

/// Matches a closed [RebuildCounter] against budgets stored in a JSON file,
/// the way `matchesGoldenFile` matches pixels.
///
/// [path] is resolved against the directory of the test file, like a golden
/// file. The file maps each [key] to the budget of every tracked widget
/// type:
///
/// ```json
/// {
///   "scroll the feed": {
///     "FeedTile": 12,
///     "TabBar": 0
///   }
/// }
/// ```
///
/// [types] and [named] list the widget types this window tracks (`named`
/// is for private types such as `'_Header'`). Each must have rebuilt no more
/// than its stored budget. A type that is tracked but missing from the
/// file, or stored but no longer tracked, is a failure too, so the file
/// always describes exactly what the test checks.
///
/// A tracked type that had no element anywhere in the window fails, in
/// update mode as well, because its budget could never fail (see
/// `rebuiltAtMost`); pass [allowAbsent] when one may legitimately be
/// missing. So does a [named] entry that two different types rebuilt under.
/// The file keys each type by its name, so two tracked entries with the
/// same name are rejected.
///
/// Run once with `--dart-define=UPDATE_REBUILD_BUDGETS=true` to write the
/// measured counts as the budgets. Commit the file; from then on a raised
/// budget shows up as a reviewed diff instead of a silently edited number.
///
/// Keep one baseline file per test file: test files run in parallel, and
/// two of them rewriting one file in update mode would race.
Matcher matchesRebuildBaseline(
  String path, {
  required String key,
  List<Type> types = const [],
  List<String> named = const [],
  bool allowAbsent = false,
  int top = defaultTopTypes,
}) {
  // Each tracked name, with its exact type when it came from `types`.
  final byName = <String, Type?>{};
  void track(String name, Type? type) {
    if (byName.containsKey(name) && byName[name] != type) {
      throw ArgumentError(
        'matchesRebuildBaseline tracks two widget types named $name; the '
        'baseline file keys budgets by name, so it cannot tell them apart.',
      );
    }
    byName[name] = type;
  }

  for (final type in types) {
    track('$type', type);
  }
  for (final name in named) {
    track(name, null);
  }
  if (byName.isEmpty) {
    throw ArgumentError(
      'matchesRebuildBaseline needs at least one widget type in `types` or '
      '`named`. Track the few types that matter, not the whole tree.',
    );
  }
  final tracked = byName.keys.toList()..sort();
  return _BaselineMatcher(path, key, tracked, byName, allowAbsent, top);
}

class _BaselineMatcher extends Matcher {
  const _BaselineMatcher(
    this.path,
    this.key,
    this.tracked,
    this.types,
    this.allowAbsent,
    this.top,
  );

  final String path;
  final String key;
  final List<String> tracked;
  final Map<String, Type?> types;
  final bool allowAbsent;
  final int top;

  static const String _problemsKey = 'problems';
  static const String _tableKey = 'table';

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final problems = <String>[];
    matchState[_problemsKey] = problems;
    if (item is! RebuildCounter) {
      problems.add('is not a RebuildCounter');
      return false;
    }
    if (item.isOpen) {
      problems.add('is still open; call close() before asserting');
      return false;
    }

    final measured = <String, int>{};
    for (final name in tracked) {
      final type = types[name];
      bool counts(RebuildRecord r) =>
          type != null ? r.widgetType == type : r.typeName == name;
      final counted = item.rebuilds.where(counts).toList();
      measured[name] = counted.length;
      final problem = typeBudgetProblem(
        item,
        type: type,
        named: type == null ? name : null,
        counted: counted,
        allowAbsent: allowAbsent,
      );
      if (problem != null) problems.add(problem);
    }
    final resolved = resolveBaselinePath(path);
    if (problems.isNotEmpty) {
      if (RebuildCounter.updateBaselines) {
        problems.add('nothing was written to $resolved');
      }
      return false;
    }

    if (RebuildCounter.updateBaselines) {
      final baseline = readBaseline(resolved) ?? {};
      baseline[key] = measured;
      writeBaseline(resolved, baseline);
      if (RebuildCounter.printCounts) {
        // ignore: avoid_print
        print('[rebuild counts] wrote "$key" to $resolved: $measured');
      }
      return true;
    }

    const hint = 'record it with --dart-define=UPDATE_REBUILD_BUDGETS=true';
    final baseline = readBaseline(resolved);
    if (baseline == null) {
      problems.add('baseline file $resolved does not exist; $hint');
      return false;
    }
    final budgets = baseline[key];
    if (budgets == null) {
      problems.add('baseline file $resolved has no entry "$key"; $hint');
      return false;
    }

    for (final type in tracked) {
      final budget = budgets[type];
      final count = measured[type]!;
      if (RebuildCounter.printCounts && budget != null) {
        // ignore: avoid_print
        print(printMeasurement('$type in "$key"', count, budget));
      }
      if (budget == null) {
        problems.add('$type is tracked but has no budget in "$key"; $hint');
      } else if (count > budget) {
        problems.add('$type rebuilt $count times, budget $budget '
            '(over by ${count - budget})');
      }
    }
    for (final type in budgets.keys) {
      if (!tracked.contains(type)) {
        problems.add('"$key" stores a budget for $type, which this test no '
            'longer tracks; $hint');
      }
    }
    if (problems.isNotEmpty) {
      matchState[_tableKey] = busiestTable(
        item.rebuilds,
        top: top,
        budgets: {
          for (final type in tracked)
            if (budgets[type] != null) type: budgets[type]!,
        },
      );
    }
    return problems.isEmpty;
  }

  @override
  Description describe(Description description) => description.add(
        'rebuilds of ${tracked.join(', ')} within the budgets stored under '
        '"$key" in $path',
      );

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    final problems = matchState[_problemsKey] as List<String>;
    final table = matchState[_tableKey] as String?;
    mismatchDescription.add(problems.map((p) => '- $p').join('\n'));
    if (table != null) mismatchDescription.add('\n$table');
    return mismatchDescription;
  }
}
