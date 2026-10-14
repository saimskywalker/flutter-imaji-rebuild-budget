import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
import 'package:imaji_rebuild_budget_example/bloc/download.dart';

Future<RebuildCounter> fiveProgressTicks(
  WidgetTester tester, {
  required bool selective,
}) async {
  final cubit = DownloadCubit('report.pdf');
  await tester.pumpWidget(
    BlocProvider.value(
      value: cubit,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            FileNameText(selective: selective),
            const ProgressText(),
          ],
        ),
      ),
    ),
  );

  var ticks = 0;
  final window = RebuildCounter.open(
    label: 'five progress ticks',
    counters: {'ticks': () => ticks},
  );
  for (var i = 0; i < 5; i++) {
    cubit.progress();
    ticks++;
    await tester.pump();
  }
  window.close();
  await cubit.close();
  return window;
}

void main() {
  testWidgets('BEFORE: a BlocBuilder redraws the file name on every tick', (
    tester,
  ) async {
    final window = await fiveProgressTicks(tester, selective: false);

    expect(
      window,
      interactionHappened(counters: {'ticks': 5}, rebuilt: ProgressText),
    );
    // FileNameText itself never rebuilds, so a per-type budget on it
    // passes...
    expect(window, rebuiltAtMost(0, of: FileNameText));
    // ...but the subtree budget sees the builder inside it.
    expect(
      window,
      isNot(subtreeRebuiltAtMost(0, under: find.byType(FileNameText))),
    );
  });

  testWidgets('AFTER: a BlocSelector on the name stays quiet', (tester) async {
    final window = await fiveProgressTicks(tester, selective: true);

    expect(
      window,
      interactionHappened(counters: {'ticks': 5}, rebuilt: ProgressText),
    );
    expect(window, subtreeRebuiltAtMost(0, under: find.byType(FileNameText)));
  });
}
