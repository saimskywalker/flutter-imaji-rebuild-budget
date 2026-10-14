import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
import 'package:imaji_rebuild_budget_example/bloc/playback.dart';

Future<RebuildCounter> playFiveSeconds(
  WidgetTester tester, {
  required bool selective,
}) async {
  final cubit = PlaybackCubit('Track one');
  await tester.pumpWidget(
    BlocProvider.value(
      value: cubit,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [TrackTitle(selective: selective), const PositionText()],
        ),
      ),
    ),
  );

  var ticks = 0;
  final window = RebuildCounter.open(
    label: 'five seconds of playback',
    counters: {'ticks': () => ticks},
  );
  for (var i = 0; i < 5; i++) {
    cubit.tick();
    ticks++;
    await tester.pump();
  }
  window.close();
  await cubit.close();
  return window;
}

void main() {
  testWidgets('BEFORE: a BlocBuilder redraws the title on every tick',
      (tester) async {
    final window = await playFiveSeconds(tester, selective: false);

    expect(
      window,
      interactionHappened(counters: {'ticks': 5}, rebuilt: PositionText),
    );
    // TrackTitle itself never rebuilds, so a per-type budget on it passes...
    expect(window, rebuiltAtMost(0, of: TrackTitle));
    // ...but the subtree budget sees the builder inside it.
    expect(
      window,
      isNot(subtreeRebuiltAtMost(0, under: find.byType(TrackTitle))),
    );
  });

  testWidgets('AFTER: a BlocSelector on the title stays quiet', (tester) async {
    final window = await playFiveSeconds(tester, selective: true);

    expect(
      window,
      interactionHappened(counters: {'ticks': 5}, rebuilt: PositionText),
    );
    expect(window, subtreeRebuiltAtMost(0, under: find.byType(TrackTitle)));
  });
}
