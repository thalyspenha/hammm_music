import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart' show Color;
import 'package:just_audio/just_audio.dart';

Future<HammmAudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => HammmAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.hammm.music.channel.audio',
      androidNotificationChannelName: 'Hammm Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      notificationColor: Color(0xFF7C6AFF),
    ),
  );
}

class HammmAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final _player = AudioPlayer();

  HammmAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    _player.currentIndexStream.listen((index) {
      final q = queue.value;
      if (index != null && index < q.length) {
        mediaItem.add(q[index]);
      }
    });

    _player.sequenceStateStream.listen((state) {
      if (state != null) {
        final items = state.effectiveSequence
            .map((s) => s.tag as MediaItem)
            .toList();
        queue.add(items);
      }
    });
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  Future<void> setPlaylist(List<MediaItem> items, int initialIndex) async {
    queue.add(items);
    final source = ConcatenatingAudioSource(
      children: items
          .map((item) => AudioSource.uri(Uri.file(item.id), tag: item))
          .toList(),
    );
    await _player.setAudioSource(source, initialIndex: initialIndex);
    mediaItem.add(items[initialIndex]);
    await play();
  }

  void setLoopMode(LoopMode mode) => _player.setLoopMode(mode);
  void setShuffleModeEnabled(bool enabled) =>
      _player.setShuffleModeEnabled(enabled);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  AudioPlayer get player => _player;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    await _player.seek(Duration.zero, index: index);
    await play();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}
