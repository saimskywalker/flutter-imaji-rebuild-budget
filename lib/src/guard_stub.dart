import 'guard_scan.dart';

Never _unsupported() => throw UnsupportedError(
      'The rebuild budget guard reads pubspec.yaml and lib/, so it needs a '
      'file system (dart:io). Run it on the Dart VM, which is what plain '
      '`flutter test` does.',
    );

/// The nearest directory at or above [start] that has a `pubspec.yaml`.
String? findPackageRoot(String start) => _unsupported();

/// Checks the package at [root].
List<GuardFinding> checkPackage(String root) => _unsupported();
