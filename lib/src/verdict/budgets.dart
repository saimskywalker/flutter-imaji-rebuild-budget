import 'package:flutter_test/flutter_test.dart';

import '../output/type_table.dart';
import '../tally/build_record.dart';
import '../tally/rebuild_window.dart';
import 'presence.dart';
import 'window_matcher.dart';

/// Matches a closed [RebuildWindow] in which widgets rebuilt at most
/// [budget] times.
///
/// Counts widgets of exactly type [of], widgets whose type is called
/// [named] (for private types), or, with neither, every rebuild.
///
/// A budget for a type that had no element anywhere in the window fails,
/// because it could never fail; pass [allowAbsent] to keep it anyway. A
/// budget by [named] also fails when two different types with that name
/// rebuilt. [top] limits the busiest-types table in the failure.
Matcher rebuiltAtMost(
  int budget, {
  Type? of,
  String? named,
  bool allowAbsent = false,
  int top = 10,
}) {
  _checkBudget(budget);
  if (of != null && named != null) {
    throw ArgumentError('Pass at most one of `of` and `named`.');
  }
  return _RebuildBudget(budget, of, named, allowAbsent, top);
}

/// Matches a closed [RebuildWindow] in which at most [budget] elements of
/// exactly type [of] (or of any type, without [of]) were mounted.
///
/// A mount is an element built for the first time inside the window: a
/// `UniqueKey()` in `build`, or a subtree whose type flips, remounts and
/// loses its `State`.
Matcher mountedAtMost(
  int budget, {
  Type? of,
  bool allowAbsent = false,
  int top = 10,
}) {
  _checkBudget(budget);
  return _MountBudget(budget, of, allowAbsent, top);
}

/// Matches a closed [RebuildWindow] in which the subtree at every widget
/// [under] finds rebuilt at most [budget] times, counting only type [of]
/// when it is given.
///
/// A finder that finds nothing fails rather than passes.
Matcher subtreeRebuiltAtMost(
  int budget, {
  required Finder under,
  Type? of,
  bool allowAbsent = false,
  int top = 10,
}) {
  _checkBudget(budget);
  return _SubtreeBudget(budget, under, of, allowAbsent, top);
}

void _checkBudget(int budget) {
  if (budget < 0) {
    throw ArgumentError.value(budget, 'budget', 'must not be negative');
  }
}

/// `in "label"`, or `in the rebuild window` without a label.
String _where(RebuildWindow window) =>
    window.label == null ? 'in the rebuild window' : 'in "${window.label}"';

String _overrun(String verb, int measured, int budget) =>
    '$verb ${times(measured)}, ${measured - budget} over budget.\n';

class _RebuildBudget extends WindowMatcher {
  const _RebuildBudget(
    this.budget,
    this.type,
    this.name,
    this.allowAbsent,
    this.top,
  );

  final int budget;
  final Type? type;
  final String? name;
  final bool allowAbsent;
  final int top;

  String? get _subject => type != null ? typeLabel(type!) : name;

  @override
  String? judge(RebuildWindow window) {
    final type = this.type;
    final name = this.name;
    final int measured;
    if (type != null) {
      if (!allowAbsent) {
        final absent = absentTypeForBudget(window, type);
        if (absent != null) return absent;
      }
      measured = window.countOf(type);
    } else if (name != null) {
      if (!allowAbsent) {
        final absent = absentNameForBudget(window, name);
        if (absent != null) return absent;
      }
      final ambiguous = ambiguousName(window, name);
      if (ambiguous != null) return ambiguous;
      measured = window.countNamed(name);
    } else {
      measured = window.total;
    }

    if (RebuildWindow.printCounts) {
      // ignore: avoid_print
      print(measurementLine(
        '${_subject ?? 'all widgets'} rebuilt ${_where(window)}',
        measured,
        budget,
      ));
    }
    if (measured <= budget) {
      return null;
    }
    final subject = _subject;
    return _overrun('rebuilt', measured, budget) +
        formatTypeTable(
          window.rebuilds,
          top: top,
          budgets: {if (subject != null) subject: budget},
        );
  }

  @override
  Description describe(Description description) => description.add(
        '${_subject ?? 'all widgets'} rebuilt at most ${times(budget)} '
        'in the window',
      );
}

class _MountBudget extends WindowMatcher {
  const _MountBudget(this.budget, this.type, this.allowAbsent, this.top);

  final int budget;
  final Type? type;
  final bool allowAbsent;
  final int top;

  String get _subject => type == null ? 'all widgets' : typeLabel(type!);

  @override
  String? judge(RebuildWindow window) {
    final type = this.type;
    if (type != null && !allowAbsent) {
      final absent = absentTypeForBudget(window, type);
      if (absent != null) return absent;
    }
    final measured =
        type == null ? window.mounts.length : window.mountsOf(type);
    if (RebuildWindow.printCounts) {
      // ignore: avoid_print
      print(measurementLine(
        '$_subject mounted ${_where(window)}',
        measured,
        budget,
      ));
    }
    if (measured <= budget) {
      return null;
    }
    return _overrun('mounted', measured, budget) +
        formatTypeTable(
          window.mounts,
          top: top,
          noun: 'mount',
          budgets: {if (type != null) _subject: budget},
        );
  }

  @override
  Description describe(Description description) => description
      .add('$_subject mounted at most ${times(budget)} in the window');
}

class _SubtreeBudget extends WindowMatcher {
  const _SubtreeBudget(
    this.budget,
    this.under,
    this.type,
    this.allowAbsent,
    this.top,
  );

  final int budget;
  final Finder under;
  final Type? type;
  final bool allowAbsent;
  final int top;

  String get _root => under.describeMatch(Plurality.one);

  String get _subject => type == null
      ? 'the subtree of the $_root'
      : '${typeLabel(type!)} under the $_root';

  @override
  String? judge(RebuildWindow window) {
    final type = this.type;
    if (type != null && !allowAbsent) {
      final absent = absentTypeForBudget(window, type);
      if (absent != null) return absent;
    }
    final records = buildsUnder(window, under);
    if (records == null) {
      return 'found no ${under.describeMatch(Plurality.many)}, so there is '
          'no subtree to count. A budget on nothing could never fail.';
    }
    final measured = type == null
        ? records.length
        : records.where((r) => r.widgetType == type).length;
    if (RebuildWindow.printCounts) {
      // ignore: avoid_print
      print(measurementLine(
        '$_subject rebuilt ${_where(window)}',
        measured,
        budget,
      ));
    }
    if (measured <= budget) {
      return null;
    }
    return _overrun('rebuilt', measured, budget) +
        formatTypeTable(
          records,
          top: top,
          budgets: {if (type != null) typeLabel(type): budget},
        );
  }

  @override
  Description describe(Description description) =>
      description.add('$_subject rebuilt at most ${times(budget)} '
          'in the window');
}
