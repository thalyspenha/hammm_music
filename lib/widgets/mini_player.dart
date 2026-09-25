import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import '../theme/app_theme.dart';
import 'gradient_album_art.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    // Sem key por música: o mesmo State é reaproveitado entre faixas, então
    // a animação de entrada só roda quando o mini player aparece, não a cada
    // troca de faixa.
    final hasSong =
        context.select<PlayerProvider, bool>((p) => p.currentSong != null);
    if (!hasSong) return const SizedBox.shrink();

    return const _MiniPlayerBody();
  }
}

class _MiniPlayerBody extends StatefulWidget {
  const _MiniPlayerBody();

  @override
  State<_MiniPlayerBody> createState() => _MiniPlayerBodyState();
}

class _MiniPlayerBodyState extends State<_MiniPlayerBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

  // Para swipe horizontal (skip)
  double _swipeX = 0;

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  void _openPlayer(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const PlayerScreen(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerProvider>();
    final song = provider.currentSong!;
    final accent = provider.currentAccent;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: GestureDetector(
          onTap: () => _openPlayer(context),
          onVerticalDragEnd: (d) {
            if (d.primaryVelocity != null && d.primaryVelocity! < -300) {
              _openPlayer(context);
            }
          },
          onHorizontalDragUpdate: (d) =>
              setState(() => _swipeX += d.delta.dx),
          onHorizontalDragEnd: (d) {
            if (_swipeX < -60) provider.skipNext();
            if (_swipeX > 60) provider.skipPrevious();
            setState(() => _swipeX = 0);
          },
          child: Transform.translate(
            offset: Offset(_swipeX * 0.15, 0), // resistência ao swipe
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppTheme.surface.withValues(alpha: 0.82),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          // Sem padding embaixo: a área de toque do seek (logo abaixo)
                          // ocupa esse espaço, sem mudar a altura do mini player.
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
                          child: Row(
                            children: [
                              // Álbum art com anel de progresso
                              _ArtWithProgress(
                                songId: song.id,
                                songTitle: song.title,
                                provider: provider,
                                accent: accent,
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
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppTheme.textSecondary
                                            .withValues(alpha: 0.85),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Controles
                              _MiniCtrl(
                                icon: Icons.skip_previous_rounded,
                                onTap: provider.skipPrevious,
                              ),
                              _MiniPlayPause(
                                isPlaying: provider.isPlaying,
                                accent: accent,
                                onTap: provider.togglePlayPause,
                              ),
                              _MiniCtrl(
                                icon: Icons.skip_next_rounded,
                                onTap: provider.skipNext,
                              ),
                            ],
                          ),
                        ),
                        // Linha de progresso no rodapé (toque/arraste = seek)
                        _SeekableProgressLine(
                          provider: provider,
                          accent: accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Álbum art com anel de progresso circular
// ──────────────────────────────────────────────────────────────

class _ArtWithProgress extends StatelessWidget {
  final int songId;
  final String songTitle;
  final PlayerProvider provider;
  final Color accent;

  const _ArtWithProgress({
    required this.songId,
    required this.songTitle,
    required this.provider,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    // Só o anel acompanha a posição; a capa entra como `child` fixo para não
    // ser reconstruída (e reconsultada no MediaStore) a cada tick.
    return SizedBox(
      width: 50,
      height: 50,
      child: ValueListenableBuilder<Duration>(
        valueListenable: provider.positionListenable,
        builder: (context, position, art) => CustomPaint(
          painter: _RingPainter(
            progress: provider.progressAt(position),
            color: accent,
          ),
          child: art,
        ),
        child: Center(
          child: GradientAlbumArt(
            songId: songId,
            songTitle: songTitle,
            size: 42,
            borderRadius: 9,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    const startAngle = -3.14159 / 2; // 12 o'clock

    // Trilha de fundo
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Progresso
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        progress * 2 * 3.14159,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ──────────────────────────────────────────────────────────────
// Seek pela linha de progresso
// ──────────────────────────────────────────────────────────────

// A linha tem 2 px; a área de toque (12 px, o antigo espaçamento abaixo da
// linha de controles) fica na base do mini player. Arrastes que começam nela são seek (não o swipe de pular faixa do
// mini player, porque o detector mais interno vence a disputa de gestos).
// Durante o arraste a linha mostra a posição escolhida; o seek só acontece
// ao soltar, para não disparar um seek por frame.
class _SeekableProgressLine extends StatefulWidget {
  final PlayerProvider provider;
  final Color accent;

  const _SeekableProgressLine({required this.provider, required this.accent});

  @override
  State<_SeekableProgressLine> createState() => _SeekableProgressLineState();
}

class _SeekableProgressLineState extends State<_SeekableProgressLine> {
  static const _touchHeight = 12.0;
  double? _dragValue;

  double _fractionAt(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) =>
              widget.provider.seekTo(_fractionAt(d.localPosition.dx, width)),
          onHorizontalDragStart: (d) => setState(
              () => _dragValue = _fractionAt(d.localPosition.dx, width)),
          onHorizontalDragUpdate: (d) => setState(
              () => _dragValue = _fractionAt(d.localPosition.dx, width)),
          onHorizontalDragEnd: (_) {
            final value = _dragValue;
            setState(() => _dragValue = null);
            if (value != null) widget.provider.seekTo(value);
          },
          onHorizontalDragCancel: () => setState(() => _dragValue = null),
          child: SizedBox(
            height: _touchHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<Duration>(
                valueListenable: widget.provider.positionListenable,
                builder: (context, position, _) => _ProgressLine(
                  progress:
                      _dragValue ?? widget.provider.progressAt(position),
                  accent: widget.accent,
                  animate: _dragValue == null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Linha de progresso com degradê
// ──────────────────────────────────────────────────────────────

class _ProgressLine extends StatelessWidget {
  final double progress;
  final Color accent;
  // Desligado durante o arraste, para a linha seguir o dedo sem atraso.
  final bool animate;

  const _ProgressLine({
    required this.progress,
    required this.accent,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: 2,
          width: w,
          child: Stack(
            children: [
              Container(color: Colors.white.withValues(alpha: 0.07)),
              AnimatedContainer(
                duration: Duration(milliseconds: animate ? 250 : 0),
                width: w * progress.clamp(0, 1),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withValues(alpha: 0.7), accent],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Botões do mini player
// ──────────────────────────────────────────────────────────────

class _MiniCtrl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniCtrl({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Icon(icon, color: AppTheme.textPrimary, size: 22),
      ),
    );
  }
}

class _MiniPlayPause extends StatelessWidget {
  final bool isPlaying;
  final Color accent;
  final VoidCallback onTap;

  const _MiniPlayPause({
    required this.isPlaying,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
