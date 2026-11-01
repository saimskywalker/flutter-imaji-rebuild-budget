# rebuildcop

Turn unnecessary Flutter widget rebuilds into failing `flutter test` runs,
so a screen that starts rebuilding too much is caught in CI instead of as jank
on a mid-range phone.

[![pub version](https://img.shields.io/pub/v/rebuildcop)](https://pub.dev/packages/rebuildcop)
[![pub points](https://img.shields.io/pub/points/rebuildcop)](https://pub.dev/packages/rebuildcop/score)
[![pub likes](https://img.shields.io/pub/likes/rebuildcop)](https://pub.dev/packages/rebuildcop/score)
[![CI](https://github.com/saimskywalker/rebuildcop/actions/workflows/ci.yml/badge.svg)](https://github.com/saimskywalker/rebuildcop/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-green)](https://github.com/saimskywalker/rebuildcop/blob/main/LICENSE)

## Why

- Over-rebuilds are invisible in tests and code review; they show up later as
  jank on real devices.
- DevTools finds them, but only when someone opens it and looks. Nothing stops
  the fix from regressing next month.
- Frame-timing tests need a device and are flaky. A rebuild count is
  deterministic: same code, same number, on a laptop or a slow CI runner.

## Install

```sh
flutter pub add --dev rebuildcop
```

Keep it in `dev_dependencies` and import it only from tests. It depends on
`flutter_test`, and a package imported from `lib/` is compiled into release
builds. Windows refuse to open outside `flutter test`. Leave the
`depend_on_referenced_packages` lint on (`flutter_lints` enables it); it
flags a `lib/` import of a dev dependency:

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    depend_on_referenced_packages: true
```

The lint stays quiet once the package is moved to `dependencies`, so add one
test to the app's suite as well. It fails, naming the file and line, if the
package is listed under `dependencies` or imported from `lib/`:

```dart
// test/rebuild_budget_guard_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rebuildcop/guard.dart';

void main() =>
    test('rebuild budgets stay out of the app', expectRebuildBudgetIsTestOnly);
```

`dart run rebuildcop:check` runs the same check without
`flutter test`, for an early CI step.

### Coming from imaji_rebuild_budget

This package was renamed from `imaji_rebuild_budget`; the API is the same.
Replace the dev dependency with `rebuildcop`, change
`package:imaji_rebuild_budget/` imports to `package:rebuildcop/`, and run
`dart run rebuildcop:check`. See the
[CHANGELOG](https://github.com/saimskywalker/rebuildcop/blob/main/CHANGELOG.md).

## Quick start

Open a window, run one interaction, close the window, assert:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rebuildcop/rebuildcop.dart';

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

Run `flutter test`. To pick a budget, measure first: run with
`--dart-define=REBUILD_COUNTS=true` and every window prints its per-type
counts.

## Example output

A clock that ticks with `setState` at the root of a screen rebuilds the whole
product list once a second. Three ticks, budget zero:

```text
Expected: ProductTile rebuilt at most 0 times in the window
  Actual: RebuildCounter:<RebuildCounter("three clock ticks", closed, 42 rebuilds, 0 mounts)>
   Which: rebuilt 15 times, 15 over budget.
          42 rebuilds across 5 widget types, busiest first:
            18  Text
            15  ProductTile      budget 0, over by 15
             3  ClockText
             3  ProductList
             3  TickingShopSlow
```

The busiest types point at the cause: the screen itself rebuilt three times
and took the list with it.

## Features

- **Headless**: plain `flutter test` on any CI runner. No device, emulator,
  `integration_test` or `traceAction`.
- **No probes in production code**: it listens to Flutter's own
  [`debugOnRebuildDirtyWidget`](https://api.flutter.dev/flutter/widgets/debugOnRebuildDirtyWidget.html)
  hook, the one DevTools' "Track widget rebuilds" uses.
- **Budgets by type, private name or subtree**: `rebuiltAtMost`,
  `subtreeRebuiltAtMost`, and `mountedAtMost` for remounts that lose `State`.
- **A zero must prove something happened**: `interactionHappened` fails a
  window whose scroll never moved or whose fake was never called.
- **Baseline files**: `matchesRebuildBaseline` keeps budgets in JSON, so every
  increase is a reviewed one-line diff.
- **Failures say what rebuilt**, busiest types first.

Known gap: render-object widgets (`Padding`, `ColoredBox`, ...) are mostly not
counted, a framework limitation; budget the widget that builds them.
[Details in the FAQ](https://github.com/saimskywalker/rebuildcop/blob/main/doc/faq.md).

## Documentation

- [API: `RebuildCounter` and every matcher](https://github.com/saimskywalker/rebuildcop/blob/main/doc/api.md)
- [Measuring budgets (print mode) and baseline files](https://github.com/saimskywalker/rebuildcop/blob/main/doc/budgets.md)
- [Examples: setState, keys, Riverpod, Provider, Bloc](https://github.com/saimskywalker/rebuildcop/blob/main/doc/examples.md)
- [FAQ, known gaps, supported versions and comparison](https://github.com/saimskywalker/rebuildcop/blob/main/doc/faq.md)
- [pub.dev page](https://pub.dev/packages/rebuildcop) and [API docs](https://pub.dev/documentation/rebuildcop/latest/)
- [CHANGELOG](https://github.com/saimskywalker/rebuildcop/blob/main/CHANGELOG.md), [issues](https://github.com/saimskywalker/rebuildcop/issues) and [CONTRIBUTING](https://github.com/saimskywalker/rebuildcop/blob/main/CONTRIBUTING.md)

## License

MIT © saimskywalker. See [LICENSE](https://github.com/saimskywalker/rebuildcop/blob/main/LICENSE).
