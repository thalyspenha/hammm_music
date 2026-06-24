import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class AlbumArtWidget extends StatelessWidget {
  final int songId;
  final double size;
  final double borderRadius;
  final bool showShadow;

  const AlbumArtWidget({
    super.key,
    required this.songId,
    this.size = 56,
    this.borderRadius = 12,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: AppTheme.cardElevated,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: QueryArtworkWidget(
          id: songId,
          type: ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          quality: 85,
          size: size.toInt() * 2,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          nullArtworkWidget: Consumer<PlayerProvider>(
            builder: (context, provider, _) {
              final url = provider.getArtworkUrl(songId);
              if (url != null) {
                return Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _Placeholder(size: size),
                );
              }
              return _Placeholder(size: size);
            },
          ),
          keepOldArtwork: true,
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double size;
  const _Placeholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.cardElevated,
      child: Icon(
        Icons.music_note_rounded,
        color: AppTheme.accent.withOpacity(0.6),
        size: size * 0.45,
      ),
    );
  }
}
