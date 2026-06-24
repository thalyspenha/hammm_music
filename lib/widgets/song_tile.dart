import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import 'gradient_album_art.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final List<Song> playlist;
  final int index;

  const SongTile({
    super.key,
    required this.song,
    required this.playlist,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerProvider>();
    final isActive = provider.currentSong?.id == song.id;
    final accent = songAccentColor(song.title);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => provider.playSong(song, playlist: playlist),
        onLongPress: () => _showAddToPlaylistSheet(context, song),
        splashColor: accent.withOpacity(0.08),
        highlightColor: accent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isActive
                ? Border.all(color: accent.withOpacity(0.3), width: 1)
                : null,
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      accent.withOpacity(0.12),
                      accent.withOpacity(0.04),
                    ],
                  )
                : null,
          ),
          child: Row(
            children: [
              // Album art com borda colorida quando ativo
              _ArtWithActiveBorder(
                songId: song.id,
                songTitle: song.title,
                isActive: isActive,
                accent: accent,
              ),
              const SizedBox(width: 14),
              // Título + artista
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive ? accent : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.8),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Duração ou indicador animado
              SizedBox(
                width: 36,
                child: isActive && provider.isPlaying
                    ? _PlayingBars(accent: accent)
                    : Text(
                        song.formattedDuration,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.7),
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Album art com borda pulsante quando ativa
// ──────────────────────────────────────────────────────────────

class _ArtWithActiveBorder extends StatefulWidget {
  final int songId;
  final String songTitle;
  final bool isActive;
  final Color accent;

  const _ArtWithActiveBorder({
    required this.songId,
    required this.songTitle,
    required this.isActive,
    required this.accent,
  });

  @override
  State<_ArtWithActiveBorder> createState() => _ArtWithActiveBorderState();
}

class _ArtWithActiveBorderState extends State<_ArtWithActiveBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_ArtWithActiveBorder old) {
    super.didUpdateWidget(old);
    if (widget.isActive == old.isActive) return;
    widget.isActive ? _ctrl.repeat(reverse: true) : _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: widget.accent
                        .withOpacity(0.2 + 0.25 * _ctrl.value),
                    blurRadius: 10 + 8 * _ctrl.value,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: child,
      ),
      child: GradientAlbumArt(
        songId: widget.songId,
        songTitle: widget.songTitle,
        size: 50,
        borderRadius: 11,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Barras de equalizer animadas
// ──────────────────────────────────────────────────────────────

class _PlayingBars extends StatefulWidget {
  final Color accent;
  const _PlayingBars({required this.accent});

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final phase = (i * 0.3 + _ctrl.value) % 1.0;
          final h = 4.0 + 12.0 * _wave(phase);
          return Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 2.5),
            child: Container(
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: widget.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  double _wave(double t) => (1 - (t * 2 - 1).abs()).clamp(0.0, 1.0);
}

// ──────────────────────────────────────────────────────────────
// Long-press: adicionar à playlist
// ──────────────────────────────────────────────────────────────

void _showAddToPlaylistSheet(BuildContext context, Song song) {
  final provider = context.read<PlayerProvider>();
  final playlists = provider.playlists;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToPlaylistSheet(song: song, playlists: playlists),
  );
}

class _AddToPlaylistSheet extends StatelessWidget {
  final Song song;
  final List<Playlist> playlists;

  const _AddToPlaylistSheet({required this.song, required this.playlists});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Adicionar à playlist',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Text(
                'Nenhuma playlist criada.\nAcesse a tela de Playlists para criar uma.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            )
          else
            ...playlists.map((playlist) => _PlaylistOption(
                  song: song,
                  playlist: playlist,
                )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PlaylistOption extends StatelessWidget {
  final Song song;
  final Playlist playlist;

  const _PlaylistOption({required this.song, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final alreadyAdded = playlist.songIds.contains(song.id);
    return InkWell(
      onTap: alreadyAdded
          ? null
          : () {
              context.read<PlayerProvider>().addSongToPlaylist(playlist.id, song.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Adicionado a "${playlist.name}"'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: AppTheme.card,
                ),
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(alreadyAdded ? 0.08 : 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.queue_music_rounded,
                color: AppTheme.accent.withOpacity(alreadyAdded ? 0.4 : 1.0),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: TextStyle(
                      color: alreadyAdded
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${playlist.songIds.length} músicas${alreadyAdded ? ' · já adicionada' : ''}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (alreadyAdded)
              const Icon(Icons.check_rounded, color: AppTheme.accent, size: 18),
          ],
        ),
      ),
    );
  }
}
