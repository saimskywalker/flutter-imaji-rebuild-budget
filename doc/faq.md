# FAQ and comparison

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
and 3.47.7. The [`example/`](https://github.com/saimskywalker/flutter-imaji-rebuild-budget/tree/main/example) app needs Flutter 3.32 (Dart 3.8) or
newer, because `flutter_riverpod` 3 does; CI runs it on 3.47.7.

## Comparison

| | Headless in `flutter test` | Fails a test | No code in `lib/` | Points at the widget |
|---|---|---|---|---|
| **imaji_rebuild_budget** | yes | yes | yes | yes, busiest types |
| DevTools "Track widget rebuilds" | no, interactive | no | yes | yes |
| `debugPrintRebuildDirtyWidgets` | yes | no, a log to read | yes | yes, unaggregated |
| `integration_test` + `traceAction` / frame timings | no, needs a device | yes, on timings | yes | no |
| Hand-written counters in `build()` | yes | yes | no | only where added |

## Installing by hand or from `main`

By hand in `pubspec.yaml`:

```yaml
dev_dependencies:
  imaji_rebuild_budget: ^0.1.0
```

To try unreleased changes from `main` instead of a published version (it can
change under you):

```yaml
dev_dependencies:
  imaji_rebuild_budget:
    git: https://github.com/saimskywalker/flutter-imaji-rebuild-budget
```
