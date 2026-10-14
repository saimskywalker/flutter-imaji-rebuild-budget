import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'report.dart';

/// The counter name that [RebuildCounter.open]'s `fetchCount` callback is
/// stored under. Read it back with [RebuildCounter.counterDelta].
const String fetchCountName = 'fetchCount';

/// One build that Flutter reported while a [RebuildCounter] window was open.
///
/// A record is either a *rebuild* (an element that already existed built
/// again) or a *mount* (an element built for the first time inside the
/// window). Budgets are about rebuilds; mounts are kept separately because
/// a list that scrolls new rows into view is expected to mount them.
@immutable
class RebuildRecord {
  const RebuildRecord._({
    required this.element,
    required this.widget,
    required this.ancestors,
    required this.isMount,
  });

  /// The element that built.
  final Element element;

  /// The widget the element built with, captured at the moment it built.
  final Widget widget;

  /// The element's ancestors at the moment it built, nearest first.
  ///
  /// Captured eagerly because an element that is later unmounted can no
  /// longer be walked, while a subtree question may be asked after it was.
  final List<Element> ancestors;

  /// Whether this was the element's first build (a mount) rather than a
  /// rebuild.
  final bool isMount;

  /// The runtime type of [widget].
  Type get widgetType => widget.runtimeType;

  /// The name of [widgetType], as used in reports and baseline files.
  String get typeName => widget.runtimeType.toString();

  /// Whether this record's element is one of [roots] or sits below one.
  bool isWithin(Set<Element> roots) {
    if (roots.contains(element)) return true;
    for (final ancestor in ancestors) {
      if (roots.contains(ancestor)) return true;
    }
    return false;
  }
}

/// A counting window over Flutter's widget builds.
///
/// Open a window, run one interaction, close it, then assert on what was
/// rebuilt in between:
///
/// ```dart
/// final window = RebuildCounter.open(label: 'scroll the feed');
/// await tester.drag(find.byType(ListView), const Offset(0, -600));
/// await tester.pumpAndSettle();
/// window.close();
///
/// expect(window, interactionHappened(scrollOffsetMoved: find.byType(ListView)));
/// expect(window, rebuiltAtMost(2, of: TabBar));
/// ```
///
/// The window listens to [debugOnRebuildDirtyWidget], the framework hook
/// behind DevTools' "Track widget rebuilds", so the code under test needs no
/// keys, probes or counters. The hook only fires in debug builds, which is
/// what `flutter test` runs.
///
/// Every element already in the tree when the window opens is remembered, so
/// a later build of one of them counts as a rebuild and a build of anything
/// new counts as a mount.
///
/// Render-object widgets (`ColoredBox`, `Padding`, `SizedBox`, `RichText`,
/// ...) are mostly not counted. Flutter does not call the hook when a
/// parent hands a `RenderObjectElement` a new widget (its `update` calls
/// `updateRenderObject` without going through `Element.rebuild`), nor when
/// one is first mounted; only a changed inherited dependency reaches it. See
/// [flutter/flutter#71626](https://github.com/flutter/flutter/issues/71626).
/// Budget the widget that builds them instead.
///
/// Windows can overlap and nest. A hook that was installed before the first
/// window opened keeps receiving every call and is put back when the last
/// window closes. A window that is still open when its test ends is closed
/// and the test fails, so a forgotten [close] cannot leak the hook into the
/// next test.
class RebuildCounter {
  RebuildCounter._(this.label, Map<String, num Function()> counters)
      : _counters = Map.unmodifiable(counters);

  /// Opens a window and starts counting.
  ///
  /// Call it inside a test body (or `setUp`), after the widget under test
  /// has been pumped, and right before the interaction being measured.
  ///
  /// [label] names the window in failure messages, print-mode output and
  /// baseline files.
  ///
  /// [fetchCount] and [counters] are read when the window opens and again
  /// when it closes, so `interactionHappened(fetchCount: ...)` can prove
  /// that the interaction reached the code it was meant to reach. They are
  /// plain callbacks into test doubles; nothing in production code changes.
  static RebuildCounter open({
    String? label,
    num Function()? fetchCount,
    Map<String, num Function()> counters = const {},
  }) {
    if (!kDebugMode) {
      throw UnsupportedError(
        'RebuildCounter needs a debug build: Flutter only calls '
        'debugOnRebuildDirtyWidget when assertions are enabled.',
      );
    }
    if (fetchCount != null && counters.containsKey(fetchCountName)) {
      throw ArgumentError.value(
        counters,
        'counters',
        'must not contain "$fetchCountName" when fetchCount is also given',
      );
    }
    final window = RebuildCounter._(label, {
      ...counters,
      if (fetchCount != null) fetchCountName: fetchCount,
    });
    window._start();
    addTearDown(window._failIfLeftOpen);
    return window;
  }

  /// Opens a window, runs [interaction], and closes the window, even when
  /// [interaction] throws.
  ///
  /// The arguments mean the same as for [open].
  static Future<RebuildCounter> record(
    Future<void> Function() interaction, {
    String? label,
    num Function()? fetchCount,
    Map<String, num Function()> counters = const {},
  }) async {
    final window =
        open(label: label, fetchCount: fetchCount, counters: counters);
    try {
      await interaction();
    } finally {
      if (window.isOpen) window.close();
    }
    return window;
  }

  /// Whether print mode is on.
  ///
  /// In print mode every window prints its per-type counts when it closes,
  /// and every budget matcher prints the measured count beside its budget,
  /// so a budget can be set from a measurement instead of a guess. It
  /// defaults to `--dart-define=REBUILD_COUNTS=true`; a test file may also
  /// set it directly while a budget is being measured.
  static bool printCounts = const bool.fromEnvironment('REBUILD_COUNTS');

  /// Whether `matchesRebuildBaseline` rewrites baseline files with the
  /// measured counts instead of checking against them.
  ///
  /// Defaults to `--dart-define=UPDATE_REBUILD_BUDGETS=true`, the rebuild
  /// counterpart of `flutter test --update-goldens`. Never turn it on in
  /// CI: a baseline that rewrites itself can never fail.
  static bool updateBaselines =
      const bool.fromEnvironment('UPDATE_REBUILD_BUDGETS');

  /// The name given to [open], if any.
  final String? label;

  final Map<String, num Function()> _counters;
  final Map<String, num> _countersAtOpen = {};
  final Map<String, num> _countersAtClose = {};

  final Set<Element> _known = Set.identity();
  final List<RebuildRecord> _rebuilds = [];
  final List<RebuildRecord> _mounts = [];

  final Map<ScrollableState, double> _scrollAtOpen = Map.identity();
  final Map<ScrollableState, double> _scrollAtClose = Map.identity();

  bool _open = false;
  bool _closedOnce = false;

  /// Whether the window is still counting.
  bool get isOpen => _open;

  /// Every rebuild recorded in the window, in the order Flutter reported
  /// them.
  List<RebuildRecord> get rebuilds => List.unmodifiable(_rebuilds);

  /// Every mount (first build of a new element) recorded in the window.
  List<RebuildRecord> get mounts => List.unmodifiable(_mounts);

  /// The total number of rebuilds in the window.
  int get total => _rebuilds.length;

  /// Rebuilds of widgets whose runtime type is exactly [type].
  ///
  /// Subtypes are not included: a budget for `MyCard` says nothing about
  /// `MyFancyCard`.
  int countOf(Type type) => _rebuilds.where((r) => r.widgetType == type).length;

  /// Rebuilds of widgets whose runtime type is named [typeName].
  ///
  /// Use this for a type that is private to the library under test, such as
  /// `'_Header'`.
  int countNamed(String typeName) =>
      _rebuilds.where((r) => r.typeName == typeName).length;

  /// Rebuilds of widgets that satisfy [test], for telling instances of one
  /// type apart by a field.
  int countWhere(bool Function(Widget widget) test) =>
      _rebuilds.where((r) => test(r.widget)).length;

  /// Rebuilds of the elements found by [under] and of everything below
  /// them, optionally restricted to widgets of type [of].
  ///
  /// [under] is evaluated against the current tree, so ask before the
  /// subtree is unmounted. Throws a [StateError] when it finds nothing,
  /// because a subtree that is not there would always count zero.
  int countUnder(Finder under, {Type? of}) {
    final roots = resolveRoots(under);
    return _rebuilds
        .where((r) => (of == null || r.widgetType == of) && r.isWithin(roots))
        .length;
  }

  /// Mounts of widgets whose runtime type is exactly [type].
  int mountsOf(Type type) => _mounts.where((r) => r.widgetType == type).length;

  /// Rebuild counts grouped by widget type name, busiest first.
  ///
  /// Ties are broken by name so the order is stable between runs.
  Map<String, int> countsByType() => groupByType(_rebuilds);

  /// How much the counter called [name] changed between [open] and
  /// [close].
  ///
  /// Throws a [StateError] while the window is open, and an [ArgumentError]
  /// when no such counter was given to [open].
  num counterDelta(String name) {
    _requireClosed('read a counter');
    if (!_counters.containsKey(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'no counter with this name was given to RebuildCounter.open',
      );
    }
    return _countersAtClose[name]! - _countersAtOpen[name]!;
  }

  /// The names of the counters given to [open], including `fetchCount`.
  Iterable<String> get counterNames => _counters.keys;

  /// How far the [ScrollableState] that [scrollable] resolves to moved
  /// between [open] and [close], in logical pixels.
  ///
  /// [scrollable] may find a [Scrollable] itself, a scroll view that builds
  /// one (such as [ListView]), or any widget inside one. Returns `null` when
  /// no scrollable can be resolved, or when it was not on screen at both
  /// ends of the window.
  double? scrollDelta(Finder scrollable) {
    _requireClosed('read a scroll offset');
    for (final element in scrollable.evaluate()) {
      final state = scrollableFor(element);
      if (state == null) continue;
      final before = _scrollAtOpen[state];
      final after = _scrollAtClose[state];
      if (before == null || after == null) return null;
      return after - before;
    }
    return null;
  }

  /// A table of the busiest widget types in the window.
  ///
  /// Lists the [top] types by rebuild count, plus any type named in
  /// [budgets] even when it is not among them, with its budget beside it.
  /// [under] narrows the table to one subtree.
  String describeBusiest({
    int top = 10,
    Map<String, int> budgets = const {},
    Finder? under,
  }) {
    final records = under == null
        ? _rebuilds
        : _rebuilds.where((r) => r.isWithin(resolveRoots(under)));
    return busiestTable(records.toList(), top: top, budgets: budgets);
  }

  /// Stops counting and snapshots scroll offsets and counters.
  ///
  /// Throws a [StateError] if the window was already closed, or if
  /// [debugOnRebuildDirtyWidget] was replaced by someone else while the
  /// window was open, which means some builds were never reported and the
  /// counts cannot be trusted.
  void close() {
    if (!_open) {
      throw StateError(
        _closedOnce
            ? '${_name()} was already closed.'
            : '${_name()} is not open.',
      );
    }
    _finish();
    final intact = _Hook.detach(this);
    if (printCounts) {
      // ignore: avoid_print
      print(printReport(this));
    }
    if (!intact) {
      throw StateError(
        'debugOnRebuildDirtyWidget was replaced while ${_name()} was open, '
        'so its counts are incomplete. Do not set the hook directly while a '
        'RebuildCounter is counting.',
      );
    }
  }

  @override
  String toString() {
    final state = _open ? 'open' : 'closed';
    final name = label == null ? '' : '"$label", ';
    return 'RebuildCounter($name$state, ${_rebuilds.length} rebuilds, '
        '${_mounts.length} mounts)';
  }

  void _requireClosed(String action) {
    if (_open) {
      throw StateError(
        'Cannot $action while ${_name()} is still open. Call close() first, '
        'so frames pumped after the interaction cannot change the result.',
      );
    }
  }

  String _name() => label == null ? 'the rebuild window' : 'window "$label"';

  void _start() {
    final root = WidgetsBinding.instance.rootElement;
    if (root != null) {
      _known.add(root);
      _walk(root, (element) {
        _known.add(element);
        _snapshotScroll(element, _scrollAtOpen);
      });
    }
    _counters.forEach((name, read) => _countersAtOpen[name] = read());
    _open = true;
    _Hook.attach(this);
  }

  void _finish() {
    _open = false;
    _closedOnce = true;
    final root = WidgetsBinding.instance.rootElement;
    if (root != null) {
      _walk(root, (element) => _snapshotScroll(element, _scrollAtClose));
    }
    _counters.forEach((name, read) => _countersAtClose[name] = read());
  }

  void _onBuild(Element element) {
    if (!_open) return;
    final isMount = _known.add(element);
    final ancestors = <Element>[];
    element.visitAncestorElements((ancestor) {
      ancestors.add(ancestor);
      return true;
    });
    final record = RebuildRecord._(
      element: element,
      widget: element.widget,
      ancestors: List.unmodifiable(ancestors),
      isMount: isMount,
    );
    (isMount ? _mounts : _rebuilds).add(record);
  }

  String? _closeIfLeftOpen() {
    if (!_open) return null;
    _finish();
    _Hook.detach(this);
    return '${_name()} was opened but never closed. Call close() after the '
        'interaction (or use RebuildCounter.record) so the counting hook is '
        'released before the next test.';
  }

  void _failIfLeftOpen() {
    final message = _closeIfLeftOpen();
    if (message != null) fail(message);
  }

  static void _walk(Element parent, void Function(Element) visit) {
    parent.visitChildren((child) {
      visit(child);
      _walk(child, visit);
    });
  }

  static void _snapshotScroll(
    Element element,
    Map<ScrollableState, double> into,
  ) {
    if (element is StatefulElement && element.state is ScrollableState) {
      final state = element.state as ScrollableState;
      final position = state.position;
      if (position.hasPixels) into[state] = position.pixels;
    }
  }
}

/// The elements that [finder] currently finds, as an identity set.
///
/// Throws a [StateError] when it finds none.
Set<Element> resolveRoots(Finder finder) {
  final roots = Set<Element>.identity()..addAll(finder.evaluate());
  if (roots.isEmpty) {
    throw StateError(
      'Found no ${finder.describeMatch(Plurality.zero)}, so there is no '
      'subtree to '
      'count. A subtree budget over nothing would always pass.',
    );
  }
  return roots;
}

/// The [ScrollableState] that [element] stands for: its own, the first one
/// below it, or the nearest one above it.
ScrollableState? scrollableFor(Element element) {
  ScrollableState? own(Element e) =>
      e is StatefulElement && e.state is ScrollableState
          ? e.state as ScrollableState
          : null;

  final self = own(element);
  if (self != null) return self;

  final queue = <Element>[element];
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    final found = own(current);
    if (found != null) return found;
    current.visitChildren(queue.add);
  }
  return element.findAncestorStateOfType<ScrollableState>();
}

/// Closes [window] if its test left it open, and returns the failure message
/// the test would report; `null` when it was already closed.
///
/// Not exported: the package's own tests use it to check the end-of-test
/// guard without failing a test on purpose.
String? closeLeftOpenWindow(RebuildCounter window) => window._closeIfLeftOpen();

/// Fans [debugOnRebuildDirtyWidget] out to every open window.
///
/// One dispatcher is installed while at least one window is open, so
/// windows may open and close in any order. Whatever hook was installed
/// before the first window opened keeps receiving every call, and is put
/// back when the last window closes.
abstract final class _Hook {
  static final List<RebuildCounter> _windows = [];
  static RebuildDirtyWidgetCallback? _previous;
  static bool _replaced = false;

  static void _dispatch(Element element, bool builtOnce) {
    _previous?.call(element, builtOnce);
    for (final window in List.of(_windows)) {
      window._onBuild(element);
    }
  }

  static final RebuildDirtyWidgetCallback _installed = _dispatch;

  static bool get _intact => identical(debugOnRebuildDirtyWidget, _installed);

  static void attach(RebuildCounter window) {
    if (_windows.isEmpty) {
      _previous = debugOnRebuildDirtyWidget;
      _replaced = false;
      debugOnRebuildDirtyWidget = _installed;
    } else if (!_intact) {
      _replaced = true;
    }
    _windows.add(window);
  }

  /// Removes [window]; returns whether the dispatcher stayed installed for
  /// the whole time any window was open.
  static bool detach(RebuildCounter window) {
    _windows.remove(window);
    if (!_intact) _replaced = true;
    final intact = !_replaced;
    if (_windows.isEmpty) {
      if (_intact) debugOnRebuildDirtyWidget = _previous;
      _previous = null;
      _replaced = false;
    }
    return intact;
  }
}
