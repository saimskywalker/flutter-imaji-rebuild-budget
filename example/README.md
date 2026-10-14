# imaji_rebuild_budget examples

Each test file here pairs a Flutter widget that rebuilds too much
(**BEFORE**) with its fix (**AFTER**), and shows `imaji_rebuild_budget`
telling the two apart. Run them with:

```sh
cd example
flutter test
flutter test --dart-define=REBUILD_COUNTS=true   # print every measured count
```

| File | Over-rebuild | Fix |
|---|---|---|
| [`test/set_state_test.dart`](test/set_state_test.dart) | A clock ticks with `setState` at the screen root, rebuilding every product tile once a second | Move the clock into its own widget and make the list `const` |
| [`test/set_state_test.dart`](test/set_state_test.dart) | `UniqueKey()` in `build` remounts every row on a re-sort | `ValueKey(result.id)` |
| [`test/riverpod_test.dart`](test/riverpod_test.dart) | `ref.watch(cartProvider)` rebuilds an item badge when a coupon is applied | `ref.watch(cartProvider.select((c) => c.items.length))` |
| [`test/provider_test.dart`](test/provider_test.dart) | `context.watch<ReaderSettings>()` rebuilds a text-size label on a theme change | `context.select<ReaderSettings, double>((s) => s.fontSize)` |
| [`test/bloc_test.dart`](test/bloc_test.dart) | A `BlocBuilder` redraws a file name on every download progress tick | `BlocSelector` on the name |

The shape of every test:

```dart
testWidgets('AFTER: ref.watch(cartProvider.select(...)) leaves it alone',
    (tester) async {
  await tester.pumpWidget(/* the screen */);

  final window = RebuildCounter.open(label: 'apply a coupon');
  container.read(cartProvider.notifier).applyCoupon('SPRING');
  await tester.pump();
  window.close();

  // Proof the interaction ran, so a zero below means something.
  expect(window, interactionHappened(rebuilt: CouponLabel));
  // The budget.
  expect(window, rebuiltAtMost(0, of: CartBadgeFast));
});
```

The state libraries are dependencies of this example only;
`imaji_rebuild_budget` itself depends on nothing but Flutter.
