import 'package:flutter/widgets.dart';

/// Receives every element that builds while it is attached to [HookRelay].
typedef BuildListener = void Function(Element element);

/// Shares Flutter's single [debugOnRebuildDirtyWidget] slot between any
/// number of open windows.
///
/// The relay takes the slot when the first listener attaches and hands it
/// back when the last one detaches. A callback that was in the slot before
/// keeps receiving every call in between and is put back afterwards.
class HookRelay {
  HookRelay._();

  /// The relay for this isolate.
  static final HookRelay shared = HookRelay._();

  final List<BuildListener> _listeners = [];

  /// The callback that was in the slot when the relay took it.
  RebuildDirtyWidgetCallback? _displaced;

  /// The relay's own callback, kept as one object so the slot can be
  /// compared with it by identity.
  late final RebuildDirtyWidgetCallback _entry = _dispatch;

  bool _holdsSlot = false;

  /// Starts sending builds to [listener].
  void attach(BuildListener listener) {
    if (!_holdsSlot) {
      _displaced = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = _entry;
      _holdsSlot = true;
    }
    _listeners.add(listener);
  }

  /// Stops sending builds to [listener].
  ///
  /// Returns false when something else took the slot while [listener] was
  /// attached, which means [listener] may have missed builds. The relay then
  /// leaves the slot alone, because the callback in it is not its own.
  bool detach(BuildListener listener) {
    _listeners.remove(listener);
    final intact = _holdsSlot && identical(debugOnRebuildDirtyWidget, _entry);
    if (_listeners.isEmpty && _holdsSlot) {
      if (intact) {
        debugOnRebuildDirtyWidget = _displaced;
      }
      _displaced = null;
      _holdsSlot = false;
    }
    return intact;
  }

  void _dispatch(Element element, bool builtOnce) {
    for (final listener in List.of(_listeners)) {
      listener(element);
    }
    _displaced?.call(element, builtOnce);
  }
}
