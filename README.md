# rebuild_budget

> Status: **pre-alpha, not published.** The API below is the design target;
> progress is tracked in the issues.

Rebuild regressions are invisible until a screen janks on a mid-range phone.
`rebuild_budget` turns them into failing tests.

It hooks Flutter's own `debugOnRebuildDirtyWidget` — the hook DevTools'
"Track widget rebuilds" uses — so production code needs no keys, probes or
counters. Open a window, run the interaction, and assert that a widget type,
or a whole subtree, rebuilt no more than a measured budget. A failure lists
the busiest widget types. It runs in plain `flutter test`, headless, with no
device and no `traceAction`.

## Planned API

```dart
testWidgets('scrolling the feed rebuilds the tab bar at most twice', (tester) async {
  await tester.pumpWidget(const MyApp());

  final window = RebuildCounter.open();
  await tester.drag(find.byType(ListView), const Offset(0, -600));
  await tester.pumpAndSettle();
  window.close();

  expect(window, interactionHappened(scrollOffsetMoved: find.byType(ListView)));
  expect(window, rebuiltAtMost(2, of: TabBar));
});
```

## Principles

- **A budget is a measurement, not a wish.** Print mode records the real
  counts; you commit those numbers and review any increase like any other
  behaviour change.
- **A zero must prove something happened.** Every window can assert that its
  interaction actually ran, so a test that scrolled nothing cannot pass.
- **Count the few hot spots, not everything.** A suite that fails over
  rebuilds that do not matter gets switched off.

## License

MIT. See [LICENSE](LICENSE).
