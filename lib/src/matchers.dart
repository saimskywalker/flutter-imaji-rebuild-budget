import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rebuild_counter.dart';
import 'report.dart';

/// How many busy widget types a failure lists by default.
const int defaultTopTypes = 10;

/// Matches a closed [RebuildCounter] whose rebuilds stayed within [budget].
///
/// With [of], only widgets whose runtime type is exactly that type count.
/// With [named], only widgets whose runtime type has that name count, for a
/// type that is private to the code under test. With neither, every rebuild
/// in the window counts.
///
/// A failure lists the [top] busiest widget types in the window with the
/// budget beside the one that was checked.
///
/// ```dart
/// expect(window, rebuiltAtMost(0, of: NavigationBar));
/// expect(window, rebuiltAtMost(3, named: '_Header'));
/// ```
///
/// The budget should be the count measured when the test was written
/// (see [RebuildCounter.printCounts]). Raising it is a decision to accept
/// more rebuilds, not a way to make a red test green.
Matcher rebuiltAtMost(
  int budget, {
  Type? of,
  String? named,
  int top = defaultTopTypes,
}) {
  _checkBudget(budget);
  if (of != null && named != null) {
    throw ArgumentError('Pass either `of` or `named`, not both.');
  }
  return _BudgetMatcher(
    budget: budget,
    top: top,
    subject: of != null ? '$of' : named ?? 'all widgets',
    budgetKey: of != null ? '$of' : named,
    select: (record) => of != null
        ? record.widgetType == of
        : named == null || record.typeName == named,
    pool: (window) => window.rebuilds,
  );
}

/// Matches a closed [RebuildCounter] in which the subtree found by [under]
/// rebuilt at most [budget] times.
///
/// The subtree is the elements [under] finds plus every element below them.
/// It catches the busy inside of a widget whose own root never rebuilt, such
/// as a `ValueListenableBuilder` or a state-library consumer deep in a
/// screen. With [of], only widgets of exactly that type inside the subtree
/// count, for a type that also appears elsewhere on screen.
///
/// [under] is evaluated when the matcher runs, against the current tree, so
/// assert before the subtree is torn down. A finder that matches nothing is
/// a failure, never a pass, because a subtree that is not there cannot
/// rebuild. Pass `skipOffstage: false` to the finder for an offstage
/// subtree.
///
/// ```dart
/// expect(window, subtreeRebuiltAtMost(0, under: find.byType(BottomNavigationBar)));
/// ```
Matcher subtreeRebuiltAtMost(
  int budget, {
  required Finder under,
  Type? of,
  int top = defaultTopTypes,
}) {
  _checkBudget(budget);
  return _BudgetMatcher(
    budget: budget,
    top: top,
    subject: of == null
        ? 'the subtree under the ${under.describeMatch(Plurality.one)}'
        : '$of under the ${under.describeMatch(Plurality.one)}',
    budgetKey: of == null ? null : '$of',
    under: under,
    select: (record) => of == null || record.widgetType == of,
    pool: (window) => window.rebuilds,
  );
}

/// Matches a closed [RebuildCounter] in which at most [budget] new elements
/// were mounted, optionally only those of exactly type [of].
///
/// Mounts are not rebuilds: a new element means a new `State`, a fresh
/// `initState`, lost scroll positions and text selections. A widget that
/// gets a `UniqueKey()` in `build`, or a subtree whose type changes on
/// every frame, shows up here.
Matcher mountedAtMost(int budget, {Type? of, int top = defaultTopTypes}) {
  _checkBudget(budget);
  return _BudgetMatcher(
    budget: budget,
    top: top,
    subject: of == null ? 'new elements' : 'new $of elements',
    verb: 'mounted',
    budgetKey: of == null ? null : '$of',
    select: (record) => of == null || record.widgetType == of,
    pool: (window) => window.mounts,
  );
}

void _checkBudget(int budget) {
  if (budget < 0) {
    throw ArgumentError.value(budget, 'budget', 'must not be negative');
  }
}

class _BudgetMatcher extends Matcher {
  const _BudgetMatcher({
    required this.budget,
    required this.top,
    required this.subject,
    required this.select,
    required this.pool,
    this.budgetKey,
    this.under,
    this.verb = 'rebuilt',
  });

  final int budget;
  final int top;
  final String subject;
  final String verb;
  final String? budgetKey;
  final Finder? under;
  final bool Function(RebuildRecord record) select;
  final List<RebuildRecord> Function(RebuildCounter window) pool;

  static const String _countKey = 'count';
  static const String _problemKey = 'problem';
  static const String _scopeKey = 'scope';

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! RebuildCounter) {
      matchState[_problemKey] = 'is not a RebuildCounter';
      return false;
    }
    if (item.isOpen) {
      matchState[_problemKey] = 'is still open; call close() before '
          'asserting, so frames pumped later cannot change the count';
      return false;
    }
    var records = pool(item);
    if (under != null) {
      final Set<Element> roots;
      try {
        roots = resolveRoots(under!);
      } on StateError catch (error) {
        matchState[_problemKey] = error.message;
        return false;
      }
      records = records.where((r) => r.isWithin(roots)).toList();
    }
    final count = records.where(select).length;
    matchState[_countKey] = count;
    matchState[_scopeKey] = records;
    if (RebuildCounter.printCounts) {
      final window = item.label == null ? '' : ' in "${item.label}"';
      // ignore: avoid_print
      print(printMeasurement('$subject $verb$window', count, budget));
    }
    return count <= budget;
  }

  @override
  Description describe(Description description) => description.add(
        '$subject $verb at most $budget '
        '${budget == 1 ? 'time' : 'times'} in the window',
      );

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    final problem = matchState[_problemKey];
    if (problem != null) return mismatchDescription.add('$problem');
    final count = matchState[_countKey] as int;
    final scope = matchState[_scopeKey] as List<RebuildRecord>;
    final key = budgetKey;
    return mismatchDescription
        .add('$verb $count ${count == 1 ? 'time' : 'times'}, '
            '${count - budget} over budget.\n')
        .add(busiestTable(
          scope,
          top: top,
          budgets: key == null ? const {} : {key: budget},
          noun: verb == 'mounted' ? 'mounts' : 'rebuilds',
        ));
  }
}
