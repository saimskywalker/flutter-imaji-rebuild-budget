import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
import 'package:imaji_rebuild_budget_example/set_state/sortable_results.dart';
import 'package:imaji_rebuild_budget_example/set_state/ticking_shop.dart';

Widget _host(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

/// Lets the clock tick three times, one frame per tick.
Future<RebuildCounter> _threeTicks(WidgetTester tester) async {
  final window = RebuildCounter.open(label: 'three clock ticks');
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  window.close();
  return window;
}

void main() {
  group('a clock ticking with setState', () {
    testWidgets('BEFORE: at the screen root, rebuilds every product tile',
        (tester) async {
      await tester.pumpWidget(_host(const TickingShopSlow()));

      final window = await _threeTicks(tester);

      expect(window, interactionHappened(rebuilt: ClockText));
      // Caught: 3 ticks x 5 tiles. `rebuiltAtMost(0, of: ProductTile)` fails
      // here and lists ProductTile among the busiest types.
      expect(window, isNot(rebuiltAtMost(0, of: ProductTile)));
      expect(window.countOf(ProductTile), 15);
    });

    testWidgets('AFTER: in its own widget, rebuilds the clock alone',
        (tester) async {
      await tester.pumpWidget(_host(const TickingShopFast()));

      final window = await _threeTicks(tester);

      expect(window, interactionHappened(rebuilt: ClockText));
      expect(window, rebuiltAtMost(0, of: ProductTile));
      expect(window, rebuiltAtMost(0, of: ProductList));
      // Measured with --dart-define=REBUILD_COUNTS=true: per tick, the
      // clock, its ClockText and that label's Text.
      expect(window, subtreeRebuiltAtMost(9, under: find.byType(LiveClock)));
    });
  });

  group('re-sorting a keyed list', () {
    Future<RebuildCounter> reverse(WidgetTester tester, bool stable) async {
      await tester.pumpWidget(_host(SortableResults(stableKeys: stable)));
      final window = RebuildCounter.open(label: 'reverse the results');
      tester
          .state<SortableResultsState>(find.byType(SortableResults))
          .reverse();
      await tester.pump();
      window.close();
      return window;
    }

    testWidgets('BEFORE: UniqueKey in build remounts every row',
        (tester) async {
      final window = await reverse(tester, false);

      expect(window, interactionHappened(rebuilt: SortableResults));
      // Caught: ten new States, ten initState calls, for a re-sort.
      expect(window, isNot(mountedAtMost(0, of: ResultTile)));
      expect(window.mountsOf(ResultTile), 10);
    });

    testWidgets('AFTER: a ValueKey per result moves the rows instead',
        (tester) async {
      final window = await reverse(tester, true);

      expect(window, interactionHappened(rebuilt: SortableResults));
      expect(window, mountedAtMost(0, of: ResultTile));
    });
  });
}
