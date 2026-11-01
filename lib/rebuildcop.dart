/// Rebuild budgets for Flutter widget tests.
///
/// Open a `RebuildWindow` around an interaction, close it, and assert on it
/// with `rebuiltAtMost`, `subtreeRebuiltAtMost`, `mountedAtMost`,
/// `interactionHappened` and `matchesRebuildBaseline`.
///
/// Import this library from tests only: it depends on `flutter_test`.
library;

export 'src/tally/build_record.dart' show AncestorSnapshot, BuildRecord;
export 'src/tally/rebuild_window.dart' show RebuildWindow;
export 'src/verdict/baseline/baseline_matcher.dart' show matchesRebuildBaseline;
export 'src/verdict/budgets.dart'
    show mountedAtMost, rebuiltAtMost, subtreeRebuiltAtMost;
export 'src/verdict/proof.dart' show interactionHappened;
