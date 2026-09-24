import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, MemoryImage, Size;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/audio_handler.dart';

enum RepeatMode { none, one, all }

enum SortField { title, artist, album }

// Limite de entradas em cache de URLs de capa — evita crescimento sem
// limite do SharedPreferences em bibliotecas muito grandes.
const _maxArtworkCacheEntries = 500;

// Buscas no iTunes sem capa compatível ficam em cache negativo por este
// período, para não repetir a requisição a cada vez que a faixa toca.
const _artworkMissTtl = Duration(days: 7);

const _platformChannel = MethodChannel('com.hammm.music/platform');

// Normaliza para comparação: minúsculas, só letras e dígitos (com acentos).
String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

bool _looselyMatches(String a, String b) {
  final na = _normalize(a);
  final nb = _normalize(b);
  if (na.isEmpty || nb.isEmpty) return false;
  return na.contains(nb) || nb.contains(na);
}

/// Mapeia IDs antigos para novos pelo caminho do arquivo. Para cada ID de
/// [referenced] que não existe mais na biblioteca, procura o caminho salvo em
/// [knownPaths]; se houver música com esse caminho na biblioteca atual
/// ([libraryIdsByPath]), o ID antigo é mapeado para o novo. Cobre o caso do
/// MediaStore reindexar a biblioteca e trocar os IDs dos mesmos arquivos.
@visibleForTesting
Map<int, int> remapIdsByPath(
  Iterable<int> referenced,
  Map<int, String> knownPaths,
  Map<String, int> libraryIdsByPath,
) {
  final validIds = libraryIdsByPath.values.toSet();
  final remap = <int, int>{};
  for (final id in referenced) {
    if (validIds.contains(id)) continue;
    final path = knownPaths[id];
    final newId = path == null ? null : libraryIdsByPath[path];
    if (newId != null) remap[id] = newId;
  }
  return remap;
}

/// URL da capa (500x500) do primeiro resultado da iTunes Search API cujo
/// artista e título batem com a faixa, ou `null` se nenhum bater. Aceita
/// variações como "Faixa (Remastered)" ou "Artista feat. Outro".
@visibleForTesting
String? pickArtworkUrl(
  List<Map<String, dynamic>> results, {
  required String artist,
  required String title,
}) {
  for (final r in results) {
    final url = r['artworkUrl100'];
    final rArtist = r['artistName'];
    final rTitle = r['trackName'];
    if (url is! String || rArtist is! String || rTitle is! String) continue;
    if (_looselyMatches(rArtist, artist) && _looselyMatches(rTitle, title)) {
      return url.replaceAll('100x100bb', '500x500bb');
    }
  }
  return null;
}

// Acima desta fração de IDs referenciados sumindo de uma vez, a poda de
// órfãos é adiada: indica MediaStore incompleto (cartão SD desmontado,
// indexação em andamento) e não músicas apagadas pelo usuário.
const _maxOrphanFraction = 0.5;

/// IDs de [referenced] que devem ser removidos por não existirem mais em
/// [valid]. Retorna vazio quando a biblioteca parece incompleta — ver
/// [_maxOrphanFraction].
@visibleForTesting
Set<int> orphanIdsToPrune(Set<int> referenced, Set<int> valid) {
  if (valid.isEmpty || referenced.isEmpty) return {};
  final orphans = referenced.difference(valid);
  if (orphans.length > referenced.length * _maxOrphanFraction) return {};
  return orphans;
}

class PlayerProvider extends ChangeNotifier {
  final HammmAudioHandler _handler;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<Song> _songs = [];
  List<Song> _displaySongs = [];
  Song? _currentSong;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasPermission = false;
  bool _permissionPermanentlyDenied = false;
  bool _isShuffle = false;
  RepeatMode _repeatMode = RepeatMode.none;
  // Posição fica fora do `notifyListeners()`: o stream emite várias vezes
  // por segundo e reconstruiria a árvore inteira. Só o seekbar e o mini
  // player escutam este notifier.
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  Duration _duration = Duration.zero;
  String _searchQuery = '';
  double _speed = 1.0;
  Timer? _sleepTimer;
  Timer? _sleepCountdown;
  DateTime? _sleepTimerEnd;
  final ValueNotifier<Duration?> _sleepTimerRemaining = ValueNotifier(null);
  Color? _paletteAccent;
  SortField _sortField = SortField.title;
  final Set<int> _favorites = {};
  // Caminho do arquivo de cada favorito (songId → path), para reconciliar
  // quando os IDs do MediaStore mudam. Ver [remapIdsByPath].
  final Map<int, String> _favoritePaths = {};
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<bool>? _permissionRequest;
  final List<Playlist> _playlists = [];
  final Map<int, String> _artworkUrlCache = {};
  // songId → instante (ms desde epoch) da última busca sem resultado.
  final Map<int, int> _artworkMissCache = {};
  final StreamController<String> _errors = StreamController.broadcast();
  Permission? _mediaPermission;
  late final Future<void> _favoritesLoaded;
  late final Future<void> _playlistsLoaded;
  late final Future<void> _artworkCacheLoaded;

  PlayerProvider(this._handler) {
    _subscribeToStreams();
    _favoritesLoaded = _loadFavorites();
    _playlistsLoaded = _loadPlaylists();
    _artworkCacheLoaded = _loadArtworkUrlCache();
    _loadPlaybackPrefs();
  }

  List<Song> get songs => _displaySongs.isEmpty && _searchQuery.isEmpty
      ? _songs
      : _displaySongs;
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  bool get isPermissionPermanentlyDenied => _permissionPermanentlyDenied;
  bool get isShuffle => _isShuffle;
  RepeatMode get repeatMode => _repeatMode;
  Duration get position => _position.value;
  ValueListenable<Duration> get positionListenable => _position;
  Duration get duration => _duration;
  int get totalSongs => _songs.length;
  SortField get sortField => _sortField;
  Set<int> get favorites => Set.unmodifiable(_favorites);
  List<Playlist> get playlists => List.unmodifiable(_playlists);

  /// Mensagens de erro para exibir ao usuário (ex.: SnackBar).
  Stream<String> get errors => _errors.stream;

  bool isFavorited(int id) => _favorites.contains(id);
  String? getArtworkUrl(int songId) => _artworkUrlCache[songId];

  double get speed => _speed;
  Color? get paletteAccent => _paletteAccent;
  bool get hasSleepTimer => _sleepTimer?.isActive == true;

  // Atualizado a cada segundo sem `notifyListeners()`, pelo mesmo motivo
  // de `positionListenable`.
  ValueListenable<Duration?> get sleepTimerRemaining => _sleepTimerRemaining;

  void _updateSleepTimerRemaining() {
    final end = _sleepTimerEnd;
    if (end == null) {
      _sleepTimerRemaining.value = null;
      return;
    }
    final remaining = end.difference(DateTime.now());
    _sleepTimerRemaining.value =
        remaining.isNegative ? Duration.zero : remaining;
  }

  List<MediaItem> get currentQueue => _handler.queue.value;

  int get currentQueueIndex =>
      _handler.queue.value.indexWhere((m) => m.id == _currentSong?.path);

  double get progress => progressAt(_position.value);

  double progressAt(Duration position) {
    if (_duration.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  void _subscribeToStreams() {
    _subscriptions.add(
        _handler.positionStream.listen((pos) => _position.value = pos));

    _subscriptions.add(_handler.durationStream.listen((dur) {
      if (dur != null && dur != _duration) {
        _duration = dur;
        notifyListeners();
      }
    }));

    _subscriptions.add(_handler.playbackState.listen((state) {
      final playing = state.playing;
      if (playing != _isPlaying) {
        _isPlaying = playing;
        notifyListeners();
      }
    }));

    _subscriptions.add(_handler.mediaItem.listen((item) {
      if (item != null) {
        final matched = _songs.where((s) => s.path == item.id).firstOrNull;
        if (matched != null && matched != _currentSong) {
          _currentSong = matched;
          notifyListeners();
          _loadPaletteForSong(matched);
        }
      }
    }));
  }

  // Android 13+ (API 33) usa READ_MEDIA_AUDIO; abaixo, READ_EXTERNAL_STORAGE.
  // Pede só a permissão da versão atual: a outra não está no manifest
  // daquela versão e o permission_handler a reporta como negada
  // permanentemente, o que levaria direto a "Abrir Configurações".
  Future<Permission> _resolveMediaPermission() async {
    if (_mediaPermission != null) return _mediaPermission!;
    int? sdk;
    try {
      sdk = await _platformChannel.invokeMethod<int>('sdkInt');
    } catch (e) {
      debugPrint('Erro ao obter versão do Android: $e');
    }
    return _mediaPermission =
        (sdk ?? 33) >= 33 ? Permission.audio : Permission.storage;
  }

  // Chamadas concorrentes (ex.: botão "Permitir Acesso" tocado com o diálogo
  // inicial ainda aberto) reaproveitam o pedido em andamento — o
  // permission_handler lança PlatformException se dois pedidos se sobrepõem.
  Future<bool> requestPermission() => _permissionRequest ??=
      _requestPermission().whenComplete(() => _permissionRequest = null);

  Future<bool> _requestPermission() async {
    final permission = await _resolveMediaPermission();
    final status = await permission.request();
    _hasPermission = status.isGranted;
    // Negada com "não perguntar de novo" (ou negada 2x): o sistema para de
    // mostrar o diálogo nativo — só resta redirecionar às configurações.
    _permissionPermanentlyDenied = status.isPermanentlyDenied;
    notifyListeners();
    return _hasPermission;
  }

  Future<bool> openPermissionSettings() => openAppSettings();

  // Chamado quando o app volta ao primeiro plano: detecta permissão
  // concedida nas Configurações do sistema (sem abrir diálogo) e carrega a
  // biblioteca.
  Future<void> refreshPermission() async {
    if (_hasPermission) return;
    final permission = await _resolveMediaPermission();
    if (!(await permission.status).isGranted) return;
    _hasPermission = true;
    _permissionPermanentlyDenied = false;
    notifyListeners();
    await loadSongs();
  }

  Future<void> loadSongs() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final models = await _audioQuery.querySongs(
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      // filtra faixas com menos de 30 segundos (ringtones, efeitos)
      _songs = models
          .where((m) => (m.duration ?? 0) > 30000)
          .map(Song.fromSongModel)
          .toList();

      _applySortAndFilter();
      await _reconcileByPath();
      await _pruneOrphans();
    } catch (e) {
      debugPrint('Erro ao carregar músicas: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Atualiza IDs de favoritos/playlists que mudaram (mesmo arquivo, ID novo
  // após reindexação do MediaStore) e preenche o caminho de IDs válidos que
  // ainda não o tinham (dados salvos antes deste campo existir). Roda antes
  // de `_pruneOrphans`, para que IDs recuperáveis não sejam podados.
  Future<void> _reconcileByPath() async {
    await _favoritesLoaded;
    await _playlistsLoaded;

    final idsByPath = {for (final s in _songs) s.path: s.id};
    final pathsById = {for (final s in _songs) s.id: s.path};

    var favoritesChanged = false;
    final favRemap = remapIdsByPath(_favorites, _favoritePaths, idsByPath);
    favRemap.forEach((oldId, newId) {
      _favorites
        ..remove(oldId)
        ..add(newId);
      _favoritePaths.remove(oldId);
      favoritesChanged = true;
    });
    for (final id in _favorites) {
      final path = pathsById[id];
      if (path != null && _favoritePaths[id] != path) {
        _favoritePaths[id] = path;
        favoritesChanged = true;
      }
    }

    var playlistsChanged = false;
    for (final playlist in _playlists) {
      final remap =
          remapIdsByPath(playlist.songIds, playlist.songPaths, idsByPath);
      if (remap.isNotEmpty) {
        final seen = <int>{};
        playlist.songIds = [
          for (final id in playlist.songIds)
            if (seen.add(remap[id] ?? id)) remap[id] ?? id,
        ];
        remap.keys.forEach(playlist.songPaths.remove);
        playlistsChanged = true;
      }
      for (final id in playlist.songIds) {
        final path = pathsById[id];
        if (path != null && playlist.songPaths[id] != path) {
          playlist.songPaths[id] = path;
          playlistsChanged = true;
        }
      }
    }

    if (favoritesChanged) await _saveFavorites();
    if (playlistsChanged) await _savePlaylists();
    if (favRemap.isNotEmpty || playlistsChanged) notifyListeners();
  }

  // Remove de favoritos/playlists IDs de músicas que não existem mais na
  // biblioteca atual do MediaStore (ex.: arquivo apagado do dispositivo).
  Future<void> _pruneOrphans() async {
    await _favoritesLoaded;
    await _playlistsLoaded;

    final referenced = {
      ..._favorites,
      for (final playlist in _playlists) ...playlist.songIds,
    };
    final orphans =
        orphanIdsToPrune(referenced, _songs.map((s) => s.id).toSet());
    if (orphans.isEmpty) return;

    final orphanFavorites = _favorites.intersection(orphans);
    if (orphanFavorites.isNotEmpty) {
      _favorites.removeAll(orphanFavorites);
      orphanFavorites.forEach(_favoritePaths.remove);
      await _saveFavorites();
    }

    var playlistsChanged = false;
    for (final playlist in _playlists) {
      final before = playlist.songIds.length;
      playlist.songIds.removeWhere(orphans.contains);
      orphans.forEach(playlist.songPaths.remove);
      if (playlist.songIds.length != before) playlistsChanged = true;
    }
    if (playlistsChanged) {
      await _savePlaylists();
    }

    if (orphanFavorites.isNotEmpty || playlistsChanged) {
      notifyListeners();
    }
  }

  void _applySortAndFilter() {
    _songs.sort((a, b) {
      switch (_sortField) {
        case SortField.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case SortField.artist:
          return a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        case SortField.album:
          return a.album.toLowerCase().compareTo(b.album.toLowerCase());
      }
    });

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      _displaySongs = _songs
          .where((s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q))
          .toList();
    } else {
      _displaySongs = [];
    }
  }

  void sortBy(SortField field) {
    _sortField = field;
    _applySortAndFilter();
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query.trim();
    _applySortAndFilter();
    notifyListeners();
  }

  Future<void> toggleFavorite(int id) async {
    await _favoritesLoaded;
    if (_favorites.contains(id)) {
      _favorites.remove(id);
      _favoritePaths.remove(id);
    } else {
      _favorites.add(id);
      final path = _songById(id)?.path;
      if (path != null) _favoritePaths[id] = path;
    }
    notifyListeners();
    await _saveFavorites();
  }

  Song? _songById(int id) => _songs.where((s) => s.id == id).firstOrNull;

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'favorites',
      _favorites.map((e) => e.toString()).toList(),
    );
    await prefs.setString(
      'favorite_paths',
      jsonEncode(_favoritePaths.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  // Tolerante a dados corrompidos: valores inválidos são ignorados em vez de
  // falhar o carregamento (o que travaria `toggleFavorite` para sempre, já
  // que ele aguarda `_favoritesLoaded`).
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('favorites') ?? [];
      _favorites.addAll(list.map(int.tryParse).whereType<int>());
      final rawPaths = prefs.getString('favorite_paths');
      if (rawPaths != null) {
        _favoritePaths.addAll(decodeIdPathMap(jsonDecode(rawPaths)));
      }
    } catch (e) {
      debugPrint('Erro ao carregar favoritos: $e');
    }
    notifyListeners();
  }

  // Shuffle, repeat e velocidade persistem entre sessões.
  Future<void> _loadPlaybackPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isShuffle = prefs.getBool('shuffle') ?? false;
      final repeatIndex = prefs.getInt('repeat_mode') ?? 0;
      _repeatMode = RepeatMode.values[
          repeatIndex.clamp(0, RepeatMode.values.length - 1)];
      _speed = prefs.getDouble('speed') ?? 1.0;
      await _handler.setShuffleModeEnabled(_isShuffle);
      _applyRepeatMode();
      await _handler.setSpeed(_speed);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar preferências de reprodução: $e');
    }
  }

  Future<void> _savePlaybackPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shuffle', _isShuffle);
    await prefs.setInt('repeat_mode', _repeatMode.index);
    await prefs.setDouble('speed', _speed);
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    _handler.setSpeed(speed);
    notifyListeners();
    await _savePlaybackPrefs();
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    _sleepTimerEnd = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () async {
      // Limpa o estado mesmo se o stop falhar — senão a contagem continua.
      try {
        await _handler.stop();
      } finally {
        cancelSleepTimer();
      }
    });
    _sleepCountdown = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateSleepTimerRemaining(),
    );
    _updateSleepTimerRemaining();
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    _sleepTimer = null;
    _sleepTimerEnd = null;
    _updateSleepTimerRemaining();
    notifyListeners();
  }

  Future<void> skipToQueueItem(int index) => _handler.skipToQueueItem(index);

  // Várias chamadas podem rodar em paralelo quando o usuário pula faixas
  // rápido; só aplica a cor se [song] ainda for a faixa atual, senão uma
  // resposta atrasada sobrescreveria a cor da faixa nova.
  Future<void> _loadPaletteForSong(Song song) async {
    _paletteAccent = null;
    Color? color;
    try {
      color = await _fetchNetworkPalette(song);
      if (color == null && _currentSong?.id == song.id) {
        final artwork = await _audioQuery.queryArtwork(
          song.id,
          ArtworkType.AUDIO,
          size: 100,
        );
        if (artwork != null && artwork.isNotEmpty) {
          color = await _dominantColor(MemoryImage(artwork));
        }
      }
    } catch (_) {
      color = null;
    }
    if (_currentSong?.id != song.id) return;
    _paletteAccent = color;
    notifyListeners();
  }

  Future<Color?> _dominantColor(MemoryImage image) async {
    final generator = await PaletteGenerator.fromImageProvider(
      image,
      size: const Size(100, 100),
    );
    return generator.dominantColor?.color;
  }

  // Cor dominante da capa de rede (iTunes); `null` se não houver capa.
  Future<Color?> _fetchNetworkPalette(Song song) async {
    final url = await _resolveArtworkUrl(song);
    if (url == null || _currentSong?.id != song.id) return null;
    return _paletteFromUrl(url);
  }

  Future<String?> _resolveArtworkUrl(Song song) async {
    await _artworkCacheLoaded;
    final cached = _artworkUrlCache[song.id];
    if (cached != null) return cached;

    // Sem artista a busca vira só o título, que casa com qualquer faixa
    // homônima — melhor ficar com a capa local/gradiente.
    if (!song.hasKnownArtist) return null;

    final missAt = _artworkMissCache[song.id];
    if (missAt != null &&
        DateTime.now().millisecondsSinceEpoch - missAt <
            _artworkMissTtl.inMilliseconds) {
      return null;
    }

    try {
      final term = Uri.encodeComponent('${song.artist} ${song.title}');
      final uri = Uri.parse(
          'https://itunes.apple.com/search?term=$term&entity=song&limit=5&media=music');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final url =
          pickArtworkUrl(results, artist: song.artist, title: song.title);
      if (url == null) {
        _artworkMissCache[song.id] = DateTime.now().millisecondsSinceEpoch;
        _trimToLimit(_artworkMissCache);
        await _saveArtworkCaches();
        return null;
      }
      _artworkUrlCache[song.id] = url;
      _artworkMissCache.remove(song.id);
      _trimToLimit(_artworkUrlCache);
      await _saveArtworkCaches();
      notifyListeners();
      return url;
    } catch (_) {
      // Erro de rede/timeout não entra no cache negativo: tenta de novo na
      // próxima vez.
      return null;
    }
  }

  // Map preserva ordem de inserção: remove as entradas mais antigas quando
  // estoura o limite (política simples de FIFO).
  void _trimToLimit(Map<int, Object> cache) {
    while (cache.length > _maxArtworkCacheEntries) {
      cache.remove(cache.keys.first);
    }
  }

  Future<Color?> _paletteFromUrl(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return _dominantColor(MemoryImage(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveArtworkCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'artwork_url_cache',
        jsonEncode(_artworkUrlCache.map((k, v) => MapEntry(k.toString(), v))),
      );
      await prefs.setString(
        'artwork_miss_cache',
        jsonEncode(
            _artworkMissCache.map((k, v) => MapEntry(k.toString(), v))),
      );
    } catch (_) {}
  }

  Future<void> _loadArtworkUrlCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('artwork_url_cache');
      if (raw != null) {
        final map =
            (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
        _artworkUrlCache
            .addAll(map.map((k, v) => MapEntry(int.parse(k), v)));
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('artwork_miss_cache');
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          final id = int.tryParse(e.key);
          final at = e.value;
          if (id != null && at is int) _artworkMissCache[id] = at;
        }
      }
    } catch (_) {}
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    final list = playlist ?? songs;
    final idx = list.indexWhere((s) => s.id == song.id);
    final items = list.map((s) => s.toMediaItem()).toList();
    try {
      await _handler.setPlaylist(items, idx < 0 ? 0 : idx);
    } on PlayerInterruptedException {
      // Outro toque carregou uma nova fila antes desta terminar — esperado.
    } catch (e) {
      debugPrint('Erro ao tocar "${song.title}": $e');
      _errors.add('Não foi possível tocar "${song.title}"');
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> skipNext() => _handler.skipToNext();
  Future<void> skipPrevious() => _handler.skipToPrevious();

  Future<void> seekTo(double value) {
    final ms = (value * _duration.inMilliseconds).round();
    return _handler.seek(Duration(milliseconds: ms));
  }

  Future<void> toggleShuffle() async {
    _isShuffle = !_isShuffle;
    notifyListeners();
    await _handler.setShuffleModeEnabled(_isShuffle);
    await _savePlaybackPrefs();
  }

  void cycleRepeatMode() {
    _repeatMode = RepeatMode.values[(_repeatMode.index + 1) % 3];
    _applyRepeatMode();
    notifyListeners();
    _savePlaybackPrefs();
  }

  void _applyRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.none:
        _handler.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.one:
        _handler.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.all:
        _handler.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _position.dispose();
    _errors.close();
    _sleepTimerRemaining.dispose();
    _handler.stop();
    super.dispose();
  }

  // ── Playlists ──────────────────────────────────────────────

  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('playlists');
    if (raw != null) {
      try {
        _playlists.addAll(Playlist.decodeList(raw));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playlists', Playlist.encodeList(_playlists));
  }

  Future<void> createPlaylist(String name) async {
    await _playlistsLoaded;
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
    );
    _playlists.add(playlist);
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String id) async {
    await _playlistsLoaded;
    _playlists.removeWhere((p) => p.id == id);
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> renamePlaylist(String id, String name) async {
    await _playlistsLoaded;
    final playlist = _playlists.firstWhere((p) => p.id == id);
    playlist.name = name.trim();
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, int songId) async {
    await _playlistsLoaded;
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    if (!playlist.songIds.contains(songId)) {
      playlist.songIds.add(songId);
      final path = _songById(songId)?.path;
      if (path != null) playlist.songPaths[songId] = path;
      notifyListeners();
      await _savePlaylists();
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    await _playlistsLoaded;
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    playlist.songIds.remove(songId);
    playlist.songPaths.remove(songId);
    notifyListeners();
    await _savePlaylists();
  }

  List<Song> getPlaylistSongs(Playlist playlist) {
    final byId = {for (final s in _songs) s.id: s};
    return playlist.songIds.map((id) => byId[id]).whereType<Song>().toList();
  }

  Future<void> playPlaylist(Playlist playlist) async {
    final songs = getPlaylistSongs(playlist);
    if (songs.isEmpty) return;
    await playSong(songs.first, playlist: songs);
  }
}
