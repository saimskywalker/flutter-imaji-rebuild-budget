import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebuildcop/rebuildcop.dart';
import 'package:rebuildcop/src/output/type_table.dart';

import 'support/fixtures.dart';

void main() {
  // One notifier tick rebuilds the builder (1), six new ListRows (6), their
  // Texts and the CountLabel's Text (7) and the CountLabel (1). The const
  // Footer is skipped.
  Future<RebuildWindow> rebuildList(WidgetTester tester) async {
    final notifier = ValueNotifier(0);
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (_, value, __) => Column(
            children: [
              for (var i = 0; i < 6; i++) ListRow(i),
              CountLabel(value),
              const Footer(),
            ],
          ),
        ),
      ),
    );
    final window = RebuildWindow.open();
    notifier.value++;
    await tester.pump();
    window.close();
    return window;
  }

  testWidgets('formatTypeTable aligns counts and budgets', (tester) async {
    final window = await rebuildList(tester);

    final table = formatTypeTable(window.rebuilds, budgets: {'CountLabel': 0});

    expect(
      table.split('\n').take(3).join('\n'),
      '15 rebuilds across 4 widget types, busiest first:\n'
      '  7  Text\n'
      '  6  ListRow',
    );
    // Budgeted rows pad the name so budgets line up in one column.
    expect(
      table,
      contains('  1  CountLabel${' ' * 17}  budget 0, over by 1'),
    );
    expect(table, endsWith('  1  ValueListenableBuilder<int>'));
  });

  testWidgets(
      'formatTypeTable truncates to the top N and says how many are '
      'hidden', (tester) async {
    final window = await rebuildList(tester);

    final table = formatTypeTable(window.rebuilds, top: 1);

    expect(table, contains('7  Text'));
    expect(table, isNot(contains('ListRow')));
    expect(table, endsWith('... and 3 more types'));
  });

  testWidgets('describeBusiest narrows to a subtree', (tester) async {
    final screen = await showScreen(tester);
    final window = RebuildWindow.open();
    screen.bump();
    await tester.pump();
    window.close();

    final table = window.describeBusiest(under: find.byType(Panel));

    expect(table, startsWith('3 rebuilds across 3 widget types'));
    expect(table, isNot(contains('Screen')));
  });

  test('formatTypeTable on nothing', () {
    expect(formatTypeTable(const []), 'no rebuilds were recorded');
    expect(formatTypeTable(const [], noun: 'mount'), 'no mounts were recorded');
  });

  test('measurementLine flags an overrun', () {
    expect(measurementLine('TabBar', 2, 2),
        '[rebuildcop] TabBar: measured 2, budget 2');
    expect(measurementLine('TabBar', 3, 2),
        '[rebuildcop] TabBar: measured 3, budget 2 (OVER)');
  });
}
