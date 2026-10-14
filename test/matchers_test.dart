import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';

import 'support/fixtures.dart';

Future<RebuildCounter> bumpOnce(WidgetTester tester, {String? label}) async {
  final screen = await pumpScreen(tester);
  final window = RebuildCounter.open(label: label);
  screen.bump();
  await tester.pump();
  window.close();
  return window;
}

void main() {
  group('rebuiltAtMost', () {
    testWidgets('passes at and under the budget', (tester) async {
      final window = await bumpOnce(tester);

      expect(window, rebuiltAtMost(2, of: CountLabel));
      expect(window, rebuiltAtMost(5, of: CountLabel));
      expect(window, rebuiltAtMost(0, of: Footer));
      expect(window, rebuiltAtMost(2, named: 'CountLabel'));
      expect(window, rebuiltAtMost(window.total));
    });

    testWidgets('fails over the budget and names the busiest types',
        (tester) async {
      final window = await bumpOnce(tester);

      final message = mismatchOf(rebuiltAtMost(1, of: CountLabel), window);

      expect(message, startsWith('rebuilt 2 times, 1 over budget.'));
      expect(message, contains('busiest first:'));
      expect(message, contains('2  CountLabel  budget 1, over by 1'));
      expect(message, contains('Screen'));
    });

    testWidgets('describes what it expected', (tester) async {
      expect(
        rebuiltAtMost(1, of: CountLabel)
            .describe(StringDescription())
            .toString(),
        'CountLabel rebuilt at most 1 time in the window',
      );
      expect(
        rebuiltAtMost(3).describe(StringDescription()).toString(),
        'all widgets rebuilt at most 3 times in the window',
      );
    });

    testWidgets('lists a budgeted type even when it is not among the busiest',
        (tester) async {
      final window = await bumpOnce(tester);

      final message =
          mismatchOf(rebuiltAtMost(0, of: Ornament, top: 1), window);

      expect(message, contains('1  Ornament    budget 0, over by 1'));
      expect(message, contains('more types'));
    });

    testWidgets('refuses an open window', (tester) async {
      final window = RebuildCounter.open();
      final message = mismatchOf(rebuiltAtMost(100), window);
      window.close();

      expect(message, contains('still open'));
    });

    test('refuses something that is not a window', () {
      expect(mismatchOf(rebuiltAtMost(1), 42), 'is not a RebuildCounter');
    });

    test('rejects a negative budget and conflicting selectors', () {
      expect(() => rebuiltAtMost(-1), throwsArgumentError);
      expect(
        () => rebuiltAtMost(1, of: Footer, named: 'Footer'),
        throwsArgumentError,
      );
    });

    testWidgets('prints the measurement in print mode', (tester) async {
      final window = await bumpOnce(tester, label: 'bump');
      RebuildCounter.printCounts = true;
      addTearDown(() => RebuildCounter.printCounts = false);

      final printed = <String>[];
      runZoned(
        () => expect(window, rebuiltAtMost(9, of: CountLabel)),
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => printed.add(line),
        ),
      );

      expect(printed, [
        '[rebuild counts] CountLabel rebuilt in "bump": measured 2, budget 9',
      ]);
    });
  });

  group('subtreeRebuiltAtMost', () {
    testWidgets('counts the root and everything below it', (tester) async {
      final window = await bumpOnce(tester);

      expect(window, subtreeRebuiltAtMost(3, under: find.byType(Panel)));
      expect(
        mismatchOf(subtreeRebuiltAtMost(2, under: find.byType(Panel)), window),
        startsWith('rebuilt 3 times, 1 over budget.\n3 rebuilds across'),
      );
    });

    testWidgets('narrows to one type inside the subtree', (tester) async {
      final window = await bumpOnce(tester);

      // Two CountLabels rebuilt on screen, only one of them in the Panel.
      expect(
        window,
        subtreeRebuiltAtMost(1, under: find.byType(Panel), of: CountLabel),
      );
    });

    testWidgets('catches a busy inside under a quiet root', (tester) async {
      final notifier = ValueNotifier(0);
      addTearDown(notifier.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Panel(
            child: ValueListenableBuilder<int>(
              valueListenable: notifier,
              builder: (_, value, __) => CountLabel(value),
            ),
          ),
        ),
      );

      final window = RebuildCounter.open();
      notifier.value++;
      await tester.pump();
      window.close();

      expect(window, rebuiltAtMost(0, of: Panel));
      expect(
        mismatchOf(subtreeRebuiltAtMost(0, under: find.byType(Panel)), window),
        contains('CountLabel'),
      );
    });

    testWidgets('fails, never passes, when the finder finds nothing',
        (tester) async {
      final window = await bumpOnce(tester);

      final message = mismatchOf(
        subtreeRebuiltAtMost(100, under: find.byKey(const ValueKey('gone'))),
        window,
      );

      expect(message, contains('no subtree to count'));
    });
  });

  group('mountedAtMost', () {
    testWidgets('catches a UniqueKey that remounts on every build',
        (tester) async {
      final notifier = ValueNotifier(0);
      addTearDown(notifier.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<int>(
            valueListenable: notifier,
            builder: (_, value, __) => Column(
              children: [
                CountLabel(value, key: UniqueKey()),
                Ornament(key: const ValueKey('stable')),
              ],
            ),
          ),
        ),
      );

      final window = RebuildCounter.open();
      notifier.value++;
      await tester.pump();
      window.close();

      expect(window, mountedAtMost(0, of: Ornament));
      final message = mismatchOf(mountedAtMost(0, of: CountLabel), window);
      expect(message, startsWith('mounted 1 time, 1 over budget.'));
      expect(message, contains('mounts across'));
    });
  });
}
