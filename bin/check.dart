// `dart run rebuildcop:check [package directory]`: the
// expectRebuildBudgetIsTestOnly check as a command, for a CI step that runs
// before flutter test. It imports nothing from Flutter, so it runs on the
// plain Dart VM.
import 'dart:io';

import 'package:rebuildcop/src/guard_io.dart';

void main(List<String> args) => exit(runGuardCheck(args));
