import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
      androidNotificationIcon: 'drawable/ic_notification',
      notificationColor: Color(0xFF7C6AFF),
    ),
  );
}

class HammmAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final _player = AudioPlayer();

  HammmAudioHandler() {
    // Erros de reprodução (ex.: arquivo apagado) chegam também como evento
    // de erro neste stream. Sem o handleError, o pipe os repassa ao
    // `playbackState` e cada ouvinte sem `onError` (provider, audio_service)
    // gera um "Unhandled Exception". O erro já é tratado em `playSong`.
    _player.playbackEventStream
        .map(_transformEvent)
        .handleError((Object e) => debugPrint('Erro no player: $e'))
        .pipe(playbackState);

    // A faixa atual vem de `currentSource` (e não de `currentIndex`):
    // `currentIndex` é a posição na ordem original, enquanto `queue` expõe a
    // ordem efetiva (embaralhada quando o shuffle está ligado).
    _player.sequenceStateStream.listen((state) {
      if (state == null) return;
      queue.add(
          state.effectiveSequence.map((s) => s.tag as MediaItem).toList());
      final current = state.currentSource?.tag as MediaItem?;
      if (current != null && current != mediaItem.value) {
        mediaItem.add(current);
      }
    });

    // Fim da fila (sem repeat): o just_audio mantém `playing == true` no
    // estado `completed`, o que deixa a UI em "tocando" e o play sem efeito.
    // Pausa e volta ao início da fila para o próximo play recomeçar.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _rewindAfterCompletion();
    });
  }

  Future<void> _rewindAfterCompletion() async {
    await _player.pause();
    final first = _player.effectiveIndices?.firstOrNull;
    if (first != null) await _player.seek(Duration.zero, index: first);
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
      queueIndex: _toQueueIndex(event.currentIndex),
    );
  }

  // Converte índice da ordem original (`sequence`) para índice da fila
  // exposta (`effectiveSequence`).
  int? _toQueueIndex(int? index) {
    if (index == null) return null;
    final order = _player.effectiveIndices;
    if (order == null) return index;
    final pos = order.indexOf(index);
    return pos < 0 ? null : pos;
  }

  // `queue` e `mediaItem` são atualizados por `sequenceStateStream` depois
  // que a fonte é carregada.
  Future<void> setPlaylist(List<MediaItem> items, int initialIndex) async {
    if (items.isEmpty) return;
    final source = ConcatenatingAudioSource(
      children: items
          .map((item) => AudioSource.uri(Uri.file(item.id), tag: item))
          .toList(),
    );
    await _player.setAudioSource(source, initialIndex: initialIndex);
    await play();
  }

  void setLoopMode(LoopMode mode) => _player.setLoopMode(mode);
  Future<void> setShuffleModeEnabled(bool enabled) async {
    // Reembaralha com a faixa atual na primeira posição, para que nenhuma
    // faixa fique "antes" dela na ordem embaralhada (e seja pulada).
    if (enabled) await _player.shuffle();
    await _player.setShuffleModeEnabled(enabled);
  }
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  AudioPlayer get player => _player;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  // Não chama `super.stop()`: ele faz `playbackState.add(...)`, que lança
  // StateError porque `playbackState` já recebe o `pipe` do player. O
  // `_player.stop()` emite o estado idle pelo próprio pipe.
  @override
  Future<void> stop() async {
    await _player.stop();
    await playbackState.firstWhere(
        (state) => state.processingState == AudioProcessingState.idle);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  // Comportamento padrão de players: depois dos primeiros segundos, "anterior"
  // volta ao início da faixa atual; só perto do início vai para a anterior.
  static const _restartThreshold = Duration(seconds: 3);

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > _restartThreshold || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    // `index` é a posição na fila exposta (ordem efetiva); o `seek` espera a
    // posição na ordem original.
    final order = _player.effectiveIndices;
    if (order == null || index < 0 || index >= order.length) return;
    await _player.seek(Duration.zero, index: order[index]);
    await play();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}
