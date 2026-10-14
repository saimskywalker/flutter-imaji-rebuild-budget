import 'package:flutter/material.dart';

import 'set_state/ticking_shop.dart';

/// Runs the fixed shop screen. The interesting part of this example is in
/// `test/`: each file pairs an over-rebuilding widget (BEFORE) with its fix
/// (AFTER) and shows imaji_rebuild_budget telling them apart.
void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(body: SafeArea(child: TickingShopFast())),
    ),
  );
}
