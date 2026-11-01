// LiveTestWidgetsFlutterBinding, which integration_test's binding extends,
// is a test binding too, so windows open under it. It needs a file of its
// own because the binding is chosen once per isolate.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a window opens and counts', (tester) async {
    expect(WidgetsBinding.instance, isA<LiveTestWidgetsFlutterBinding>());
    final label = ValueNotifier(0);
    addTearDown(label.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<int>(
          valueListenable: label,
          builder: (context, value, _) => Text('$value'),
        ),
      ),
    );

    final window = RebuildCounter.open();
    label.value++;
    await tester.pump();
    window.close();

    expect(window, rebuiltAtMost(1, of: ValueListenableBuilder<int>));
    expect(window.countOf(ValueListenableBuilder<int>), 1);
  });
}
