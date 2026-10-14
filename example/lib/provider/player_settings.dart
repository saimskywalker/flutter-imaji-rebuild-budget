import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Settings for a music player.
class PlayerSettings extends ChangeNotifier {
  double _volume = 0.5;
  bool _darkMode = false;

  /// The volume, from 0 to 1.
  double get volume => _volume;

  /// Whether the dark theme is on.
  bool get darkMode => _darkMode;

  /// Sets the volume.
  set volume(double value) {
    _volume = value;
    notifyListeners();
  }

  /// Flips the theme.
  void toggleDarkMode() {
    _darkMode = !_darkMode;
    notifyListeners();
  }
}

/// BEFORE: `context.watch` rebuilds the label on every change to the
/// settings, including the theme it does not show.
class VolumeLabelSlow extends StatelessWidget {
  /// Creates the label.
  const VolumeLabelSlow({super.key});

  @override
  Widget build(BuildContext context) {
    final volume = context.watch<PlayerSettings>().volume;
    return Text('Volume ${(volume * 100).round()}%');
  }
}

/// AFTER: `context.select` rebuilds the label only when the volume changes.
class VolumeLabelFast extends StatelessWidget {
  /// Creates the label.
  const VolumeLabelFast({super.key});

  @override
  Widget build(BuildContext context) {
    final volume = context.select<PlayerSettings, double>((s) => s.volume);
    return Text('Volume ${(volume * 100).round()}%');
  }
}

/// Shows the theme; it is meant to rebuild when the theme changes.
class ThemeLabel extends StatelessWidget {
  /// Creates the label.
  const ThemeLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.select<PlayerSettings, bool>((s) => s.darkMode);
    return Text(dark ? 'Dark' : 'Light');
  }
}
