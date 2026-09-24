import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, MemoryImage, Size;
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
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String _searchQuery = '';
  double _speed = 1.0;
  Timer? _sleepTimer;
  Timer? _sleepCountdown;
  DateTime? _sleepTimerEnd;
  Color? _paletteAccent;
  SortField _sortField = SortField.title;
  final Set<int> _favorites = {};
  final List<Playlist> _playlists = [];
  final Map<int, String> _artworkUrlCache = {};
  late final Future<void> _favoritesLoaded;
  late final Future<void> _playlistsLoaded;
  late final Future<void> _artworkCacheLoaded;

  PlayerProvider(this._handler) {
    _subscribeToStreams();
    _favoritesLoaded = _loadFavorites();
    _playlistsLoaded = _loadPlaylists();
    _artworkCacheLoaded = _loadArtworkUrlCache();
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
  Duration get position => _position;
  Duration get duration => _duration;
  int get totalSongs => _songs.length;
  SortField get sortField => _sortField;
  Set<int> get favorites => Set.unmodifiable(_favorites);
  List<Playlist> get playlists => List.unmodifiable(_playlists);

  bool isFavorited(int id) => _favorites.contains(id);
  String? getArtworkUrl(int songId) => _artworkUrlCache[songId];

  double get speed => _speed;
  Color? get paletteAccent => _paletteAccent;
  bool get hasSleepTimer => _sleepTimer?.isActive == true;

  Duration? get sleepTimerRemaining {
    if (_sleepTimerEnd == null) return null;
    final remaining = _sleepTimerEnd!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  List<MediaItem> get currentQueue => _handler.queue.value;

  int get currentQueueIndex =>
      _handler.queue.value.indexWhere((m) => m.id == _currentSong?.path);

  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  void _subscribeToStreams() {
    _handler.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _handler.durationStream.listen((dur) {
      if (dur != null && dur != _duration) {
        _duration = dur;
        notifyListeners();
      }
    });

    _handler.playbackState.listen((state) {
      final playing = state.playing;
      if (playing != _isPlaying) {
        _isPlaying = playing;
        notifyListeners();
      }
    });

    _handler.mediaItem.listen((item) {
      if (item != null) {
        final matched = _songs.where((s) => s.path == item.id).firstOrNull;
        if (matched != null && matched != _currentSong) {
          _currentSong = matched;
          notifyListeners();
          _loadPaletteForSong(matched);
        }
      }
    });
  }

  Future<bool> requestPermission() async {
    // Android 13+ usa READ_MEDIA_AUDIO; abaixo usa READ_EXTERNAL_STORAGE
    PermissionStatus status = await Permission.audio.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    _hasPermission = status.isGranted;
    // Negada com "não perguntar de novo" (ou negada 2x): o sistema para de
    // mostrar o diálogo nativo — só resta redirecionar às configurações.
    _permissionPermanentlyDenied = status.isPermanentlyDenied;
    notifyListeners();
    return _hasPermission;
  }

  Future<bool> openPermissionSettings() => openAppSettings();

  Future<void> loadSongs() async {
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
      await _pruneOrphans();
    } catch (e) {
      debugPrint('Erro ao carregar músicas: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Remove de favoritos/playlists IDs de músicas que não existem mais na
  // biblioteca atual do MediaStore (ex.: arquivo apagado do dispositivo).
  Future<void> _pruneOrphans() async {
    await _favoritesLoaded;
    await _playlistsLoaded;

    final validIds = _songs.map((s) => s.id).toSet();

    final orphanFavorites = _favorites.difference(validIds);
    if (orphanFavorites.isNotEmpty) {
      _favorites.removeAll(orphanFavorites);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'favorites',
        _favorites.map((e) => e.toString()).toList(),
      );
    }

    var playlistsChanged = false;
    for (final playlist in _playlists) {
      final before = playlist.songIds.length;
      playlist.songIds.removeWhere((id) => !validIds.contains(id));
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
    } else {
      _favorites.add(id);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'favorites',
      _favorites.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorites') ?? [];
    _favorites.addAll(list.map(int.parse));
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    _handler.setSpeed(speed);
    notifyListeners();
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    _sleepTimerEnd = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () async {
      await _handler.stop();
      _sleepTimerEnd = null;
      _sleepCountdown?.cancel();
      _sleepTimer = null;
      notifyListeners();
    });
    _sleepCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    _sleepTimer = null;
    _sleepTimerEnd = null;
    notifyListeners();
  }

  Future<void> skipToQueueItem(int index) => _handler.skipToQueueItem(index);

  Future<void> _loadPaletteForSong(Song song) async {
    _paletteAccent = null;
    try {
      await _fetchNetworkArtwork(song);
      if (_paletteAccent == null) {
        final artwork = await _audioQuery.queryArtwork(
          song.id,
          ArtworkType.AUDIO,
          size: 100,
        );
        if (artwork != null && artwork.isNotEmpty) {
          final generator = await PaletteGenerator.fromImageProvider(
            MemoryImage(artwork),
            size: const Size(100, 100),
          );
          _paletteAccent = generator.dominantColor?.color;
          notifyListeners();
        }
      }
    } catch (_) {
      _paletteAccent = null;
      notifyListeners();
    }
  }

  Future<void> _fetchNetworkArtwork(Song song) async {
    await _artworkCacheLoaded;
    if (_artworkUrlCache.containsKey(song.id)) {
      notifyListeners();
      await _loadPaletteFromUrl(_artworkUrlCache[song.id]!);
      return;
    }
    try {
      final term = Uri.encodeComponent('${song.artist} ${song.title}');
      final uri = Uri.parse(
          'https://itunes.apple.com/search?term=$term&entity=song&limit=5&media=music');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results =
            (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (results.isNotEmpty) {
          final artUrl = results.first['artworkUrl100'] as String?;
          if (artUrl != null) {
            final highRes = artUrl.replaceAll('100x100bb', '500x500bb');
            _artworkUrlCache[song.id] = highRes;
            // Map preserva ordem de inserção: remove a entrada mais antiga
            // quando estoura o limite (política simples de FIFO/LRU).
            while (_artworkUrlCache.length > _maxArtworkCacheEntries) {
              _artworkUrlCache.remove(_artworkUrlCache.keys.first);
            }
            await _saveArtworkUrlCache();
            notifyListeners();
            await _loadPaletteFromUrl(highRes);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPaletteFromUrl(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final generator = await PaletteGenerator.fromImageProvider(
          MemoryImage(response.bodyBytes),
          size: const Size(100, 100),
        );
        _paletteAccent = generator.dominantColor?.color;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveArtworkUrlCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _artworkUrlCache.map((k, v) => MapEntry(k.toString(), v));
      await prefs.setString('artwork_url_cache', jsonEncode(map));
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
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    final list = playlist ?? songs;
    final idx = list.indexWhere((s) => s.id == song.id);
    final items = list.map((s) => s.toMediaItem()).toList();
    await _handler.setPlaylist(items, idx < 0 ? 0 : idx);
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

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _handler.setShuffleModeEnabled(_isShuffle);
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode = RepeatMode.values[(_repeatMode.index + 1) % 3];
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
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
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
      notifyListeners();
      await _savePlaylists();
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    await _playlistsLoaded;
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    playlist.songIds.remove(songId);
    notifyListeners();
    await _savePlaylists();
  }

  List<Song> getPlaylistSongs(Playlist playlist) {
    return playlist.songIds
        .map((id) => _songs.cast<Song?>().firstWhere(
              (s) => s?.id == id,
              orElse: () => null,
            ))
        .whereType<Song>()
        .toList();
  }

  Future<void> playPlaylist(Playlist playlist) async {
    final songs = getPlaylistSongs(playlist);
    if (songs.isEmpty) return;
    await playSong(songs.first, playlist: songs);
  }
}
