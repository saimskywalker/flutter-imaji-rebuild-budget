import 'package:flutter/widgets.dart';

/// One of two unrelated widgets named `Tile` (the other is in
/// `tile_b.dart`), like the `TabBar` in `package:flutter/material.dart` and
/// the one in `package:material_ui/material_ui.dart`.
class Tile extends StatelessWidget {
  const Tile(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text);
}
