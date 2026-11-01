import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebuildcop/rebuildcop.dart';

import 'support/fixtures.dart';
import 'support/tile_a.dart' as a;
import 'support/tile_b.dart' as b;

Future<RebuildWindow> bumpOnce(WidgetTester tester, {String? label}) async {
  final screen = await showScreen(tester);
  final window = RebuildWindow.open(label: label);
  screen.bump();
  await tester.pump();
  window.close();
  return window;
}

void main() {
  group('a budget for a type that never appeared', () {
    testWidgets('fails, naming the type and the window', (tester) async {
      // ListRow is a real widget, but not on the Screen.
      final window = await bumpOnce(tester, label: 'bump');

      final message = mismatchOf(rebuiltAtMost(0, of: ListRow), window);

      expect(
        message,
        'no ListRow element existed during window "bump", so this budget '
        'could never fail. If it was renamed or replaced, budget the new '
        'type. To assert that it never appears, use findsNothing; to keep '
        'this budget anyway, pass allowAbsent: true.',
      );
      expect(
        rebuiltAtMost(0, of: ListRow).describe(StringDescription()).toString(),
        'ListRow rebuilt at most 0 times in the window',
      );
    });

    testWidgets('fails for every type budget', (tester) async {
      final window = await bumpOnce(tester);
      const absent = 'no ListRow element existed during the rebuild window';

      expect(mismatchOf(mountedAtMost(0, of: ListRow), window),
          startsWith(absent));
      expect(
        mismatchOf(
          subtreeRebuiltAtMost(0, under: find.byType(Panel), of: ListRow),
          window,
        ),
        startsWith(absent),
      );
      expect(
        mismatchOf(rebuiltAtMost(0, named: '_Gone'), window),
        startsWith('no widget type named _Gone existed during the rebuild '
            'window, so this budget could never fail.'),
      );
    });

    testWidgets('passes with allowAbsent', (tester) async {
      final window = await bumpOnce(tester);

      expect(window, rebuiltAtMost(0, of: ListRow, allowAbsent: true));
      expect(window, rebuiltAtMost(0, named: '_Gone', allowAbsent: true));
      expect(window, mountedAtMost(0, of: ListRow, allowAbsent: true));
      expect(
        window,
        subtreeRebuiltAtMost(
          0,
          under: find.byType(Panel),
          of: ListRow,
          allowAbsent: true,
        ),
      );
    });

    testWidgets('allowAbsent still fails a type that is over its budget',
        (tester) async {
      final window = await bumpOnce(tester);

      expect(
        mismatchOf(rebuiltAtMost(1, of: CountLabel, allowAbsent: true), window),
        startsWith('rebuilt 2 times, 1 over budget.'),
      );
    });

    testWidgets('interactionHappened says the type was never there',
        (tester) async {
      final window = await bumpOnce(tester);

      expect(
        mismatchOf(interactionHappened(rebuilt: ListRow), window),
        contains('rebuilt: no ListRow element existed during the rebuild '
            'window. Was it renamed or replaced?'),
      );
    });
  });

  group('a type that was present', () {
    testWidgets('passes at zero even when it never rebuilt', (tester) async {
      final window = await bumpOnce(tester);

      // Footer is const and SizedBox is a render-object widget: neither
      // rebuilt, but both were in the tree when the window opened.
      expect(window, rebuiltAtMost(0, of: Footer));
      expect(window, rebuiltAtMost(0, of: SizedBox));
      expect(window, mountedAtMost(0, of: Footer));
      expect(window, rebuiltAtMost(0, named: 'Footer'));
      expect(window.presentTypes, containsAll([Screen, Footer, SizedBox]));
      expect(window.presentTypes, isNot(contains(ListRow)));
    });

    testWidgets('is present when it appeared and left inside the window',
        (tester) async {
      await tester.pumpWidget(const SizedBox());

      final window = RebuildWindow.open();
      await pumpList(tester, count: 3);
      await tester.pumpWidget(const SizedBox());
      window.close();

      expect(find.byType(ListRow), findsNothing);
      expect(window, rebuiltAtMost(0, of: ListRow));
      expect(window.presentTypes, contains(ListRow));
    });
  });

  group('two types with the same name', () {
    testWidgets('budgeting the absent one says the other was present',
        (tester) async {
      final window = await tickTiles(tester, withB: true);

      const message = 'no Tile element existed during window "tick", so this '
          'budget could never fail. A different type with the same name, '
          'Tile, was present: the test and the app probably import it from '
          'different libraries (for example package:flutter/material.dart '
          'and package:material_ui/material_ui.dart).';
      expect(mismatchOf(rebuiltAtMost(0, of: a.Tile), window), message);
      expect(mismatchOf(mountedAtMost(0, of: a.Tile), window), message);
      expect(
        mismatchOf(interactionHappened(rebuilt: a.Tile), window),
        contains('rebuilt: no Tile element existed during window "tick". '
            'A different type with the same name'),
      );
      expect(window, rebuiltAtMost(1, of: b.Tile));
    });

    testWidgets('a budget by name fails when both rebuilt', (tester) async {
      final window = await tickTiles(tester, withA: true, withB: true);

      expect(
        mismatchOf(rebuiltAtMost(5, named: 'Tile'), window),
        '2 different types named Tile rebuilt during window "tick", so a '
        'budget by name would add them up. Budget each by type, or narrow '
        'the budget to one subtree.',
      );
      // By type, each is counted on its own.
      expect(window, rebuiltAtMost(1, of: a.Tile));
      expect(window, rebuiltAtMost(1, of: b.Tile));
    });

    testWidgets('a budget by name passes when only one is there',
        (tester) async {
      final window = await tickTiles(tester, withA: true);

      expect(window, rebuiltAtMost(1, named: 'Tile'));
    });
  });
}
