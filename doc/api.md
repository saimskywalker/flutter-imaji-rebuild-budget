# API

Everything is exported from `package:imaji_rebuild_budget/imaji_rebuild_budget.dart`.

## `RebuildCounter`, the counting window

| Member | What it does |
|---|---|
| `RebuildCounter.open({label, fetchCount, counters})` | Starts counting. Call it after the widget is pumped, right before the interaction. |
| `RebuildCounter.record(() async { ... }, {...})` | Opens, runs the interaction, closes, even when it throws. |
| `close()` | Stops counting and snapshots scroll offsets and counters. |
| `countOf(Type)` / `countNamed('_Private')` / `countWhere(test)` | Rebuilds of an exact type, a type by name, or widgets matching a predicate. |
| `countUnder(Finder, {of})` | Rebuilds of a subtree, optionally of one type inside it. |
| `mountsOf(Type)`, `mounts`, `rebuilds`, `total` | Raw records. A *mount* is an element built for the first time inside the window; a *rebuild* is an element that already existed building again. |
| `countsByType()`, `describeBusiest({top, budgets, under})` | Per-type counts and the failure table, for your own `reason:` strings. |
| `counterDelta(name)`, `scrollDelta(Finder)` | How much a counter or a scroll offset changed between `open` and `close`. |
| `RebuildCounter.printCounts` | Print mode; defaults to `--dart-define=REBUILD_COUNTS=true`. |
| `RebuildCounter.updateBaselines` | Baseline update mode; defaults to `--dart-define=UPDATE_REBUILD_BUDGETS=true`. |

Windows may overlap and close in any order. A hook installed before the first
window opens keeps receiving every call and is put back afterwards. If
something replaces the hook while a window is open, `close()` throws rather
than report incomplete counts. A window still open when its test ends is
closed and **fails the test**, so a forgotten `close()` cannot leak into the
next test.

## Matchers

All matchers take a **closed** window; asserting on an open one fails, so
frames pumped after the interaction cannot change the result.

```dart
// A widget type, a private type by name, or every rebuild in the window.
expect(window, rebuiltAtMost(0, of: NavigationBar));
expect(window, rebuiltAtMost(2, named: '_FeedHeader'));
expect(window, rebuiltAtMost(40));

// A whole subtree: catches a busy Consumer or ValueListenableBuilder deep
// inside a widget whose own root never rebuilt. A finder that finds nothing
// fails rather than passes.
expect(window, subtreeRebuiltAtMost(0, under: find.byType(BottomNavigationBar)));
expect(window, subtreeRebuiltAtMost(1, under: find.byKey(cartKey), of: PriceTag));

// New elements: a UniqueKey() in build, or a subtree whose type flips, remounts
// and loses its State.
expect(window, mountedAtMost(0, of: ResultTile));

// Proof the interaction ran. Every given condition must hold.
expect(window, interactionHappened(
  scrollOffsetMoved: find.byType(ListView),   // the offset changed
  fetchCount: 5,                              // or greaterThan(0)
  counters: {'saves': 1},                     // named counters from open()
  rebuilt: UnreadBadge,                       // this type rebuilt at least once
));
```

`fetchCount` and `counters` are plain callbacks into your test doubles, read
when the window opens and when it closes:

```dart
final api = FakeInboxApi();
final window = RebuildCounter.open(fetchCount: () => api.calls);
for (var i = 0; i < 5; i++) {
  await tester.pump(const Duration(seconds: 15)); // the poll interval
}
window.close();

expect(window, interactionHappened(fetchCount: 5));
expect(window, rebuiltAtMost(0, of: NavigationBar));
```

Type matching is exact: a budget for `MyCard` says nothing about a subclass
`MyFancyCard`. Every matcher takes `top:` (default 10) for the length of the
busiest-types table.
