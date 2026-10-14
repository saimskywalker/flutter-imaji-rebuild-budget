import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
import 'package:imaji_rebuild_budget/src/rebuild_counter.dart'
    show closeLeftOpenWindow;

import 'support/fixtures.dart';

void main() {
  group('counting', () {
    testWidgets('counts rebuilds of widgets that already existed',
        (tester) async {
      final screen = await pumpScreen(tester);

      final window = RebuildCounter.open();
      screen.bump();
      await tester.pump();
      window.close();

      expect(window.countOf(Screen), 1);
      // Two CountLabels: one direct, one inside the Panel.
      expect(window.countOf(CountLabel), 2);
      // Rebuilt only because its parent built a new instance of it.
      expect(window.countOf(Ornament), 1);
      // A const widget is the same instance, so Flutter skips it.
      expect(window.countOf(Footer), 0);
      expect(window.mounts, isEmpty);
    });

    testWidgets('ignores everything before open and after close',
        (tester) async {
      final screen = await pumpScreen(tester);
      screen.bump();
      await tester.pump();

      final window = RebuildCounter.open();
      window.close();
      screen.bump();
      await tester.pump();

      expect(window.total, 0);
    });

    testWidgets('counts every frame in the window', (tester) async {
      final screen = await pumpScreen(tester);

      final window = RebuildCounter.open();
      for (var i = 0; i < 3; i++) {
        screen.bump();
        await tester.pump();
      }
      window.close();

      expect(window.countOf(Screen), 3);
      expect(window.total, window.rebuilds.length);
    });

    testWidgets('tells mounts apart from rebuilds', (tester) async {
      await pumpList(tester);

      final window = RebuildCounter.open();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      window.close();

      expect(window.mountsOf(ListRow), greaterThan(0));
      expect(window.countOf(ListRow), 0);
      expect(window.mounts.every((r) => r.isMount), isTrue);
      expect(window.rebuilds.every((r) => !r.isMount), isTrue);
    });

    testWidgets(
        'a widget mounted inside the window then rebuilt counts once '
        'as each', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final window = RebuildCounter.open();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Screen(),
        ),
      );
      tester.state<ScreenState>(find.byType(Screen)).bump();
      await tester.pump();
      window.close();

      expect(window.mountsOf(Screen), 1);
      expect(window.countOf(Screen), 1);
    });

    testWidgets('matches by name and by predicate', (tester) async {
      final screen = await pumpScreen(tester);

      final window = RebuildCounter.open();
      screen.bump();
      await tester.pump();
      window.close();

      expect(window.countNamed('CountLabel'), 2);
      expect(window.countWhere((w) => w is CountLabel && w.count == 1), 2);
      expect(window.countNamed('NoSuchWidget'), 0);
    });

    testWidgets('counts a subtree by finder', (tester) async {
      final screen = await pumpScreen(tester);

      final window = RebuildCounter.open();
      screen.bump();
      await tester.pump();
      window.close();

      // The Panel, the CountLabel inside it and that label's Text.
      expect(window.countUnder(find.byType(Panel)), 3);
      expect(window.countUnder(find.byType(Panel), of: CountLabel), 1);
      expect(
        () => window.countUnder(find.byKey(const ValueKey('missing'))),
        throwsStateError,
      );
    });

    testWidgets('groups counts by type, busiest first, ties by name',
        (tester) async {
      final screen = await pumpScreen(tester);

      final window = RebuildCounter.open();
      screen.bump();
      await tester.pump();
      window.close();

      final counts = window.countsByType();
      expect(counts.keys.first, 'CountLabel');
      expect(counts['CountLabel'], 2);
      final ones =
          counts.entries.where((e) => e.value == 1).map((e) => e.key).toList();
      expect(ones, [...ones]..sort());
    });

    testWidgets('records the ancestry of each rebuild', (tester) async {
      final screen = await pumpScreen(tester);

      final window = RebuildCounter.open();
      screen.bump();
      await tester.pump();
      window.close();

      final nested = window.rebuilds.singleWhere(
        (r) =>
            r.widget is CountLabel &&
            r.ancestors.any(
              (a) => a.widget is Panel,
            ),
      );
      expect(nested.typeName, 'CountLabel');
      expect(nested.widgetType, CountLabel);
      expect(nested.ancestors.first.widget, isA<Padding>());
    });
  });

  group('the window', () {
    testWidgets('cannot be closed twice', (tester) async {
      final window = RebuildCounter.open(label: 'twice');
      window.close();
      expect(
        window.close,
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('window "twice" was already closed'),
        )),
      );
    });

    testWidgets('describes itself', (tester) async {
      final window = RebuildCounter.open(label: 'tap');
      expect('$window', 'RebuildCounter("tap", open, 0 rebuilds, 0 mounts)');
      window.close();
      expect(
        '${RebuildCounter.open()..close()}',
        'RebuildCounter(closed, 0 rebuilds, 0 mounts)',
      );
    });

    testWidgets('releases the hook when it closes', (tester) async {
      expect(debugOnRebuildDirtyWidget, isNull);
      final window = RebuildCounter.open();
      expect(debugOnRebuildDirtyWidget, isNotNull);
      window.close();
      expect(debugOnRebuildDirtyWidget, isNull);
    });

    testWidgets('keeps a previous hook working and puts it back',
        (tester) async {
      final seen = <Element>[];
      void record(Element e, bool _) => seen.add(e);
      // One tear-off, so it can be compared by identity afterwards.
      final RebuildDirtyWidgetCallback previous = record;
      debugOnRebuildDirtyWidget = previous;
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      final screen = await pumpScreen(tester);
      seen.clear();

      final window = RebuildCounter.open();
      screen.bump();
      await tester.pump();
      window.close();

      expect(seen, isNotEmpty);
      expect(seen.length, window.total);
      expect(identical(debugOnRebuildDirtyWidget, previous), isTrue);
    });

    testWidgets('windows overlap and close in any order', (tester) async {
      final screen = await pumpScreen(tester);

      final outer = RebuildCounter.open(label: 'outer');
      screen.bump();
      await tester.pump();
      final inner = RebuildCounter.open(label: 'inner');
      screen.bump();
      await tester.pump();
      outer.close();
      screen.bump();
      await tester.pump();
      inner.close();

      expect(outer.countOf(Screen), 2);
      expect(inner.countOf(Screen), 2);
      expect(debugOnRebuildDirtyWidget, isNull);
    });

    testWidgets('refuses to vouch for counts when the hook was replaced',
        (tester) async {
      void ignore(Element _, bool __) {}
      final RebuildDirtyWidgetCallback other = ignore;
      addTearDown(() => debugOnRebuildDirtyWidget = null);

      final window = RebuildCounter.open(label: 'hijacked');
      debugOnRebuildDirtyWidget = other;

      expect(
        window.close,
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('counts are incomplete'),
        )),
      );
      expect(window.isOpen, isFalse);
      // The other hook is not ours to remove.
      expect(identical(debugOnRebuildDirtyWidget, other), isTrue);
    });

    testWidgets('a window left open is closed and reported at test end',
        (tester) async {
      final window = RebuildCounter.open(label: 'forgotten');

      final message = closeLeftOpenWindow(window);

      expect(
          message,
          contains('window "forgotten" was opened but never '
              'closed'));
      expect(window.isOpen, isFalse);
      expect(debugOnRebuildDirtyWidget, isNull);
      expect(closeLeftOpenWindow(window), isNull);
    });

    testWidgets('record() closes the window after the interaction',
        (tester) async {
      final screen = await pumpScreen(tester);

      final window = await RebuildCounter.record(() async {
        screen.bump();
        await tester.pump();
      });

      expect(window.isOpen, isFalse);
      expect(window.countOf(Screen), 1);
    });

    testWidgets('record() closes the window when the interaction throws',
        (tester) async {
      await expectLater(
        RebuildCounter.record(() async => throw StateError('boom')),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'boom')),
      );
      expect(debugOnRebuildDirtyWidget, isNull);
    });
  });

  group('counters', () {
    testWidgets('report how much they changed while the window was open',
        (tester) async {
      var fetches = 3;
      var ticks = 10;

      final window = RebuildCounter.open(
        fetchCount: () => fetches,
        counters: {'ticks': () => ticks},
      );
      fetches += 2;
      ticks += 5;
      window.close();
      fetches += 100;

      expect(window.counterDelta('fetchCount'), 2);
      expect(window.counterDelta('ticks'), 5);
      expect(window.counterNames, containsAll(['fetchCount', 'ticks']));
    });

    testWidgets('cannot be read while the window is open', (tester) async {
      final window = RebuildCounter.open(fetchCount: () => 0);
      expect(() => window.counterDelta('fetchCount'), throwsStateError);
      window.close();
    });

    testWidgets('must exist to be read', (tester) async {
      final window = RebuildCounter.open();
      window.close();
      expect(() => window.counterDelta('nope'), throwsArgumentError);
    });

    test('fetchCount cannot also be passed as a named counter', () {
      expect(
        () => RebuildCounter.open(
          fetchCount: () => 0,
          counters: {'fetchCount': () => 0},
        ),
        throwsArgumentError,
      );
    });
  });

  group('scroll offsets', () {
    testWidgets('are snapshotted at both ends of the window', (tester) async {
      await pumpList(tester);

      final window = RebuildCounter.open();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      window.close();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      final delta = window.scrollDelta(find.byType(ListView))!;
      expect(delta, greaterThan(200));
      expect(delta, lessThan(301));
    });

    testWidgets('resolve from a widget inside the scrollable', (tester) async {
      await pumpList(tester);

      final window = RebuildCounter.open();
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pump();
      window.close();

      expect(window.scrollDelta(find.byType(ListRow).first), isNot(0));
      expect(window.scrollDelta(find.byType(Scrollable)), isNot(0));
    });

    testWidgets('are null when nothing scrollable is found', (tester) async {
      final screen = await pumpScreen(tester);
      final window = RebuildCounter.open();
      screen.bump();
      await tester.pump();
      window.close();

      expect(window.scrollDelta(find.byType(Footer)), isNull);
    });
  });

  group('print mode', () {
    testWidgets('prints per-type counts when a window closes', (tester) async {
      final screen = await pumpScreen(tester);
      RebuildCounter.printCounts = true;
      addTearDown(() => RebuildCounter.printCounts = false);

      var fetches = 0;
      final window =
          RebuildCounter.open(label: 'bump', fetchCount: () => fetches);
      screen.bump();
      fetches++;
      await tester.pump();
      final printed = <String>[];
      runZoned(
        window.close,
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => printed.add(line),
        ),
      );

      expect(printed, hasLength(1));
      expect(printed.single, startsWith('[rebuild counts] window "bump": '));
      expect(printed.single, contains('2  CountLabel'));
      expect(printed.single, contains('counter fetchCount changed by 1'));
    });

    test('is off unless REBUILD_COUNTS is defined', () {
      expect(
        RebuildCounter.printCounts,
        const bool.fromEnvironment('REBUILD_COUNTS'),
      );
    });
  });
}
