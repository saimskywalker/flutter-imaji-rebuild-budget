# API

Everything is exported from `package:rebuildcop/rebuildcop.dart`,
except the [guard](#guard-keeping-the-package-out-of-the-app), which has a
library of its own.

## `RebuildWindow`, the counting window

| Member | What it does |
|---|---|
| `RebuildWindow.open({label, fetchCount, counters})` | Starts counting. Call it after the widget is pumped, right before the interaction. Throws a `StateError` outside `flutter test` (no `TestWidgetsFlutterBinding`). |
| `RebuildWindow.record(() async { ... }, {...})` | Opens, runs the interaction, closes, even when it throws. |
| `close()` | Stops counting and snapshots scroll offsets and counters. |
| `countOf(Type)` / `countNamed('_Private')` / `countWhere(test)` | Rebuilds of an exact type, a type by name, or widgets matching a predicate. |
| `countUnder(Finder, {of})` | Rebuilds of a subtree, optionally of one type inside it. |
| `presentTypes` | Widget types that had an element in the tree during the window. A type budget for anything else fails. |
| `mountsOf(Type)`, `mounts`, `rebuilds`, `total` | Raw records. A *mount* is an element built for the first time inside the window; a *rebuild* is an element that already existed building again. |
| `BuildRecord` | One entry of `mounts` or `rebuilds`: `widget`, `widgetType`, `typeName`, `isMount`, `element`, and `ancestors` (the enclosing widgets at build time, nearest first, as `AncestorSnapshot`s). |
| `countsByType()`, `describeBusiest({top, budgets, under})` | Per-type counts and the failure table, for your own `reason:` strings. |
| `counterDelta(name)`, `scrollDelta(Finder)` | How much a counter or a scroll offset changed between `open` and `close`. |
| `RebuildWindow.printCounts` | Print mode; defaults to `--dart-define=PRINT_REBUILDS=true`. |
| `RebuildWindow.updateBaselines` | Baseline update mode; defaults to `--dart-define=UPDATE_REBUILD_BUDGETS=true`. |

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
final window = RebuildWindow.open(fetchCount: () => api.calls);
for (var i = 0; i < 5; i++) {
  await tester.pump(const Duration(seconds: 15)); // the poll interval
}
window.close();

expect(window, interactionHappened(fetchCount: 5));
expect(window, rebuiltAtMost(0, of: NavigationBar));
```

Type matching is exact: a budget for `MyCard` says nothing about a subclass
`MyFancyCard`. A type budget whose type never appeared in the window fails
instead of passing, because it could never fail (a renamed widget, or a test
that imports a same-named widget from another library than the app). Pass
`allowAbsent: true` to keep one anyway, or use `findsNothing` to assert that
a widget is not there. Every matcher takes `top:` (default 10) for the length of the
busiest-types table.

## Guard: keeping the package out of the app

`package:rebuildcop/guard.dart` exports one function for the app's
own suite:

```dart
// test/rebuild_budget_guard_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rebuildcop/guard.dart';

void main() =>
    test('rebuild budgets stay out of the app', expectRebuildBudgetIsTestOnly);
```

| Member | What it does |
|---|---|
| `expectRebuildBudgetIsTestOnly({packageRoot})` | Fails the test if the app's `pubspec.yaml` lists `rebuildcop` under `dependencies`, or a `.dart` file under `lib/` imports or exports `package:rebuildcop/...`. The failure names the file and line of each finding. The app is the nearest directory above the test file with a `pubspec.yaml`; `packageRoot` checks another one. |
| `dart run rebuildcop:check [dir]` | The same check as a command, without `flutter test`. Exits 0 when clean, 1 with the findings on stderr, 2 on a usage error. Without `dir` it checks the package around the working directory. |

```text
rebuildcop must stay out of the app in /work/shop: it depends on
flutter_test, and every dependency and every import from lib/ is compiled into
release builds.
  pubspec.yaml:14: rebuildcop is under dependencies, so it is built into the app. Move it to dev_dependencies.
  lib/debug_menu.dart:3: imports package:rebuildcop/rebuildcop.dart. Import it only from test/ or integration_test/.
```

Not findings: the package under `dev_dependencies` (from pub.dev, a path or
git) or `dependency_overrides`; imports from `test/`, `integration_test/`,
`tool/` or anywhere else outside `lib/`; and the package's name in comments,
strings or other packages' names (`package:rebuildcop_example/`).
A pubspec without `dev_dependencies` is fine. In a pub workspace
(`resolution: workspace`) each member is checked on its own, so add the test
to each package that depends on `rebuildcop`. The pubspec is read
by a small reader of top-level keys, not `package:yaml`, so the guard adds no
dependency. It needs a file system: under `flutter test --platform chrome` it
throws `UnsupportedError`.
