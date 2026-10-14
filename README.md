# imaji_rebuild_budget — rebuild budgets for Flutter widget tests

Unnecessary widget rebuilds in Flutter are invisible until a screen janks on a
mid-range phone; `imaji_rebuild_budget` turns them into failing `flutter test`
runs.

[![pub version](https://img.shields.io/pub/v/imaji_rebuild_budget)](https://pub.dev/packages/imaji_rebuild_budget)
[![pub points](https://img.shields.io/pub/points/imaji_rebuild_budget)](https://pub.dev/packages/imaji_rebuild_budget/score)
[![pub likes](https://img.shields.io/pub/likes/imaji_rebuild_budget)](https://pub.dev/packages/imaji_rebuild_budget/score)
[![CI](https://github.com/saimskywalker/flutter-imaji-rebuild-budget/actions/workflows/ci.yml/badge.svg)](https://github.com/saimskywalker/flutter-imaji-rebuild-budget/actions/workflows/ci.yml)
![Flutter 3.27+](https://img.shields.io/badge/Flutter-3.27%2B-02569B?logo=flutter)
![Dart 3.6+](https://img.shields.io/badge/Dart-3.6%2B-0175C2?logo=dart)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

- **Headless.** Runs in plain `flutter test` on any CI runner. No device, no
  emulator, no `integration_test`, no `traceAction`.
- **No probes in production code.** It listens to Flutter's own
  [`debugOnRebuildDirtyWidget`](https://api.flutter.dev/flutter/widgets/debugOnRebuildDirtyWidget.html)
  hook, the one DevTools' "Track widget rebuilds" uses. Your `lib/` gets no
  keys, counters or wrappers.
- **Budgets are measurements.** Print mode records the real counts; a baseline
  file turns every budget increase into a reviewed diff.
- **A zero must prove something happened.** `interactionHappened` fails a
  window whose scroll never moved or whose fake was never called.
- **Failures say what rebuilt**, not only that something did.

## Contents

- [30-second quick start](#30-second-quick-start)
- [What a failure looks like](#what-a-failure-looks-like)
- [API](#api)
- [Measuring a budget (print mode)](#measuring-a-budget-print-mode)
- [Baseline files](#baseline-files)
- [Examples: setState, keys, Riverpod, Provider, Bloc](#examples)
- [FAQ](#faq)
- [Comparison](#comparison)
- [Support](#support)

## 30-second quick start

Add it as a dev dependency from
[pub.dev](https://pub.dev/packages/imaji_rebuild_budget):

```sh
flutter pub add --dev imaji_rebuild_budget
```

or by hand in `pubspec.yaml`:

```yaml
dev_dependencies:
  imaji_rebuild_budget: ^0.1.0
```

To try unreleased changes from `main` instead (not a published version, and
it can change under you):

```yaml
dev_dependencies:
  imaji_rebuild_budget:
    git: https://github.com/saimskywalker/flutter-imaji-rebuild-budget
```

Open a window, run one interaction, close the window, assert:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';

void main() {
  testWidgets('scrolling the feed never rebuilds the tab bar', (tester) async {
    await tester.pumpWidget(const MyApp());

    final window = RebuildCounter.open(label: 'scroll the feed');
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    window.close();

    expect(window, interactionHappened(scrollOffsetMoved: find.byType(ListView)));
    expect(window, rebuiltAtMost(0, of: TabBar));
  });
}
```

Run `flutter test`. That's it.

## What a failure looks like

A clock that ticks with `setState` at the root of a screen rebuilds the whole
product list once a second. Three ticks, budget zero:

```
Expected: ProductTile rebuilt at most 0 times in the window
  Actual: RebuildCounter("three clock ticks", closed, 42 rebuilds, 0 mounts)
   Which: rebuilt 15 times, 15 over budget.
          42 rebuilds across 5 widget types, busiest first:
            18  Text
            15  ProductTile      budget 0, over by 15
             3  ClockText
             3  ProductList
             3  TickingShopSlow
```

The busiest types point straight at the cause: the screen itself rebuilt three
times, and took the list with it.

## API

Everything is exported from `package:imaji_rebuild_budget/imaji_rebuild_budget.dart`.

### `RebuildCounter`, the counting window

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

### Matchers

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

## Measuring a budget (print mode)

Never guess a budget. Run the interaction, read the count, write that number
down:

```sh
flutter test --dart-define=REBUILD_COUNTS=true test/feed_test.dart
```

```
[rebuild counts] window "three clock ticks": 42 rebuilds, 0 mounts
  18  Text
  15  ProductTile
   3  ClockText
   3  ProductList
   3  TickingShopSlow
[rebuild counts] ProductTile rebuilt in "three clock ticks": measured 15, budget 0 (OVER)
```

Every window prints its per-type counts when it closes, and every budget
matcher prints its measurement beside its budget. A budget set above what the
code does today hides the next regression up to the slack; raising one is a
decision to accept more rebuilds, to be made in review, not the fix for a red
test.

## Baseline files

For screens with several hot spots, keep the budgets in a JSON file next to
the test, like a golden file:

```dart
expect(
  window,
  matchesRebuildBaseline(
    'rebuild_budgets/feed.json',
    key: 'scroll the feed',
    types: [FeedTile, TabBar],
    named: ['_FeedHeader'],
  ),
);
```

Write (or rewrite) it from the measured counts:

```sh
flutter test --dart-define=UPDATE_REBUILD_BUDGETS=true test/feed_test.dart
```

```json
{
  "scroll the feed": {
    "FeedTile": 12,
    "TabBar": 0,
    "_FeedHeader": 1
  }
}
```

Commit the file. From then on, a budget increase is a one-line diff a reviewer
sees. A missing file, key or type fails with the command to record it, and a
budget for a type the test no longer tracks fails too, so the file always
matches the test. Keep one baseline file per test file (test files run in
parallel), and never enable update mode in CI.

## Examples

[`example/`](example) pairs real over-rebuilds with their fixes, each as a
small test file:

| | Over-rebuild | Fix | Matcher |
|---|---|---|---|
| setState | A ticking clock at the screen root rebuilds every tile | Clock owns its own state; list is `const` | `rebuiltAtMost` |
| Keys | `UniqueKey()` in `build` remounts every row | `ValueKey(id)` | `mountedAtMost` |
| Riverpod | `ref.watch(cartProvider)` for one field | `ref.watch(cartProvider.select(...))` | `rebuiltAtMost` |
| Provider | `context.watch<T>()` for one field | `context.select<T, R>(...)` | `rebuiltAtMost` |
| Bloc | `BlocBuilder` redraws a file name on every progress tick | `BlocSelector` | `subtreeRebuiltAtMost` |

The state libraries are dependencies of the example only; this package depends
on nothing but Flutter.

## FAQ

**Why not DevTools?**
DevTools' "Track widget rebuilds" uses the very same framework hook, and it is
the right tool for *finding* a problem. But it is interactive: someone has to
open it, run the app, and look. Nothing stops the fix from regressing next
month. This package turns what you saw in DevTools into a test that fails in
CI when it comes back.

**Does it work in CI?**
Yes. It is plain `flutter test`: headless, on the Dart VM, on any Linux, macOS
or Windows runner. No device, emulator, simulator or `integration_test`. The
hook only fires in debug builds, which is what `flutter test` always runs.

**Is this a performance test?**
No, and that is the point. It counts *work*, not milliseconds, so it is
deterministic: the same code gives the same count on a laptop and on a
throttled CI runner. A rebuild count is a proxy for jank, but a stable one.

**What counts as a rebuild?**
Every time Flutter calls `Element.rebuild` on an element that already existed
when the window opened, or was mounted earlier in it. For stateless,
stateful and proxy widgets (your own widgets, `Text`, `Builder`, an
`InheritedWidget`, state-library consumers) that covers a `setState`, a
changed `InheritedWidget` dependency, and a parent handing it a new widget
instance. `const` widgets that Flutter skips are not counted. First builds are
counted separately as mounts.

**Known gap: render-object widgets are mostly not counted.** For
`ColoredBox`, `Padding`, `SizedBox`, `Column`, `RichText`, `Opacity` and every
other `RenderObjectWidget`, a parent handing it a new widget instance is not
counted: `RenderObjectElement.update` calls `updateRenderObject` directly
instead of going through `Element.rebuild`, so `debugOnRebuildDirtyWidget`
never fires. Its first build (`mount`) skips `Element.rebuild` too. The only
build of one that is counted is a changed `InheritedWidget` dependency (for
example `Padding` reading `Directionality`) when no parent rebuilt it in the
same frame. A budget such as `rebuiltAtMost(0, of: ColoredBox)` therefore
passes even when the `ColoredBox` gets a new color every frame, and
`mountedAtMost` does not see new render-object elements. Budget the widget
that *builds* them instead (the stateless or stateful widget above them),
which is counted. This is a framework limitation tracked upstream in
[flutter/flutter#71626](https://github.com/flutter/flutter/issues/71626), and
DevTools' "Track widget rebuilds" shares it because it uses the same hook.
Counting these updates separately is planned in
[#10](https://github.com/saimskywalker/flutter-imaji-rebuild-budget/issues/10).

**Should every widget have a budget?**
No. Count the few hot spots that matter (a bottom nav under a poll, a list
under a ticking timer, a header over a scroll view). A suite that fails over
rebuilds nobody cares about gets switched off.

**My budget passed with zero, but the screen is broken.**
That is what `interactionHappened` is for: a drag that missed its target or a
timer that never fired also produces zero rebuilds. Pair every budget with
proof that the interaction ran.

**Why do I have to call `close()`?**
So the counts cover exactly the interaction. Frames pumped later (settling
animations, teardown) cannot change them. Use `RebuildCounter.record` if you
prefer a closure.

**Does it work with `flutter test --platform chrome`?**
The counters and matchers do. Baseline files need a file system, so
`matchesRebuildBaseline` throws `UnsupportedError` on the web.

**Which Flutter versions?**
The package: Flutter 3.27 (Dart 3.6) and newer. CI runs its suite on 3.27.4
and 3.47.7. The [`example/`](example) app needs Flutter 3.32 (Dart 3.8) or
newer, because `flutter_riverpod` 3 does; CI runs it on 3.47.7.

## Comparison

| | Headless in `flutter test` | Fails a test | No code in `lib/` | Points at the widget |
|---|---|---|---|---|
| **imaji_rebuild_budget** | yes | yes | yes | yes, busiest types |
| DevTools "Track widget rebuilds" | no, interactive | no | yes | yes |
| `debugPrintRebuildDirtyWidgets` | yes | no, a log to read | yes | yes, unaggregated |
| `integration_test` + `traceAction` / frame timings | no, needs a device | yes, on timings | yes | no |
| Hand-written counters in `build()` | yes | yes | no | only where added |

## Support

If this saved you a janky release, a ⭐ on GitHub helps other Flutter
developers find it. Bug reports and pull requests are welcome; see
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT © saimskywalker. See [LICENSE](LICENSE).
