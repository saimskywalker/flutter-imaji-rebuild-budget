/// Rebuild budgets for Flutter widget tests.
///
/// Open a [RebuildCounter] window around an interaction, close it, and
/// assert that a widget type or a whole subtree rebuilt no more than a
/// measured budget:
///
/// ```dart
/// final window = RebuildCounter.open();
/// await tester.tap(find.byIcon(Icons.add));
/// await tester.pump();
/// window.close();
///
/// expect(window, interactionHappened(rebuilt: CounterText));
/// expect(window, rebuiltAtMost(0, of: ProductList));
/// ```
///
/// It listens to Flutter's own [debugOnRebuildDirtyWidget] hook, so it runs
/// headless in plain `flutter test` and the code under test carries no
/// probes.
library;

import 'package:flutter/widgets.dart' show debugOnRebuildDirtyWidget;

import 'src/rebuild_counter.dart';

export 'src/baseline.dart' show matchesRebuildBaseline;
export 'src/interaction.dart' show interactionHappened;
export 'src/matchers.dart'
    show mountedAtMost, rebuiltAtMost, subtreeRebuiltAtMost;
export 'src/rebuild_counter.dart' show RebuildCounter, RebuildRecord;
