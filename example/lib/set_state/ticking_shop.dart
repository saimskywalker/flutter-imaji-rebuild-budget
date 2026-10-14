import 'dart:async';

import 'package:flutter/widgets.dart';

/// The products every shop screen lists.
const List<String> products = ['Lamp', 'Chair', 'Desk', 'Rug', 'Shelf'];

/// BEFORE: a clock ticks with `setState` at the root of the screen, so every
/// second the whole product list is rebuilt to redraw one line of text.
class TickingShopSlow extends StatefulWidget {
  /// Creates the slow screen.
  const TickingShopSlow({super.key});

  @override
  State<TickingShopSlow> createState() => _TickingShopSlowState();
}

class _TickingShopSlowState extends State<TickingShopSlow> {
  late final Timer _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _seconds++),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClockText(_seconds),
        // Not const, and rebuilt with the clock every second.
        // ignore: prefer_const_constructors
        ProductList(),
      ],
    );
  }
}

/// AFTER: the clock owns its own state and the list is `const`, so a tick
/// rebuilds the clock and nothing else.
class TickingShopFast extends StatelessWidget {
  /// Creates the fast screen.
  const TickingShopFast({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(children: [LiveClock(), ProductList()]);
  }
}

/// A clock that ticks once a second without touching its parent.
class LiveClock extends StatefulWidget {
  /// Creates the clock.
  const LiveClock({super.key});

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late final Timer _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _seconds++),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClockText(_seconds);
}

/// Shows how many seconds have passed.
class ClockText extends StatelessWidget {
  /// Creates the label.
  const ClockText(this.seconds, {super.key});

  /// Seconds since the screen opened.
  final int seconds;

  @override
  Widget build(BuildContext context) => Text('Open for ${seconds}s');
}

/// The list of [products].
class ProductList extends StatelessWidget {
  /// Creates the list.
  const ProductList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [for (final name in products) ProductTile(name)]);
  }
}

/// One product row.
class ProductTile extends StatelessWidget {
  /// Creates a row for [name].
  const ProductTile(this.name, {super.key});

  /// The product's name.
  final String name;

  @override
  Widget build(BuildContext context) => Text(name);
}
