import 'package:flutter_test/flutter_test.dart';

import '../tally/rebuild_window.dart';

/// A matcher over a closed [RebuildWindow].
///
/// Subclasses implement [judge], which returns the mismatch text or null
/// when the window passes.
abstract class WindowMatcher extends Matcher {
  /// Const constructor for subclasses.
  const WindowMatcher();

  static const Object _key = #rebuildcopMismatch;

  /// The mismatch for [window], or null when it passes.
  String? judge(RebuildWindow window);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final String? problem;
    if (item is! RebuildWindow) {
      problem = 'is not a RebuildWindow';
    } else if (item.isOpen) {
      problem = 'is ${windowPhrase(item)}, which is still open. Call close() '
          'before asserting, so frames pumped later cannot change the counts.';
    } else {
      problem = judge(item);
    }
    if (problem == null) {
      return true;
    }
    matchState[_key] = problem;
    return false;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    final problem = matchState[_key];
    return problem is String
        ? mismatchDescription.add(problem)
        : mismatchDescription;
  }
}
