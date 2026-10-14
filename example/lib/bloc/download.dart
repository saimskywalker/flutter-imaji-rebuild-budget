import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A file being downloaded.
@immutable
class Download {
  /// Creates a download state.
  const Download({required this.fileName, this.percent = 0});

  /// The file's name.
  final String fileName;

  /// How much has arrived, from 0 to 100.
  final int percent;
}

/// Emits a new [Download] every time more of the file arrives.
class DownloadCubit extends Cubit<Download> {
  /// Starts downloading [fileName].
  DownloadCubit(String fileName) : super(Download(fileName: fileName));

  /// Records ten more percent of the file.
  void progress() => emit(
    Download(
      fileName: state.fileName,
      percent: (state.percent + 10).clamp(0, 100),
    ),
  );
}

/// The file name. Its own widget never rebuilds; what happens inside it is
/// the point.
class FileNameText extends StatelessWidget {
  /// Creates the name; [selective] picks the AFTER version.
  const FileNameText({super.key, required this.selective});

  /// Whether to rebuild only when the file name changes.
  final bool selective;

  @override
  Widget build(BuildContext context) {
    if (selective) {
      // AFTER: rebuilds only when the selected name changes.
      return BlocSelector<DownloadCubit, Download, String>(
        selector: (state) => state.fileName,
        builder: (context, name) => Text(name),
      );
    }
    // BEFORE: rebuilds on every progress tick to draw a name that did not
    // change.
    return BlocBuilder<DownloadCubit, Download>(
      builder: (context, state) => Text(state.fileName),
    );
  }
}

/// The progress; it is meant to rebuild on every tick.
class ProgressText extends StatelessWidget {
  /// Creates the label.
  const ProgressText({super.key});

  @override
  Widget build(BuildContext context) {
    final percent = context.select<DownloadCubit, int>(
      (cubit) => cubit.state.percent,
    );
    return Text('$percent%');
  }
}
