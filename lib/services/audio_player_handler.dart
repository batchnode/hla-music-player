import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:async';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _audioPlayer;
  final AndroidEqualizer _equalizer;
  bool _stopOnDisconnect = true;

  final _skipToNextController = StreamController<void>.broadcast();
  final _skipToPreviousController = StreamController<void>.broadcast();

  Stream<void> get skipToNextStream => _skipToNextController.stream;
  Stream<void> get skipToPreviousStream => _skipToPreviousController.stream;

  AudioPlayerHandler(this._audioPlayer, this._equalizer) {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Handle "becoming noisy" (e.g. headphone unplugged)
    session.becomingNoisyEventStream.listen((_) {
      if (_stopOnDisconnect) {
        pause();
      }
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
          },
          androidCompactActionIndices: const [
            0, // Index of MediaControl.skipToPrevious
            1, // Index of MediaControl.play/pause
            2, // Index of MediaControl.skipToNext
          ], // For next, play/pause, previous
          processingState: {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[processingState]!,
          playing: isPlaying,
          updatePosition: _audioPlayer.position,
          bufferedPosition: _audioPlayer.bufferedPosition,
          speed: _audioPlayer.speed,
        ),
      );
    });

    _audioPlayer.sequenceStateStream.listen((sequenceState) {
      if (sequenceState.currentSource != null) {
        final item = sequenceState.currentSource!.tag as MediaItem;
        mediaItem.add(
          item.copyWith(duration: sequenceState.currentSource!.duration),
        );
      }
    });
  }

  @override
  Future<void> play() => _audioPlayer.play();

  @override
  Future<void> pause() => _audioPlayer.pause();

  @override
  Future<void> stop() => _audioPlayer.stop();

  Future<void> setVolume(double volume) => _audioPlayer.setVolume(volume);

  void setStopOnDisconnect(bool stop) {
    _stopOnDisconnect = stop;
  }

  Future<void> setEqualizerEnabled(bool enabled) =>
      _equalizer.setEnabled(enabled);

  Future<void> setEqualizerBand(int index, double gain) async {
    final parameters = await _equalizer.parameters;
    final band = parameters.bands[index];
    await band.setGain(gain);
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
    // Add a new playback state with the updated position immediately
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

  // You might want to implement custom actions for next/previous if your queue logic is complex
  // For now, these rely on JustAudio's internal queue management
  @override
  Future<void> skipToNext() async {
    _skipToNextController.add(null);
  }

  @override
  Future<void> skipToPrevious() async {
    _skipToPreviousController.add(null);
  }

  // Custom method to update the audio source from MusicProvider
  Future<void> updateAudioSource(MediaItem newMediaItem, String? uri) async {
    mediaItem.add(
      newMediaItem,
    ); // Update the current media item for audio_service
    try {
      if (uri != null) {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(Uri.parse(uri), tag: newMediaItem),
        );
      } else {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
            ),
            tag: newMediaItem,
          ),
        );
      }
    } catch (e) {
      // Handle error
    }
  }
}
