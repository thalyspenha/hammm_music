import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

// Paleta de gradientes determinística por música (hash do título)
const _gradients = [
  [Color(0xFF7C6AFF), Color(0xFF4A3FCC)], // purple
  [Color(0xFF00B4D8), Color(0xFF0077B6)], // cyan
  [Color(0xFF06D6A0), Color(0xFF028A60)], // emerald
  [Color(0xFFF72585), Color(0xFFB5179E)], // magenta
  [Color(0xFFFF6B6B), Color(0xFFCC4040)], // coral
  [Color(0xFFFFBE0B), Color(0xFFDD8B00)], // amber
  [Color(0xFF3A86FF), Color(0xFF1A5ECC)], // blue
  [Color(0xFFE040FB), Color(0xFF9900CC)], // violet
];

List<Color> songGradient(String title) =>
    _gradients[title.hashCode.abs() % _gradients.length];

Color songAccentColor(String title) => songGradient(title).first;

// ──────────────────────────────────────────────────────────────
// Widget público: álbum art com fallback em gradiente
// ──────────────────────────────────────────────────────────────

class GradientAlbumArt extends StatelessWidget {
  final int songId;
  final String songTitle;
  final double size;
  final double borderRadius;

  const GradientAlbumArt({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.size,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: Consumer<PlayerProvider>(
          builder: (context, provider, _) {
            final url = provider.getArtworkUrl(songId);
            if (url != null) {
              return Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _LocalOrGradient(
                  songId: songId,
                  songTitle: songTitle,
                  size: size,
                ),
              );
            }
            return _LocalOrGradient(
              songId: songId,
              songTitle: songTitle,
              size: size,
            );
          },
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Widget de vinyl rotativo (usado no player full-screen)
// ──────────────────────────────────────────────────────────────

class VinylAlbumArt extends StatefulWidget {
  final int songId;
  final String songTitle;
  final double size;
  final bool isPlaying;

  const VinylAlbumArt({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.size,
    required this.isPlaying,
  });

  @override
  State<VinylAlbumArt> createState() => _VinylAlbumArtState();
}

class _VinylAlbumArtState extends State<VinylAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(VinylAlbumArt old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying == old.isPlaying) return;
    widget.isPlaying ? _ctrl.repeat() : _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artSize = widget.size * 0.58;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.rotate(
        angle: _ctrl.value * 2 * math.pi,
        child: child,
      ),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _VinylPainter(title: widget.songTitle),
          child: Center(
            child: ClipOval(
              child: _ArtOrGradient(
                songId: widget.songId,
                songTitle: widget.songTitle,
                size: artSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Internals
// ──────────────────────────────────────────────────────────────

// Prioridade: URL de rede > arte embutida > gradiente placeholder
class _LocalOrGradient extends StatelessWidget {
  final int songId;
  final String songTitle;
  final double size;

  const _LocalOrGradient({
    required this.songId,
    required this.songTitle,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return QueryArtworkWidget(
      id: songId,
      type: ArtworkType.AUDIO,
      format: ArtworkFormat.JPEG,
      quality: 90,
      size: (size * 1.5).toInt(),
      artworkFit: BoxFit.cover,
      artworkBorder: BorderRadius.zero,
      keepOldArtwork: true,
      nullArtworkWidget: _GradientPlaceholder(title: songTitle, size: size),
    );
  }
}

class _ArtOrGradient extends StatelessWidget {
  final int songId;
  final String songTitle;
  final double size;

  const _ArtOrGradient({
    required this.songId,
    required this.songTitle,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        final url = provider.getArtworkUrl(songId);
        if (url != null) {
          return Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _LocalOrGradient(
              songId: songId,
              songTitle: songTitle,
              size: size,
            ),
          );
        }
        return _LocalOrGradient(
          songId: songId,
          songTitle: songTitle,
          size: size,
        );
      },
    );
  }
}

class _GradientPlaceholder extends StatelessWidget {
  final String title;
  final double size;

  const _GradientPlaceholder({required this.title, required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = songGradient(title);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white.withOpacity(0.4),
          size: size * 0.38,
        ),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  final String title;
  const _VinylPainter({required this.title});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Base preta
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF111111));

    // Ranhuras (grooves) concêntricas
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (double gr = r * 0.32; gr < r * 0.97; gr += r * 0.035) {
      groovePaint.color = Colors.white.withOpacity(0.04);
      canvas.drawCircle(c, gr, groovePaint);
    }

    // Reflexo especular (canto superior esquerdo)
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [Colors.white.withOpacity(0.09), Colors.transparent],
          stops: const [0.0, 0.65],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.title != title;
}
