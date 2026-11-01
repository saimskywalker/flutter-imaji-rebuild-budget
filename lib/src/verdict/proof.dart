import 'package:flutter_test/flutter_test.dart';

import '../tally/build_record.dart';
import '../tally/rebuild_window.dart';
import '../tally/tree_survey.dart';
import 'presence.dart';
import 'window_matcher.dart';

/// Matches a closed [RebuildWindow] whose interaction provably ran.
///
/// Every given condition must hold:
///
/// * [scrollOffsetMoved]: the scrollable at, inside or around what this
///   finds was on screen when the window opened and closed, and its offset
///   changed.
/// * [fetchCount]: the window's `fetchCount` counter changed by this amount
///   (an `int`) or by an amount this matcher accepts.
/// * [counters]: each named counter changed by its value or matcher.
/// * [rebuilt]: a widget of exactly this type rebuilt at least once.
///
/// Pair every budget with one, so that a zero means something: a drag that
/// missed or a timer that never fired also rebuilds nothing.
Matcher interactionHappened({
  Finder? scrollOffsetMoved,
  Object? fetchCount,
  Map<String, Object?> counters = const {},
  Type? rebuilt,
}) {
  if (scrollOffsetMoved == null &&
      fetchCount == null &&
      counters.isEmpty &&
      rebuilt == null) {
    throw ArgumentError('interactionHappened needs at least one condition.');
  }
  if (fetchCount != null && counters.containsKey(fetchCountName)) {
    throw ArgumentError(
      'Pass fetchCount either as fetchCount: or in counters:, not both.',
    );
  }
  return _Proof(
      scrollOffsetMoved,
      {
        if (fetchCount != null) fetchCountName: wrapMatcher(fetchCount),
        for (final entry in counters.entries)
          entry.key: wrapMatcher(entry.value),
      },
      rebuilt);
}

class _Proof extends WindowMatcher {
  const _Proof(this.scroll, this.counters, this.rebuilt);

  final Finder? scroll;
  final Map<String, Matcher> counters;
  final Type? rebuilt;

  static String _label(String counter) =>
      counter == fetchCountName ? fetchCountName : 'counter "$counter"';

  static String _expected(Matcher matcher) =>
      StringDescription().addDescriptionOf(matcher).toString();

  @override
  String? judge(RebuildWindow window) {
    final problems = <String>[];

    final scroll = this.scroll;
    if (scroll != null) {
      final target = scrollableFor(scroll);
      final what = 'the ${scroll.describeMatch(Plurality.one)}';
      if (!target.found) {
        problems.add('scrollOffsetMoved: found no '
            '${scroll.describeMatch(Plurality.many)}');
      } else if (target.scrollable == null) {
        problems.add('scrollOffsetMoved: there is no Scrollable at, in or '
            'around $what');
      } else {
        final moved = scrollMovement(window, target.scrollable!);
        if (moved == null) {
          problems.add('scrollOffsetMoved: the Scrollable of $what must be '
              'on screen both when the window opened and when it closed');
        } else if (moved == 0) {
          problems.add('scrollOffsetMoved: the scroll offset of $what did '
              'not change');
        }
      }
    }

    final known = window.counterNames.toSet();
    for (final entry in counters.entries) {
      final name = entry.key;
      if (!known.contains(name)) {
        problems.add(name == fetchCountName
            ? 'fetchCount: the window was opened without a fetchCount '
                'callback'
            : 'counters: the window was opened without a counter named '
                '"$name"');
        continue;
      }
      final delta = window.counterDelta(name);
      if (!entry.value.matches(delta, {})) {
        problems.add('${_label(name)} changed by $delta, expected '
            '${_expected(entry.value)}');
      }
    }

    final rebuilt = this.rebuilt;
    if (rebuilt != null) {
      final absent = absentTypeForProof(window, rebuilt);
      if (absent != null) {
        problems.add('rebuilt: $absent');
      } else if (window.countOf(rebuilt) == 0) {
        problems.add('rebuilt: ${typeLabel(rebuilt)} never rebuilt during '
            '${windowPhrase(window)}');
      }
    }

    if (problems.isEmpty) {
      return null;
    }
    return 'gives no proof the interaction ran:'
        '${problems.map((p) => '\n  - $p').join()}';
  }

  @override
  Description describe(Description description) {
    final scroll = this.scroll;
    final rebuilt = this.rebuilt;
    final parts = [
      if (scroll != null)
        'the scroll offset of the ${scroll.describeMatch(Plurality.one)} '
            'changed',
      for (final entry in counters.entries)
        '${_label(entry.key)} changed by ${_expected(entry.value)}',
      if (rebuilt != null) '${typeLabel(rebuilt)} rebuilt at least once',
    ];
    return description.add('proof the interaction ran: ${parts.join(', ')}');
  }
}
