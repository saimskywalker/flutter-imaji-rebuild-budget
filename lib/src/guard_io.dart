import 'dart:io';

import 'guard_scan.dart';

/// The nearest directory at or above [start] that has a `pubspec.yaml`,
/// or `null` if there is none.
String? findPackageRoot(String start) {
  if (!Directory(start).existsSync()) return null;
  var dir = Directory(Directory(start).resolveSymbolicLinksSync());
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

/// Checks the package at [root]: its `pubspec.yaml`, and every `.dart` file
/// under its `lib/`.
///
/// Only `lib/` is compiled into the app, so `test/`, `integration_test/`,
/// `tool/` and the rest are not read. Throws a [StateError] when [root] has
/// no `pubspec.yaml`.
List<GuardFinding> checkPackage(String root) {
  final pubspec = File('$root/pubspec.yaml');
  if (!pubspec.existsSync()) {
    throw StateError('No pubspec.yaml in $root, so it is not a package root.');
  }
  final findings = [...checkPubspec(pubspec.readAsStringSync())];
  final lib = Directory('$root/lib');
  if (lib.existsSync()) {
    final files = lib
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final relative = file.path
          .substring(root.length)
          .replaceAll(r'\', '/')
          .replaceFirst(RegExp('^/+'), '');
      findings.addAll(checkLibSource(file.readAsStringSync(), relative));
    }
  }
  return findings;
}

/// Runs [checkPackage] for the command-line check and returns its exit code:
/// 0 when the package is clean (or for `--help`), 1 when something was
/// found, 2 on a usage error.
///
/// [args] is empty (check the package the command runs in, found by walking
/// up from the working directory) or one package directory.
int runGuardCheck(List<String> args, {StringSink? out, StringSink? err}) {
  out ??= stdout;
  err ??= stderr;
  final help = args.length == 1 && (args[0] == '-h' || args[0] == '--help');
  if (help || args.length > 1 || args.any((arg) => arg.startsWith('-'))) {
    (help ? out : err)
      ..writeln('Usage: dart run $guardedPackage:check [package directory]')
      ..writeln()
      ..writeln('Fails if the package lists $guardedPackage under '
          'dependencies or imports it from lib/.');
    return help ? 0 : 2;
  }
  final root = args.isEmpty ? findPackageRoot('.') : args.single;
  if (root == null || !File('$root/pubspec.yaml').existsSync()) {
    err.writeln(
      args.isEmpty
          ? 'No pubspec.yaml in this directory or any directory above it.'
          : 'No pubspec.yaml in $root.',
    );
    return 2;
  }
  final findings = checkPackage(root);
  if (findings.isEmpty) {
    out.writeln(
      '$root: $guardedPackage is a dev dependency only and is not imported '
      'from lib/.',
    );
    return 0;
  }
  err.writeln(describeFindings(root, findings));
  return 1;
}
