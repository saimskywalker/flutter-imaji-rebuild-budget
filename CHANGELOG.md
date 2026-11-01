# Changelog

## 0.3.0

Internals rewritten; the window class is now `RebuildWindow` and print mode
is `--dart-define=PRINT_REBUILDS=true`. The rebuild tracking core
(the window, the matchers, the failure tables and baseline files) was
written again from scratch. The guard (`package:rebuildcop/guard.dart` and
`dart run rebuildcop:check`) is unchanged.

### Breaking changes

- The counting window class is renamed to `RebuildWindow`. Its members are
  the same: `RebuildWindow.open`, `RebuildWindow.record`, `close()`,
  `countOf`, `countNamed`, `countWhere`, `countUnder`, `mountsOf`,
  `presentTypes`, `countsByType`, `describeBusiest`, `counterDelta`,
  `scrollDelta`, `RebuildWindow.printCounts` and
  `RebuildWindow.updateBaselines`. There is no alias for the old name:
  replace it with `RebuildWindow` in tests, including return types such as
  `Future<RebuildWindow>` in test helpers.
- Print mode is turned on with `--dart-define=PRINT_REBUILDS=true`; the
  0.2.0 define is no longer read. Printed lines start with `[rebuildcop]`.
- The entries of `rebuilds` and `mounts` are `BuildRecord`s, and their
  `ancestors` are `AncestorSnapshot`s, both exported. Code that only read
  their fields (`widget`, `widgetType`, `typeName`, `isMount`, `ancestors`)
  needs no change.
- A matcher given something other than a window says
  `is not a RebuildWindow`.

### Unchanged

- Every matcher (`rebuiltAtMost`, `mountedAtMost`, `subtreeRebuiltAtMost`,
  `interactionHappened`, `matchesRebuildBaseline`) and `allowAbsent`, with
  the failure messages shown in the README and FAQ.
- Baseline files: the same JSON format (one object per key, one whole-number
  budget per type name, keys sorted, two-space indent) and the same paths,
  so files written by 0.2.0 and 0.1.x are read as they are.
- `UPDATE_REBUILD_BUDGETS`, `expectRebuildBudgetIsTestOnly` and
  `dart run rebuildcop:check`.

## 0.2.0

Renamed from `imaji_rebuild_budget`. The API is the same; only the package
name, its imports and the command change. `imaji_rebuild_budget` 0.1.1 is
the last release under the old name.

### Migration

- In `pubspec.yaml`, replace `imaji_rebuild_budget` under
  `dev_dependencies` with `rebuildcop: ^0.2.0`, or run
  `flutter pub remove imaji_rebuild_budget` and
  `flutter pub add --dev rebuildcop`.
- Replace `package:imaji_rebuild_budget/imaji_rebuild_budget.dart` with
  `package:rebuildcop/rebuildcop.dart`, and
  `package:imaji_rebuild_budget/guard.dart` with
  `package:rebuildcop/guard.dart`.
- Run the command-line check as `dart run rebuildcop:check`.
- Baseline files are unchanged: same JSON format, same paths.

### Behaviour changes

Type budgets no longer pass vacuously. Tests that passed only because their
widget type was never built now fail
([#22](https://github.com/saimskywalker/rebuildcop/issues/22)).

- `rebuiltAtMost(of:/named:)`, `mountedAtMost(of:)`,
  `subtreeRebuiltAtMost(of:)` and every type tracked by
  `matchesRebuildBaseline` fail when no element of that type existed while
  the window was open, naming the type and the window. That is usually a
  renamed or replaced widget, or a test that imports a same-named widget
  from a different library than the app (`package:flutter/material.dart`
  versus `package:material_ui/material_ui.dart`); the message says so when a
  same-named type was present. Pass `allowAbsent: true` to keep the old
  behaviour for one budget, or assert `findsNothing` for a widget that must
  never appear.
- `rebuiltAtMost(named:)` and a `named:` entry in `matchesRebuildBaseline`
  fail when two different types with that name rebuilt, instead of adding
  their counts together.
- `matchesRebuildBaseline` counts `types:` entries by exact type rather than
  by name, rejects two tracked entries with the same name, and does not write
  a baseline in update mode while one of its types is absent.
- `interactionHappened(rebuilt:)` says when the type was never there at all.
- Opening a window (`open` and `record`) throws a `StateError`
  unless the widgets binding is a `TestWidgetsFlutterBinding`, so a window
  can no longer be opened in a debug run of the app, for example from a
  debug menu. `LiveTestWidgetsFlutterBinding` and `integration_test` are
  still allowed
  ([#27](https://github.com/saimskywalker/rebuildcop/issues/27)).

### Added

- `allowAbsent` on `rebuiltAtMost`, `mountedAtMost`, `subtreeRebuiltAtMost`
  and `matchesRebuildBaseline`.
- `presentTypes` on the window: the widget types that had an element in the
  tree during the window, collected by the walks that already run at `open()`
  and `close()`.
- `package:rebuildcop/guard.dart` with
  `expectRebuildBudgetIsTestOnly`, a test for the app's own suite. It fails
  when the app lists this package under `dependencies` or imports or exports
  it from `lib/`, naming the file and line of each finding.
  `dev_dependencies` (pub.dev, path or git), `dependency_overrides`,
  workspace members, comments and imports from `test/` or `integration_test/`
  are fine. The pubspec is read without `package:yaml`, so there is no new
  dependency
  ([#27](https://github.com/saimskywalker/rebuildcop/issues/27)).
- `dart run rebuildcop:check [dir]`: the same check as a command,
  for a CI step that runs before `flutter test`.

## 0.1.1

Documentation only; no API or behaviour change.

- README: install from pub.dev (`flutter pub add --dev`) instead of git,
  with pub.dev version, points and likes badges. The git
  install stays as an option for unreleased `main`.
- README FAQ and dartdoc: render-object widgets (`ColoredBox`, `Padding`,
  `SizedBox`, ...) are mostly not counted. Flutter does not call
  `debugOnRebuildDirtyWidget` for them when a parent hands them a new widget
  or on their first build
  ([flutter/flutter#71626](https://github.com/flutter/flutter/issues/71626)).
  The FAQ previously said a parent's new widget instance always counts.
- The example declares the SDK it really needs (Dart 3.8, for
  `flutter_riverpod` 3) instead of the package's Dart 3.6 floor.

## 0.1.0

First release.

- The counting window over Flutter's
  `debugOnRebuildDirtyWidget` hook. Windows can overlap, keep and restore a
  previously installed hook, report a hook replaced mid-window, and fail a
  test that leaves one open. Mounts and rebuilds are counted apart.
  `record` wraps an interaction in a window.
- Matchers: `rebuiltAtMost` (by type, by name, or total),
  `subtreeRebuiltAtMost` (by finder), `mountedAtMost`.
- `interactionHappened`: proof that a window's interaction ran (a scroll
  offset moved, a fetch count or named counter changed, a type rebuilt).
- Failure output lists the busiest widget types with the budget beside each.
- Print mode (a `--dart-define` flag) prints every window's
  per-type counts and every measurement beside its budget.
- `matchesRebuildBaseline`: golden-style JSON budget files, rewritten with
  `--dart-define=UPDATE_REBUILD_BUDGETS=true`.
- Examples for setState, keys, Riverpod, Provider and Bloc.
