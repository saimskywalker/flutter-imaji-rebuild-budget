import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
import 'package:imaji_rebuild_budget_example/provider/player_settings.dart';
import 'package:provider/provider.dart';

Future<RebuildCounter> toggleTheme(WidgetTester tester, Widget label) async {
  final settings = PlayerSettings();
  addTearDown(settings.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [label, const ThemeLabel()]),
      ),
    ),
  );

  final window = RebuildCounter.open(label: 'toggle dark mode');
  settings.toggleDarkMode();
  await tester.pump();
  window.close();
  return window;
}

void main() {
  testWidgets(
      'BEFORE: context.watch rebuilds the volume label for a theme '
      'change', (tester) async {
    final window = await toggleTheme(tester, const VolumeLabelSlow());

    expect(window, interactionHappened(rebuilt: ThemeLabel));
    expect(window, isNot(rebuiltAtMost(0, of: VolumeLabelSlow)));
  });

  testWidgets('AFTER: context.select leaves it alone', (tester) async {
    final window = await toggleTheme(tester, const VolumeLabelFast());

    expect(window, interactionHappened(rebuilt: ThemeLabel));
    expect(window, rebuiltAtMost(0, of: VolumeLabelFast));
  });
}
