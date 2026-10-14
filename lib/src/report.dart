import 'rebuild_counter.dart';

/// Counts [records] by widget type name, busiest first, ties by name.
Map<String, int> groupByType(Iterable<RebuildRecord> records) {
  final counts = <String, int>{};
  for (final record in records) {
    counts.update(record.typeName, (n) => n + 1, ifAbsent: () => 1);
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return Map.fromEntries(entries);
}

/// Renders the busiest widget types in [records] as an aligned table.
///
/// The [top] busiest types are listed, followed by any type in [budgets]
/// that did not make the cut, so the type a budget was set on is always
/// visible. A budgeted row shows its budget and, when exceeded, by how much.
String busiestTable(
  List<RebuildRecord> records, {
  int top = 10,
  Map<String, int> budgets = const {},
  String noun = 'rebuilds',
}) {
  if (records.isEmpty) return 'no $noun were recorded';

  final counts = groupByType(records);
  final rows = <String>[
    ...counts.keys.take(top),
    for (final name in budgets.keys)
      if (!counts.keys.take(top).contains(name)) name,
  ];
  final countWidth = rows
      .map((name) => '${counts[name] ?? 0}'.length)
      .fold<int>(1, (a, b) => a > b ? a : b);
  final nameWidth =
      rows.map((name) => name.length).fold<int>(1, (a, b) => a > b ? a : b);

  final hidden = counts.length - rows.where(counts.containsKey).length;
  final buffer = StringBuffer(
    '${records.length} $noun across ${counts.length} widget '
    '${counts.length == 1 ? 'type' : 'types'}, busiest first:',
  );
  for (final name in rows) {
    final count = counts[name] ?? 0;
    final line = StringBuffer('\n  ${'$count'.padLeft(countWidth)}  ');
    final budget = budgets[name];
    if (budget == null) {
      line.write(name);
    } else {
      line
        ..write(name.padRight(nameWidth))
        ..write('  budget $budget');
      if (count > budget) line.write(', over by ${count - budget}');
    }
    buffer.write(line.toString().trimRight());
  }
  if (hidden > 0) {
    buffer.write('\n  ... and $hidden more '
        '${hidden == 1 ? 'type' : 'types'}');
  }
  return buffer.toString();
}

/// The print-mode summary of a closed [window].
String printReport(RebuildCounter window) {
  final name = window.label == null ? 'window' : 'window "${window.label}"';
  final counts = window.countsByType();
  final buffer = StringBuffer(
    '[rebuild counts] $name: ${window.total} rebuilds, '
    '${window.mounts.length} mounts',
  );
  final width = counts.values
      .map((n) => '$n'.length)
      .fold<int>(1, (a, b) => a > b ? a : b);
  counts.forEach((type, count) {
    buffer.write('\n  ${'$count'.padLeft(width)}  $type');
  });
  for (final counter in window.counterNames) {
    buffer.write('\n  counter $counter changed by '
        '${window.counterDelta(counter)}');
  }
  return buffer.toString();
}

/// The print-mode line for one budget check.
String printMeasurement(String what, int measured, int budget) =>
    '[rebuild counts] $what: measured $measured, budget $budget'
    '${measured > budget ? ' (OVER)' : ''}';
