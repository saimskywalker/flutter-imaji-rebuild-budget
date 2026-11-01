import '../tally/build_record.dart';

/// The tag in front of every line print mode writes.
const String printTag = '[rebuildcop]';

/// `1 time`, `2 times`.
String times(int n) => n == 1 ? '1 time' : '$n times';

/// [noun] with an `s` unless [n] is 1.
String plural(int n, String noun) => n == 1 ? noun : '${noun}s';

/// Counts [records] per type name, busiest first, ties in name order.
List<MapEntry<String, int>> tallyByName(Iterable<BuildRecord> records) {
  final tally = <String, int>{};
  for (final record in records) {
    tally.update(record.typeName, (n) => n + 1, ifAbsent: () => 1);
  }
  return tally.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
}

/// A table of [records] per widget type, busiest first.
///
/// At most [top] types are listed, plus every type in [budgets] (keyed by
/// type name) that has records, each with its budget beside it. [noun]
/// names what a record is in the header (`rebuild` or `mount`).
String formatTypeTable(
  Iterable<BuildRecord> records, {
  int top = 10,
  Map<String, int> budgets = const {},
  String noun = 'rebuild',
}) {
  final rows = tallyByName(records);
  if (rows.isEmpty) {
    return 'no ${noun}s were recorded';
  }
  final total = rows.fold<int>(0, (sum, row) => sum + row.value);
  final shown = <MapEntry<String, int>>[];
  for (var i = 0; i < rows.length; i++) {
    if (i < top || budgets.containsKey(rows[i].key)) {
      shown.add(rows[i]);
    }
  }
  var countWidth = 0;
  var nameWidth = 0;
  for (final row in shown) {
    final digits = '${row.value}'.length;
    if (digits > countWidth) countWidth = digits;
    if (row.key.length > nameWidth) nameWidth = row.key.length;
  }

  final out = StringBuffer(
    '$total ${plural(total, noun)} across ${rows.length} '
    '${plural(rows.length, 'widget type')}, busiest first:',
  );
  for (final row in shown) {
    out.write('\n  ${'${row.value}'.padLeft(countWidth)}  ');
    final budget = budgets[row.key];
    if (budget == null) {
      out.write(row.key);
    } else {
      out.write('${row.key.padRight(nameWidth)}  budget $budget');
      if (row.value > budget) {
        out.write(', over by ${row.value - budget}');
      }
    }
  }
  final hidden = rows.length - shown.length;
  if (hidden > 0) {
    out.write('\n  ... and $hidden more ${plural(hidden, 'type')}');
  }
  return out.toString();
}

/// The print-mode line for one measurement against its budget.
String measurementLine(String subject, int measured, int budget) =>
    '$printTag $subject: measured $measured, budget $budget'
    '${measured > budget ? ' (OVER)' : ''}';
