// The file access behind matchesRebuildBaseline: dart:io on the VM, an
// UnsupportedError on the web.
export 'baseline_file_web.dart' if (dart.library.io) 'baseline_file_vm.dart';
