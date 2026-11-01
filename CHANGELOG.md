# Changelog

## Unreleased

### Behaviour changes

Type budgets no longer pass vacuously. Tests that passed only because their
widget type was never built now fail
([#22](https://github.com/saimskywalker/flutter-imaji-rebuild-budget/issues/22)).

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

### Added

- `allowAbsent` on `rebuiltAtMost`, `mountedAtMost`, `subtreeRebuiltAtMost`
  and `matchesRebuildBaseline`.
- `RebuildCounter.presentTypes`: the widget types that had an element in the
  tree during the window, collected by the walks that already run at `open()`
  and `close()`.

## 0.1.1

Documentation only; no API or behaviour change.

- README: install from pub.dev (`flutter pub add --dev imaji_rebuild_budget`)
  instead of git, with pub.dev version, points and likes badges. The git
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

- `RebuildCounter`: a counting window over Flutter's
  `debugOnRebuildDirtyWidget` hook. Windows can overlap, keep and restore a
  previously installed hook, report a hook replaced mid-window, and fail a
  test that leaves one open. Mounts and rebuilds are counted apart.
  `RebuildCounter.record` wraps an interaction in a window.
- Matchers: `rebuiltAtMost` (by type, by name, or total),
  `subtreeRebuiltAtMost` (by finder), `mountedAtMost`.
- `interactionHappened`: proof that a window's interaction ran (a scroll
  offset moved, a fetch count or named counter changed, a type rebuilt).
- Failure output lists the busiest widget types with the budget beside each.
- Print mode (`--dart-define=REBUILD_COUNTS=true`) prints every window's
  per-type counts and every measurement beside its budget.
- `matchesRebuildBaseline`: golden-style JSON budget files, rewritten with
  `--dart-define=UPDATE_REBUILD_BUDGETS=true`.
- Examples for setState, keys, Riverpod, Provider and Bloc.
