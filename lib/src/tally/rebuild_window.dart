import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../output/type_table.dart';
import 'build_record.dart';
import 'hook_relay.dart';
import 'tree_survey.dart';

/// The counter name [RebuildWindow.open] gives its `fetchCount` callback.
const String fetchCountName = 'fetchCount';

/// A counting window over Flutter's [debugOnRebuildDirtyWidget] hook.
///
/// Open one right before an interaction and close it right after; every
/// widget built in between is recorded, mounts apart from rebuilds:
///
/// ```dart
/// final window = RebuildWindow.open(label: 'scroll the feed');
/// await tester.drag(find.byType(ListView), const Offset(0, -600));
/// await tester.pumpAndSettle();
/// window.close();
///
/// expect(window, rebuiltAtMost(0, of: TabBar));
/// ```
///
/// Windows may overlap and close in any order. A window still open when its
/// test ends is closed and fails the test.
class RebuildWindow {
  RebuildWindow._(this.label, this._counters, this._before)
      : _known = HashSet<Element>.identity()..addAll(_before.elements);

  /// Starts counting.
  ///
  /// Call it after the widget is pumped, right before the interaction.
  /// [label] names the window in failure messages. [fetchCount] and
  /// [counters] are read now and again at [close]; see [counterDelta].
  ///
  /// Throws a [StateError] unless the widgets binding is a
  /// [TestWidgetsFlutterBinding], so a window can only open under
  /// `flutter test`.
  static RebuildWindow open({
    String? label,
    int Function()? fetchCount,
    Map<String, int Function()> counters = const {},
  }) {
    if (fetchCount != null && counters.containsKey(fetchCountName)) {
      throw ArgumentError.value(
        counters,
        'counters',
        'must not contain "$fetchCountName" when fetchCount is passed',
      );
    }
    _requireTestBinding();
    final readers = <String, int Function()>{
      if (fetchCount != null) fetchCountName: fetchCount,
      ...counters,
    };
    final window = RebuildWindow._(label, readers, TreeSurvey.now());
    window._start();
    return window;
  }

  /// Opens a window, runs [interaction] and closes the window, also when
  /// [interaction] throws.
  static Future<RebuildWindow> record(
    Future<void> Function() interaction, {
    String? label,
    int Function()? fetchCount,
    Map<String, int Function()> counters = const {},
  }) async {
    final window =
        open(label: label, fetchCount: fetchCount, counters: counters);
    try {
      await interaction();
    } finally {
      if (window.isOpen) {
        window.close();
      }
    }
    return window;
  }

  /// Print mode: when true, every window prints its per-type counts when it
  /// closes and every budget matcher prints its measurement.
  ///
  /// Defaults to `--dart-define=PRINT_REBUILDS=true`.
  static bool printCounts = const bool.fromEnvironment('PRINT_REBUILDS');

  /// Baseline update mode: when true, `matchesRebuildBaseline` writes the
  /// measured counts instead of comparing against them.
  ///
  /// Defaults to `--dart-define=UPDATE_REBUILD_BUDGETS=true`.
  static bool updateBaselines =
      const bool.fromEnvironment('UPDATE_REBUILD_BUDGETS');

  /// The name of this window in messages, if it was given one.
  final String? label;

  final Map<String, int Function()> _counters;
  final Map<String, int> _countersAtOpen = {};
  final Map<String, int> _countersAtClose = {};
  final TreeSurvey _before;
  TreeSurvey? _after;
  final Set<Element> _known;
  final List<BuildRecord> _records = [];
  final Set<Type> _builtTypes = {};
  bool _open = false;

  void _start() {
    for (final entry in _counters.entries) {
      _countersAtOpen[entry.key] = entry.value();
    }
    HookRelay.shared.attach(_onBuild);
    _open = true;
    addTearDown(() {
      final message = closeAbandonedWindow(this);
      if (message != null) {
        fail(message);
      }
    });
  }

  void _onBuild(Element element) {
    final isMount = _known.add(element);
    _records.add(BuildRecord(element, isMount: isMount));
    _builtTypes.add(element.widget.runtimeType);
  }

  /// Whether the window is still counting.
  bool get isOpen => _open;

  /// Stops counting and snapshots scroll offsets and counters.
  ///
  /// Throws a [StateError] if the window was already closed, or if
  /// something replaced [debugOnRebuildDirtyWidget] while it was open, which
  /// means the counts are incomplete.
  void close() {
    if (!_open) {
      throw StateError(
        'close() was called twice: ${windowPhrase(this)} was already closed.',
      );
    }
    _open = false;
    final intact = HookRelay.shared.detach(_onBuild);
    _after = TreeSurvey.now();
    for (final entry in _counters.entries) {
      _countersAtClose[entry.key] = entry.value();
    }
    if (!intact) {
      throw StateError(
        'debugOnRebuildDirtyWidget was replaced while ${windowPhrase(this)} '
        'was open, so its counts are incomplete. Do not set that hook, or '
        'turn on rebuild tracking in DevTools, while a window is open.',
      );
    }
    if (printCounts) {
      // ignore: avoid_print
      print(_closingSummary());
    }
  }

  String _closingSummary() {
    final rebuildCount = rebuilds.length;
    final mountCount = mounts.length;
    final out = StringBuffer(
      '$printTag ${label == null ? 'rebuild window' : 'window "$label"'}: '
      '$rebuildCount ${plural(rebuildCount, 'rebuild')}, '
      '$mountCount ${plural(mountCount, 'mount')}',
    );
    final rows = tallyByName(rebuilds);
    final width = rows.isEmpty ? 0 : '${rows.first.value}'.length;
    for (final row in rows) {
      out.write('\n  ${'${row.value}'.padLeft(width)}  ${row.key}');
    }
    for (final name in counterNames) {
      out.write('\n  counter $name changed by ${counterDelta(name)}');
    }
    return out.toString();
  }

  /// Every build of an element that already existed: it was in the tree
  /// when the window opened, or was mounted earlier in the window.
  List<BuildRecord> get rebuilds =>
      List.unmodifiable(_records.where((r) => !r.isMount));

  /// Every first build of an element inside the window.
  List<BuildRecord> get mounts =>
      List.unmodifiable(_records.where((r) => r.isMount));

  /// The number of [rebuilds].
  int get total => _records.where((r) => !r.isMount).length;

  /// Rebuilds of widgets whose runtime type is exactly [type].
  int countOf(Type type) => countWhere((w) => w.runtimeType == type);

  /// Rebuilds of widgets whose type is called [typeName], for private types.
  int countNamed(String typeName) =>
      _records.where((r) => !r.isMount && r.typeName == typeName).length;

  /// Rebuilds of widgets for which [test] returns true.
  int countWhere(bool Function(Widget widget) test) =>
      _records.where((r) => !r.isMount && test(r.widget)).length;

  /// Mounts of widgets whose runtime type is exactly [type].
  int mountsOf(Type type) =>
      _records.where((r) => r.isMount && r.widgetType == type).length;

  /// Rebuilds at and below every widget [under] finds, or only those of
  /// type [of] when it is given.
  ///
  /// Throws a [StateError] when [under] finds nothing.
  int countUnder(Finder under, {Type? of}) {
    final found = buildsUnder(this, under);
    if (found == null) {
      throw StateError(
        'countUnder: found no ${under.describeMatch(Plurality.many)}.',
      );
    }
    return found.where((r) => of == null || r.widgetType == of).length;
  }

  /// The widget types that had an element in the tree while the window was
  /// open: when it opened, when it closed, or built in between.
  Set<Type> get presentTypes => Set.unmodifiable({
        ..._before.types,
        ..._builtTypes,
        ...?_after?.types,
      });

  /// Rebuild counts per type name, busiest first, ties in name order.
  Map<String, int> countsByType() => Map.fromEntries(tallyByName(rebuilds));

  /// The busiest-types table used in failure messages.
  ///
  /// [budgets] maps type names to a budget shown beside that type. [under]
  /// narrows the table to one subtree.
  String describeBusiest({
    int top = 10,
    Map<String, int> budgets = const {},
    Finder? under,
  }) {
    var records = rebuilds;
    if (under != null) {
      records = buildsUnder(this, under) ?? const [];
    }
    return formatTypeTable(records, top: top, budgets: budgets);
  }

  /// The names of the counters given to [open], `fetchCount` included.
  Iterable<String> get counterNames => _counters.keys;

  /// How much counter [name] changed between [open] and [close].
  ///
  /// Throws a [StateError] while the window is open and an [ArgumentError]
  /// for a counter [open] was not given.
  int counterDelta(String name) {
    if (!_counters.containsKey(name)) {
      throw ArgumentError.value(name, 'name', 'no counter with this name');
    }
    _requireClosed('counterDelta');
    return _countersAtClose[name]! - _countersAtOpen[name]!;
  }

  /// How far the scrollable at, inside or around what [finder] finds moved
  /// between [open] and [close].
  ///
  /// Null when [finder] finds nothing, there is no scrollable there, or the
  /// scrollable was not in the tree at both ends of the window.
  double? scrollDelta(Finder finder) {
    _requireClosed('scrollDelta');
    final target = scrollableFor(finder).scrollable;
    if (target == null) {
      return null;
    }
    return scrollMovement(this, target);
  }

  void _requireClosed(String member) {
    if (_open) {
      throw StateError(
        '$member is only known once ${windowPhrase(this)} is closed.',
      );
    }
  }

  @override
  String toString() {
    final parts = [
      if (label != null) '"$label"',
      _open ? 'open' : 'closed',
      '$total ${plural(total, 'rebuild')}',
      '${mounts.length} ${plural(mounts.length, 'mount')}',
    ];
    return 'RebuildWindow(${parts.join(', ')})';
  }
}

/// `window "label"`, or `the rebuild window` without a label.
String windowPhrase(RebuildWindow window) =>
    window.label == null ? 'the rebuild window' : 'window "${window.label}"';

/// The builds at and below every element [under] finds, or null when it
/// finds nothing.
List<BuildRecord>? buildsUnder(
  RebuildWindow window,
  Finder under, {
  bool mounts = false,
}) {
  final roots = under.evaluate().toList();
  if (roots.isEmpty) {
    return null;
  }
  return [
    for (final record in window._records)
      if (record.isMount == mounts && roots.any(record.isWithin)) record,
  ];
}

/// How far [scrollable] moved during [window], or null when it was not in
/// the tree both when the window opened and when it closed.
double? scrollMovement(RebuildWindow window, ScrollableState scrollable) {
  final start = window._before.scrollOffsets[scrollable];
  final end = window._after?.scrollOffsets[scrollable];
  if (start == null || end == null) {
    return null;
  }
  return end - start;
}

/// Closes [window] if it is still open and returns the failure for a window
/// its test never closed; returns null for a closed window.
String? closeAbandonedWindow(RebuildWindow window) {
  if (!window.isOpen) {
    return null;
  }
  final phrase = windowPhrase(window);
  try {
    window.close();
  } on StateError {
    // Closing is all that matters here; the failure below says why.
  }
  return '$phrase was opened but never closed, so it was closed when its '
      'test ended. Call close() right after the interaction, or use '
      'RebuildWindow.record.';
}

void _requireTestBinding() {
  const lead = 'rebuildcop only runs under flutter test. It must be a '
      'dev_dependency and must not be imported from lib/.';
  WidgetsBinding? binding;
  try {
    binding = WidgetsBinding.instance;
  } catch (_) {
    binding = null;
  }
  if (binding == null) {
    throw StateError(
      '$lead No widgets binding is initialized: open windows inside '
      'testWidgets, which sets up a TestWidgetsFlutterBinding.',
    );
  }
  if (binding is! TestWidgetsFlutterBinding) {
    throw StateError(
      '$lead The binding is ${binding.runtimeType}, not a '
      'TestWidgetsFlutterBinding.',
    );
  }
}
