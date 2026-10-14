# Changelog

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
