# Examples

[`example/`](https://github.com/saimskywalker/flutter-imaji-rebuild-budget/tree/main/example) pairs real over-rebuilds with their fixes, each as a
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
