import 'package:flutter/widgets.dart';

/// A search result.
class Result {
  /// Creates a result.
  const Result(this.id, this.title);

  /// A stable identifier.
  final int id;

  /// What the row shows.
  final String title;
}

/// Ten results, used by both screens.
final List<Result> results = List.unmodifiable([
  for (var i = 0; i < 10; i++) Result(i, 'Result $i'),
]);

/// Results that can be re-sorted. With [stableKeys] off, every row gets a
/// `UniqueKey()` in `build` (BEFORE); with it on, a `ValueKey` of the
/// result's id (AFTER).
class SortableResults extends StatefulWidget {
  /// Creates the list.
  const SortableResults({super.key, required this.stableKeys});

  /// Whether rows are keyed by their result's id.
  final bool stableKeys;

  @override
  State<SortableResults> createState() => SortableResultsState();
}

/// State for [SortableResults]; [reverse] flips the order.
class SortableResultsState extends State<SortableResults> {
  bool _newestFirst = false;

  /// Flips the sort order.
  void reverse() => setState(() => _newestFirst = !_newestFirst);

  @override
  Widget build(BuildContext context) {
    final ordered = _newestFirst ? results.reversed : results;
    return Column(
      children: [
        for (final result in ordered)
          ResultTile(
            result,
            // BEFORE: a new key every build tears down every row's State.
            key: widget.stableKeys ? ValueKey(result.id) : UniqueKey(),
          ),
      ],
    );
  }
}

/// A row with its own state (imagine an image loading or an animation).
class ResultTile extends StatefulWidget {
  /// Creates the row.
  const ResultTile(this.result, {super.key});

  /// The result shown.
  final Result result;

  @override
  State<ResultTile> createState() => _ResultTileState();
}

class _ResultTileState extends State<ResultTile> {
  @override
  Widget build(BuildContext context) => Text(widget.result.title);
}
