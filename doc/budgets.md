# Measuring budgets and baseline files

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
