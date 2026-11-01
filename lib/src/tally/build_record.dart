import 'package:flutter/widgets.dart';

/// A widget that enclosed a [BuildRecord] when it was built.
///
/// The [widget] is captured at build time, so it stays readable after the
/// element has been unmounted.
@immutable
class AncestorSnapshot {
  /// Captures [element] and its current widget.
  AncestorSnapshot(this.element) : widget = element.widget;

  /// The ancestor element. It may have been unmounted since.
  final Element element;

  /// The ancestor's widget at the time of the build.
  final Widget widget;

  @override
  String toString() => 'AncestorSnapshot(${widget.runtimeType})';
}

/// One call of [debugOnRebuildDirtyWidget] seen by a rebuild window.
@immutable
class BuildRecord {
  /// Captures [element] as it builds.
  ///
  /// [isMount] is true for the element's first build inside the window.
  BuildRecord(this.element, {required this.isMount})
      : widget = element.widget,
        ancestors = _ancestorsOf(element);

  /// The element that built. It may have been unmounted since.
  final Element element;

  /// The widget the element built from.
  final Widget widget;

  /// True for an element built for the first time inside the window; false
  /// for an element that already existed building again.
  final bool isMount;

  /// The enclosing widgets at the time of the build, nearest first.
  final List<AncestorSnapshot> ancestors;

  /// The exact runtime type of [widget].
  Type get widgetType => widget.runtimeType;

  /// The name of [widgetType], as shown in failure messages.
  String get typeName => typeLabel(widgetType);

  /// Whether this build happened at [root] or anywhere below it.
  bool isWithin(Element root) =>
      identical(element, root) ||
      ancestors.any((ancestor) => identical(ancestor.element, root));

  @override
  String toString() =>
      'BuildRecord($typeName, ${isMount ? 'mount' : 'rebuild'})';

  static List<AncestorSnapshot> _ancestorsOf(Element element) {
    final chain = <AncestorSnapshot>[];
    element.visitAncestorElements((ancestor) {
      chain.add(AncestorSnapshot(ancestor));
      return true;
    });
    return List.unmodifiable(chain);
  }
}

/// The name a widget type is reported under.
String typeLabel(Type type) => '$type';
