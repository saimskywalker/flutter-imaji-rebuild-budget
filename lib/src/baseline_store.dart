/// Where a baseline file lives and how it is read and written.
///
/// The `dart:io` version is used wherever files exist; on the web there is
/// no file system, so every operation throws [UnsupportedError].
library;

export 'baseline_store_stub.dart' if (dart.library.io) 'baseline_store_io.dart';
