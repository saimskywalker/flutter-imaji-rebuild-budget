/// A test that keeps `rebuildcop` out of the app.
///
/// The package depends on `flutter_test`, so it belongs in
/// `dev_dependencies` and must never be imported from `lib/`, or test code
/// is compiled into release builds. Add one test to the app's suite to
/// enforce that:
///
/// ```dart
/// // test/rebuild_budget_guard_test.dart
/// import 'package:flutter_test/flutter_test.dart';
/// import 'package:rebuildcop/guard.dart';
///
/// void main() =>
///     test('rebuild budgets stay out of the app', expectRebuildBudgetIsTestOnly);
/// ```
///
/// To check before `flutter test` runs, for example as an early CI step, use
/// `dart run rebuildcop:check`, which does the same.
library;

import 'package:flutter_test/flutter_test.dart';

import 'src/guard_scan.dart';
import 'src/guard_stub.dart' if (dart.library.io) 'src/guard_io.dart';

/// Fails the test if the app lists `rebuildcop` under
/// `dependencies` or imports it from `lib/`.
///
/// It reads the app's `pubspec.yaml` and every `.dart` file under `lib/`,
/// and the failure names the file and line of each finding:
///
/// ```text
/// rebuildcop must stay out of the app in /work/shop: it depends
/// on flutter_test, and every dependency and every import from lib/ is
/// compiled into release builds.
///   pubspec.yaml:14: rebuildcop is under dependencies, ...
///   lib/debug_menu.dart:3: imports package:rebuildcop/...
/// ```
///
/// `dev_dependencies` (from pub.dev, a path or git) and
/// `dependency_overrides` are fine, and so are imports from `test/`,
/// `integration_test/` or anywhere else outside `lib/`. Comments that
/// mention the package are not imports. In a pub workspace, put this test
/// in each package that depends on `rebuildcop`.
///
/// The app is the package around the running test file: the nearest
/// directory above it with a `pubspec.yaml`. Pass [packageRoot] to check a
/// different package directory; that throws a [StateError] if it has no
/// `pubspec.yaml`. It needs a file system, so it throws an
/// [UnsupportedError] under `flutter test --platform chrome`.
void expectRebuildBudgetIsTestOnly({String? packageRoot}) {
  final root = packageRoot ?? findPackageRoot(_testFileDirectory());
  if (root == null) {
    fail('No pubspec.yaml above ${_testFileDirectory()}; pass packageRoot.');
  }
  final findings = checkPackage(root);
  if (findings.isNotEmpty) fail(describeFindings(root, findings));
}

/// The directory of the running test file, the way golden files are
/// resolved, falling back to the working directory.
String _testFileDirectory() {
  final comparator = goldenFileComparator;
  return comparator is LocalFileComparator
      ? comparator.basedir.toFilePath()
      : '.';
}
