import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What is playing and how far into it.
@immutable
class Playback {
  /// Creates a playback state.
  const Playback({required this.title, this.position = Duration.zero});

  /// The track title.
  final String title;

  /// How far into the track playback is.
  final Duration position;
}

/// Emits a new [Playback] every time the position advances.
class PlaybackCubit extends Cubit<Playback> {
  /// Starts playing [title].
  PlaybackCubit(String title) : super(Playback(title: title));

  /// Advances the position by one second.
  void tick() => emit(Playback(
        title: state.title,
        position: state.position + const Duration(seconds: 1),
      ));
}

/// The track title. Its own widget never rebuilds; what happens inside it
/// is the point.
class TrackTitle extends StatelessWidget {
  /// Creates the title; [selective] picks the AFTER version.
  const TrackTitle({super.key, required this.selective});

  /// Whether to rebuild only when the title changes.
  final bool selective;

  @override
  Widget build(BuildContext context) {
    if (selective) {
      // AFTER: rebuilds only when the selected title changes.
      return BlocSelector<PlaybackCubit, Playback, String>(
        selector: (state) => state.title,
        builder: (context, title) => Text(title),
      );
    }
    // BEFORE: rebuilds on every position tick to draw a title that did not
    // change.
    return BlocBuilder<PlaybackCubit, Playback>(
      builder: (context, state) => Text(state.title),
    );
  }
}

/// The position; it is meant to rebuild on every tick.
class PositionText extends StatelessWidget {
  /// Creates the label.
  const PositionText({super.key});

  @override
  Widget build(BuildContext context) {
    final seconds = context.select<PlaybackCubit, int>(
      (cubit) => cubit.state.position.inSeconds,
    );
    return Text('${seconds}s');
  }
}
