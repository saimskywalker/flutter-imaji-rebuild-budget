import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small screen with one piece of state and three kinds of children:
/// one that depends on the state, one rebuilt only because its parent made
/// a new instance of it, and a const one that Flutter skips.
class Screen extends StatefulWidget {
  const Screen({super.key});

  @override
  State<Screen> createState() => ScreenState();
}

class ScreenState extends State<Screen> {
  int count = 0;

  void bump() => setState(() => count++);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CountLabel(count),
        // ignore: prefer_const_constructors
        Ornament(),
        const Footer(),
        Panel(child: CountLabel(count)),
      ],
    );
  }
}

class CountLabel extends StatelessWidget {
  const CountLabel(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Text('$count');
}

class Ornament extends StatelessWidget {
  const Ornament({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 4);
}

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) => const Text('footer');
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: child,
      );
}

/// Pumps [Screen] and returns its state, so a test can call [ScreenState.bump].
Future<ScreenState> pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    const Directionality(textDirection: TextDirection.ltr, child: Screen()),
  );
  return tester.state<ScreenState>(find.byType(Screen));
}

/// Pumps a vertical list of [count] rows.
Future<void> pumpList(WidgetTester tester, {int count = 100}) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ListView.builder(
        itemCount: count,
        itemExtent: 50,
        itemBuilder: (context, index) => ListRow(index),
      ),
    ),
  );
}

class ListRow extends StatelessWidget {
  const ListRow(this.index, {super.key});

  final int index;

  @override
  Widget build(BuildContext context) => Text('row $index');
}

/// The mismatch text [matcher] produces for [item], failing the test if
/// [matcher] actually matches.
String mismatchOf(Matcher matcher, Object? item) {
  final state = <dynamic, dynamic>{};
  expect(matcher.matches(item, state), isFalse,
      reason: 'expected the matcher to reject the window');
  return matcher
      .describeMismatch(item, StringDescription(), state, false)
      .toString();
}
