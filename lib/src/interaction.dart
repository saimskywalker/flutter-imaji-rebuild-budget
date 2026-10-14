import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rebuild_counter.dart';

/// Matches a closed [RebuildCounter] whose interaction provably ran.
///
/// A budget of zero passes just as happily when the interaction did nothing
/// at all: a drag that missed its target, a timer that never fired, a fake
/// that was never called. Pair every budget with this matcher so a zero
/// means "nothing rebuilt" and not "nothing happened".
///
/// Every given condition must hold:
///
/// * [scrollOffsetMoved] finds a [Scrollable], a scroll view that builds one
///   (such as [ListView]), or a widget inside one, whose offset changed
///   between [RebuildCounter.open] and [RebuildCounter.close].
/// * [fetchCount] is compared with how much the window's `fetchCount`
///   callback changed. An `int` must match exactly; any [Matcher] (such as
///   `greaterThan(0)`) is applied as is.
/// * [counters] does the same for named counters given to
///   [RebuildCounter.open].
/// * [rebuilt] is a widget type that must have rebuilt at least once, for
///   showing that the screen reacted at all.
///
/// ```dart
/// final window = RebuildCounter.open(fetchCount: () => inbox.fetches);
/// for (var i = 0; i < 5; i++) {
///   await tester.pump(const Duration(seconds: 15));
/// }
/// window.close();
///
/// expect(window, interactionHappened(fetchCount: 5, rebuilt: UnreadBadge));
/// expect(window, rebuiltAtMost(0, of: NavigationBar));
/// ```
///
/// Throws an [ArgumentError] when no condition is given.
Matcher interactionHappened({
  Finder? scrollOffsetMoved,
  Object? fetchCount,
  Map<String, Object> counters = const {},
  Type? rebuilt,
}) {
  if (counters.containsKey(fetchCountName) && fetchCount != null) {
    throw ArgumentError(
      'Pass the fetch count either as `fetchCount` or in `counters`, '
      'not both.',
    );
  }
  final expectedCounters = <String, Matcher>{
    for (final entry in counters.entries) entry.key: wrapMatcher(entry.value),
    if (fetchCount != null) fetchCountName: wrapMatcher(fetchCount),
  };
  if (scrollOffsetMoved == null &&
      expectedCounters.isEmpty &&
      rebuilt == null) {
    throw ArgumentError(
      'interactionHappened needs at least one condition: scrollOffsetMoved, '
      'fetchCount, counters or rebuilt.',
    );
  }
  return _InteractionMatcher(scrollOffsetMoved, expectedCounters, rebuilt);
}

class _InteractionMatcher extends Matcher {
  const _InteractionMatcher(this.scroll, this.counters, this.rebuilt);

  final Finder? scroll;
  final Map<String, Matcher> counters;
  final Type? rebuilt;

  static const String _problemsKey = 'problems';

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

    final finder = scroll;
    if (finder != null) {
      final what = finder.describeMatch(Plurality.many);
      if (finder.evaluate().isEmpty) {
        problems.add('scrollOffsetMoved: found no $what');
      } else {
        final delta = item.scrollDelta(finder);
        if (delta == null) {
          problems.add('scrollOffsetMoved: no scrollable for $what was on '
              'screen both when the window opened and when it closed');
        } else if (delta.abs() < _minimumScroll) {
          problems.add('scrollOffsetMoved: the offset of $what did not '
              'change');
        }
      }
    }

    for (final entry in counters.entries) {
      final name = entry.key;
      if (!item.counterNames.contains(name)) {
        problems.add('$name: the window was opened without '
            '${name == fetchCountName ? 'a fetchCount callback' : 'a counter named "$name"'}');
        continue;
      }
      final delta = item.counterDelta(name);
      final state = <dynamic, dynamic>{};
      if (!entry.value.matches(delta, state)) {
        final expected = entry.value.describe(StringDescription());
        problems.add('$name changed by $delta, expected $expected');
      }
    }

    final type = rebuilt;
    if (type != null && item.countOf(type) == 0) {
      problems.add('rebuilt: $type never rebuilt in the window');
    }
    return problems.isEmpty;
  }

  @override
  Description describe(Description description) {
    final parts = <String>[
      if (scroll != null)
        'the scroll offset of ${scroll!.describeMatch(Plurality.one)} moved',
      for (final entry in counters.entries)
        '${entry.key} changed by '
            '${entry.value.describe(StringDescription())}',
      if (rebuilt != null) '$rebuilt rebuilt at least once',
    ];
    return description.add('an interaction where ${parts.join(', and ')}');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    final problems = matchState[_problemsKey] as List<String>;
    return mismatchDescription.add(
      'gives no proof the interaction ran:\n'
      '${problems.map((p) => '  - $p').join('\n')}',
    );
  }
}

/// The smallest offset change, in logical pixels, that counts as a scroll.
const double _minimumScroll = 1e-6;
