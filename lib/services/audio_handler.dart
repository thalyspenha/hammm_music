import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show debugPrint, listEquals;
import 'package:just_audio/just_audio.dart';
import '../theme/app_theme.dart';

Future<HammmAudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => HammmAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.hammm.music.channel.audio',
      androidNotificationChannelName: 'Hammm Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_notification',
      notificationColor: AppTheme.accent,
    ),
  );
}

class HammmAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  // `maxSkipsOnError`: faixa que falha ao carregar (arquivo corrompido,
  // formato não suportado) é pulada automaticamente; após esse número de
  // falhas seguidas o player só pausa.
  final _player = AudioPlayer(maxSkipsOnError: 5);
  // Última sequência (ordem efetiva) enviada para `queue`.
  List<IndexedAudioSource>? _lastQueueSources;
  // Índice (ordem original) pedido em `setPlaylist` enquanto a fila carrega.
  // Ver o listener de `sequenceStateStream`.
  int? _pendingInitialIndex;
  // Faixas que falharam ao tocar (arquivo corrompido, formato não suportado).
  // O player já pula para a próxima; o provider só avisa o usuário.
  final _failures = StreamController<MediaItem>.broadcast();
  Stream<MediaItem> get failures => _failures.stream;

  HammmAudioHandler() {
    // Desde o just_audio 0.10 os erros de reprodução vão para `errorStream`
    // (não mais como evento de erro deste stream), inclusive o de
    // carregamento da faixa inicial.
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.errorStream.listen((e) {
      debugPrint('Erro no player: $e');
      final index = e.index;
      final sequence = _player.sequence;
      if (index != null && index >= 0 && index < sequence.length) {
        _failures.add(sequence[index].tag as MediaItem);
      }
    });

    // A faixa atual vem de `currentSource` (e não de `currentIndex`):
    // `currentIndex` é a posição na ordem original, enquanto `queue` expõe a
    // ordem efetiva (embaralhada quando o shuffle está ligado).
    _player.sequenceStateStream.listen((state) {
      if (!_isConsistent(state)) return;
      // `sequenceStateStream` emite a cada troca de faixa, mas a fila só
      // muda quando a sequência (ou a ordem do shuffle) muda. Reenviar a
      // fila inteira à MediaSession a cada troca custa uma serialização
      // proporcional à biblioteca (risco de TransactionTooLargeException).
      final sources = state.effectiveSequence;
      if (!listEquals(sources, _lastQueueSources)) {
        _lastQueueSources = List.of(sources);
        queue.add(sources.map((s) => s.tag as MediaItem).toList());
      }
      // Ao carregar uma fila nova, a sequência chega antes de o
      // `initialIndex` ser aplicado (currentIndex 0 por um instante). Sem
      // este filtro, tela, notificação e extração de cor piscavam com a
      // primeira música da lista antes da faixa tocada.
      final pending = _pendingInitialIndex;
      if (pending != null) {
        if (state.currentIndex != pending) return;
        _pendingInitialIndex = null;
      }
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

  // Ao carregar uma fila nova com o shuffle ligado, `sequenceStateStream`
  // (que combina vários streams) emite por um instante a sequência nova com
  // os índices de shuffle da fila anterior; `effectiveSequence` lançaria
  // RangeError. O evento seguinte já vem consistente, então este é só
  // ignorado.
  static bool _isConsistent(SequenceState state) {
    final length = state.sequence.length;
    if (!state.shuffleModeEnabled) return true;
    final indices = state.shuffleIndices;
    return indices.length == length && indices.every((i) => i < length);
  }

  Future<void> _rewindAfterCompletion() async {
    await _player.pause();
    final first = _player.effectiveIndices.firstOrNull;
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
    if (order.isEmpty) return index;
    final pos = order.indexOf(index);
    return pos < 0 ? null : pos;
  }

  // `queue` e `mediaItem` são atualizados por `sequenceStateStream` depois
  // que a fonte é carregada.
  Future<void> setPlaylist(List<MediaItem> items, int initialIndex) async {
    if (items.isEmpty) return;
    _pendingInitialIndex = initialIndex;
    try {
      await _player.setAudioSources(
        items
            .map((item) => AudioSource.uri(Uri.file(item.id), tag: item))
            .toList(),
        initialIndex: initialIndex,
      );
    } on PlayerException catch (e) {
      // Faixa inicial não carregou: o erro também chega por `errorStream`
      // (aviso ao usuário) e `maxSkipsOnError` já avança para a próxima.
      debugPrint('Erro ao carregar a fila: $e');
      if (items.length == 1) return;
    } finally {
      _pendingInitialIndex = null;
    }
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
    if (index < 0 || index >= order.length) return;
    await _player.seek(Duration.zero, index: order[index]);
    await play();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}
