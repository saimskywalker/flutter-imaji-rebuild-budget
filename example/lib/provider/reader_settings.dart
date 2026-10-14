import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Settings for an article reader.
class ReaderSettings extends ChangeNotifier {
  double _fontSize = 16;
  bool _darkMode = false;

  /// The body text size.
  double get fontSize => _fontSize;

  /// Whether the dark theme is on.
  bool get darkMode => _darkMode;

  /// Sets the body text size.
  set fontSize(double value) {
    _fontSize = value;
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
class FontSizeLabelSlow extends StatelessWidget {
  /// Creates the label.
  const FontSizeLabelSlow({super.key});

  @override
  Widget build(BuildContext context) {
    final size = context.watch<ReaderSettings>().fontSize;
    return Text('Text size ${size.round()}');
  }
}

/// AFTER: `context.select` rebuilds the label only when the size changes.
class FontSizeLabelFast extends StatelessWidget {
  /// Creates the label.
  const FontSizeLabelFast({super.key});

  @override
  Widget build(BuildContext context) {
    final size = context.select<ReaderSettings, double>((s) => s.fontSize);
    return Text('Text size ${size.round()}');
  }
}

/// Shows the theme; it is meant to rebuild when the theme changes.
class ThemeLabel extends StatelessWidget {
  /// Creates the label.
  const ThemeLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.select<ReaderSettings, bool>((s) => s.darkMode);
    return Text(dark ? 'Dark' : 'Light');
  }
}
