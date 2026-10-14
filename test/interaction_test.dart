import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';

import 'support/fixtures.dart';

void main() {
  group('scrollOffsetMoved', () {
    testWidgets('passes when the list scrolled', (tester) async {
      await pumpList(tester);

      final window = RebuildCounter.open();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      window.close();

      expect(
        window,
        interactionHappened(scrollOffsetMoved: find.byType(ListView)),
      );
    });

    testWidgets('fails when the drag missed', (tester) async {
      await pumpList(tester);

      final window = RebuildCounter.open();
      // A horizontal drag on a vertical list moves nothing.
      await tester.drag(find.byType(ListView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      window.close();

      final message = mismatchOf(
        interactionHappened(scrollOffsetMoved: find.byType(ListView)),
        window,
      );
      expect(message, startsWith('gives no proof the interaction ran:'));
      expect(message, contains('did not change'));
    });

    testWidgets('fails when the finder finds nothing', (tester) async {
      await pumpList(tester);
      final window = RebuildCounter.open()..close();

      expect(
        mismatchOf(
          interactionHappened(scrollOffsetMoved: find.byType(PageView)),
          window,
        ),
        contains('scrollOffsetMoved: found no widgets with type "PageView"'),
      );
    });

    testWidgets('fails when the scrollable appeared after the window opened',
        (tester) async {
      await tester.pumpWidget(const SizedBox());
      final window = RebuildCounter.open();
      await pumpList(tester);
      window.close();

      expect(
        mismatchOf(
          interactionHappened(scrollOffsetMoved: find.byType(ListView)),
          window,
        ),
        contains('on screen both when the window opened and when it closed'),
      );
    });
  });

  group('fetchCount and counters', () {
    testWidgets('match an exact count or any matcher', (tester) async {
      var fetches = 0;
      var saves = 0;
      final window = RebuildCounter.open(
        fetchCount: () => fetches,
        counters: {'saves': () => saves},
      );
      fetches += 5;
      saves += 1;
      window.close();

      expect(window, interactionHappened(fetchCount: 5));
      expect(window, interactionHappened(fetchCount: greaterThan(0)));
      expect(window, interactionHappened(counters: {'saves': 1}));
      expect(
        mismatchOf(interactionHappened(fetchCount: 6), window),
        contains('fetchCount changed by 5, expected <6>'),
      );
    });

    testWidgets('a zero fetch count is no proof', (tester) async {
      const fetches = 0;
      final window = RebuildCounter.open(fetchCount: () => fetches)..close();

      expect(
        mismatchOf(interactionHappened(fetchCount: greaterThan(0)), window),
        contains('fetchCount changed by 0'),
      );
    });

    testWidgets('name a counter the window was not given', (tester) async {
      final window = RebuildCounter.open()..close();

      expect(
        mismatchOf(interactionHappened(fetchCount: 1), window),
        contains('opened without a fetchCount callback'),
      );
      expect(
        mismatchOf(interactionHappened(counters: {'saves': 1}), window),
        contains('without a counter named "saves"'),
      );
    });
  });

  group('rebuilt', () {
    testWidgets('requires at least one rebuild of the type', (tester) async {
      final screen = await pumpScreen(tester);
      final window = RebuildCounter.open();
      screen.bump();
      await tester.pump();
      window.close();

      expect(window, interactionHappened(rebuilt: CountLabel));
      expect(
        mismatchOf(interactionHappened(rebuilt: Footer), window),
        contains('Footer never rebuilt'),
      );
    });
  });

  testWidgets('lists every unmet condition', (tester) async {
    await pumpList(tester);
    final window = RebuildCounter.open(fetchCount: () => 0)..close();

    final message = mismatchOf(
      interactionHappened(
        scrollOffsetMoved: find.byType(ListView),
        fetchCount: 1,
        rebuilt: ListRow,
      ),
      window,
    );
    expect('\n  - '.allMatches(message), hasLength(3));
  });

  testWidgets('describes all its conditions', (tester) async {
    final description = interactionHappened(
      scrollOffsetMoved: find.byType(ListView),
      fetchCount: 2,
      rebuilt: ListRow,
    ).describe(StringDescription()).toString();

    expect(description, contains('the scroll offset of'));
    expect(description, contains('fetchCount changed by <2>'));
    expect(description, contains('ListRow rebuilt at least once'));
  });

  testWidgets('refuses an open window', (tester) async {
    final window = RebuildCounter.open(fetchCount: () => 0);
    final message = mismatchOf(interactionHappened(fetchCount: 0), window);
    window.close();
    expect(message, contains('still open'));
  });

  test('needs at least one condition', () {
    expect(interactionHappened, throwsArgumentError);
    expect(
      () => interactionHappened(fetchCount: 1, counters: {'fetchCount': 1}),
      throwsArgumentError,
    );
  });
}
