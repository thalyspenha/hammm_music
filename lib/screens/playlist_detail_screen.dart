import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_album_art.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, _) {
          final songs = provider.getPlaylistSongs(playlist);

          if (songs.isEmpty) {
            return const _EmptyState();
          }

          return Column(
            children: [
              _PlayAllButton(playlist: playlist),
              Expanded(
                child: ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final isPlaying = provider.currentSong?.id == song.id;
                    return _PlaylistSongTile(
                      song: song,
                      isPlaying: isPlaying,
                      onTap: () => provider.playSong(song, playlist: songs),
                      onRemove: () => provider.removeSongFromPlaylist(
                        playlist.id,
                        song.id,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Botão "Tocar tudo" ──────────────────────────────────────────

class _PlayAllButton extends StatelessWidget {
  final Playlist playlist;

  const _PlayAllButton({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlayerProvider>();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => provider.playPlaylist(playlist),
        icon: const Icon(Icons.play_arrow_rounded, size: 22),
        label: const Text(
          'Tocar tudo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: AppTheme.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

// ── Tile de música dentro da playlist ──────────────────────────

class _PlaylistSongTile extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PlaylistSongTile({
    required this.song,
    required this.isPlaying,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor =
        isPlaying ? AppTheme.accent : AppTheme.textPrimary;

    return InkWell(
      onTap: onTap,
      splashColor: AppTheme.accent.withOpacity(0.08),
      highlightColor: AppTheme.accent.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Álbum art
            GradientAlbumArt(
              songId: song.id,
              songTitle: song.title,
              size: 46,
              borderRadius: 10,
            ),
            const SizedBox(width: 12),
            // Título e artista
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 14,
                      fontWeight: isPlaying
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Botão remover
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              iconSize: 20,
              color: AppTheme.textSecondary,
              splashRadius: 20,
              tooltip: 'Remover da playlist',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music_rounded,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma música nesta playlist',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adicione músicas pela lista principal',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
