import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_album_art.dart';
import 'queue_screen.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: const _PlayerScaffold(),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Scaffold com fundo de gradiente animado por música
// ──────────────────────────────────────────────────────────────

class _PlayerScaffold extends StatelessWidget {
  const _PlayerScaffold();

  @override
  Widget build(BuildContext context) {
    final song = context.watch<PlayerProvider>().currentSong;
    final accent = context.watch<PlayerProvider>().currentAccent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fundo: gradiente animado conforme a música
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(accent, Colors.black, 0.42)!,
                  Color.lerp(accent, Colors.black, 0.78)!,
                  AppTheme.background,
                ],
                stops: const [0.0, 0.4, 0.75],
              ),
            ),
          ),
          // Conteúdo
          SafeArea(
            child: song == null
                ? const SizedBox.shrink()
                : _PlayerContent(accent: accent),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Conteúdo principal do player
// ──────────────────────────────────────────────────────────────

class _PlayerContent extends StatelessWidget {
  final Color accent;
  const _PlayerContent({required this.accent});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerProvider>();
    final song = provider.currentSong!;
    final screenW = MediaQuery.of(context).size.width;
    final artSize = screenW - 64;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -300) context.read<PlayerProvider>().skipNext();
        if (velocity > 300) context.read<PlayerProvider>().skipPrevious();
      },
      child: Column(
      children: [
        _PlayerHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Arte Vinyl rotativa
                _AnimatedArt(
                  key: ValueKey(song.id),
                  songId: song.id,
                  songTitle: song.title,
                  size: artSize,
                  isPlaying: provider.isPlaying,
                  accent: accent,
                ),

                const Spacer(flex: 2),

                // Info da música
                _SongInfo(song: song),

                const SizedBox(height: 28),

                // Seekbar com glow
                _GlowSeekBar(provider: provider, accent: accent),

                const SizedBox(height: 32),

                // Controles principais
                _MainControls(provider: provider),

                const SizedBox(height: 20),

                // Shuffle + queue + repeat
                _SecondaryControls(provider: provider, accent: accent),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Header
// ──────────────────────────────────────────────────────────────

class _PlayerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textPrimary,
              size: 30,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'TOCANDO AGORA',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: AppTheme.textPrimary,
              size: 24,
            ),
            onPressed: () {
              final song = context.read<PlayerProvider>().currentSong;
              if (song == null) return;
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => _SongDetailsSheet(song: song),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Arte animada (entra com scale + fade ao trocar de música)
// ──────────────────────────────────────────────────────────────

class _AnimatedArt extends StatefulWidget {
  final int songId;
  final String songTitle;
  final double size;
  final bool isPlaying;
  final Color accent;

  const _AnimatedArt({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.size,
    required this.isPlaying,
    required this.accent,
  });

  @override
  State<_AnimatedArt> createState() => _AnimatedArtState();
}

class _AnimatedArtState extends State<_AnimatedArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow por baixo da arte
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: widget.size * 0.85,
            height: widget.size * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: widget.isPlaying ? 0.45 : 0.2),
                  blurRadius: widget.isPlaying ? 60 : 30,
                  spreadRadius: widget.isPlaying ? 10 : 0,
                ),
              ],
            ),
          ),
          // Vinyl com rotação
          VinylAlbumArt(
            songId: widget.songId,
            songTitle: widget.songTitle,
            size: widget.size,
            isPlaying: widget.isPlaying,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Informações da música
// ──────────────────────────────────────────────────────────────

class _SongInfo extends StatelessWidget {
  final Song song;
  const _SongInfo({required this.song});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary.withValues(alpha: 0.55),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _LikeButton(songId: song.id),
      ],
    );
  }
}

class _LikeButton extends StatefulWidget {
  final int songId;
  const _LikeButton({required this.songId});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
  ]).animate(_ctrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liked = context.watch<PlayerProvider>().isFavorited(widget.songId);
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: () {
          context.read<PlayerProvider>().toggleFavorite(widget.songId);
          _ctrl.forward(from: 0);
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(liked),
            color: liked ? AppTheme.favorite : AppTheme.textSecondary,
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Seekbar com glow customizado
// ──────────────────────────────────────────────────────────────

class _GlowSeekBar extends StatefulWidget {
  final PlayerProvider provider;
  final Color accent;

  const _GlowSeekBar({required this.provider, required this.accent});

  @override
  State<_GlowSeekBar> createState() => _GlowSeekBarState();
}

class _GlowSeekBarState extends State<_GlowSeekBar> {
  bool _dragging = false;
  double _dragVal = 0;


  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    return ValueListenableBuilder<Duration>(
      valueListenable: p.positionListenable,
      builder: (context, position, _) => _buildBar(context, p, position),
    );
  }

  Widget _buildBar(BuildContext context, PlayerProvider p, Duration position) {
    final value = _dragging ? _dragVal : p.progressAt(position);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackShape: _GlowTrackShape(accent: widget.accent),
            thumbShape: _GlowThumbShape(accent: widget.accent),
            overlayShape: SliderComponentShape.noOverlay,
            trackHeight: 3.5,
          ),
          child: Slider(
            value: value.isNaN || value.isInfinite ? 0 : value.clamp(0, 1),
            onChangeStart: (v) => setState(() {
              _dragging = true;
              _dragVal = v;
            }),
            onChanged: (v) => setState(() => _dragVal = v),
            onChangeEnd: (v) {
              p.seekTo(v);
              setState(() => _dragging = false);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(_dragging
                    ? Duration(
                        milliseconds:
                            (_dragVal * p.duration.inMilliseconds).round())
                    : position),
                style: TextStyle(
                  color: AppTheme.textPrimary.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                formatDuration(p.duration),
                style: TextStyle(
                  color: AppTheme.textPrimary.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlowTrackShape extends RoundedRectSliderTrackShape {
  final Color accent;
  const _GlowTrackShape({required this.accent});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    const height = 3.5;
    final top = offset.dy + (parentBox.size.height - height) / 2;
    return Rect.fromLTWH(offset.dx, top, parentBox.size.width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    required TextDirection textDirection,
    double additionalActiveTrackHeight = 2.0,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final canvas = context.canvas;
    final rr = const Radius.circular(4);

    // Trilha inativa
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, rr),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );

    // Trilha ativa com gradiente
    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
    );
    if (activeRect.width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, rr),
        Paint()
          ..shader = LinearGradient(
            colors: [accent.withValues(alpha: 0.6), accent],
          ).createShader(activeRect),
      );
    }
  }
}

class _GlowThumbShape extends SliderComponentShape {
  final Color accent;
  const _GlowThumbShape({required this.accent});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(14, 14);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Glow
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = accent.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Thumb branco
    canvas.drawCircle(center, 6, Paint()..color = Colors.white);
  }
}

// ──────────────────────────────────────────────────────────────
// Controles principais: Anterior, Play/Pause, Próximo
// ──────────────────────────────────────────────────────────────

class _MainControls extends StatelessWidget {
  final PlayerProvider provider;
  const _MainControls({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CtrlButton(
          icon: Icons.skip_previous_rounded,
          size: 34,
          onTap: provider.skipPrevious,
        ),
        _PlayPauseButton(
          isPlaying: provider.isPlaying,
          onTap: provider.togglePlayPause,
        ),
        _CtrlButton(
          icon: Icons.skip_next_rounded,
          size: 34,
          onTap: provider.skipNext,
        ),
      ],
    );
  }
}

class _CtrlButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _CtrlButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  State<_CtrlButton> createState() => _CtrlButtonState();
}

class _CtrlButtonState extends State<_CtrlButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.85,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: Icon(
          widget.icon,
          color: Colors.white,
          size: widget.size,
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseButton({required this.isPlaying, required this.onTap});

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    lowerBound: 0.9,
    upperBound: 1.0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PlayPauseButton old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying == old.isPlaying) return;
    widget.isPlaying ? _pulse.repeat(reverse: true) : _pulse.stop(canceled: false);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlayerProvider>();
    final accent = context.watch<PlayerProvider>().currentAccent;

    return GestureDetector(
      onTap: () {
        provider.togglePlayPause();
      },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.55 * _pulse.value),
                blurRadius: 32 * _pulse.value,
                spreadRadius: 4 * _pulse.value,
              ),
            ],
          ),
          child: child,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: child,
          ),
          child: Icon(
            widget.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            key: ValueKey(widget.isPlaying),
            color: Colors.white,
            size: 38,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Controles secundários: Shuffle, Queue, Repeat
// ──────────────────────────────────────────────────────────────

class _SecondaryControls extends StatelessWidget {
  final PlayerProvider provider;
  final Color accent;

  const _SecondaryControls({required this.provider, required this.accent});

  @override
  Widget build(BuildContext context) {
    final shuffleOn = provider.isShuffle;
    final repeatMode = provider.repeatMode;
    final repeatOn = repeatMode != RepeatMode.none;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SecBtn(
          icon: Icons.shuffle_rounded,
          active: shuffleOn,
          accent: accent,
          onTap: provider.toggleShuffle,
        ),
        _SecBtn(
          icon: Icons.queue_music_rounded,
          active: false,
          accent: accent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QueueScreen()),
          ),
        ),
        _SpeedButton(speed: provider.speed, onTap: () {
          const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
          final idx = speeds.indexOf(provider.speed);
          final next = speeds[(idx < 0 ? 2 : idx + 1) % speeds.length];
          provider.setSpeed(next);
        }, accent: accent),
        _SecBtn(
          icon: repeatMode == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          active: repeatOn,
          accent: accent,
          onTap: provider.cycleRepeatMode,
        ),
      ],
    );
  }
}

class _SecBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _SecBtn({
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(
              icon,
              color: active ? accent : Colors.white.withValues(alpha: 0.4),
              size: 22,
            ),
            const SizedBox(height: 5),
            // Ponto indicador de ativo
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 4 : 0,
              height: active ? 4 : 0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sheet de detalhes da música
// ──────────────────────────────────────────────────────────────

class _SongDetailsSheet extends StatelessWidget {
  final Song song;
  const _SongDetailsSheet({required this.song});


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
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detalhes',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _DetailRow(label: 'Título', value: song.title),
                _DetailRow(label: 'Artista', value: song.artist),
                _DetailRow(label: 'Álbum', value: song.album),
                _DetailRow(label: 'Duração', value: formatDuration(Duration(milliseconds: song.duration))),
                _DetailRow(label: 'Arquivo', value: song.path, multiline: true),
                const SizedBox(height: 8),
                const Divider(color: AppTheme.divider, height: 1),
                const SizedBox(height: 12),
                _SleepTimerSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool multiline;

  const _DetailRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: multiline ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final double speed;
  final Color accent;
  final VoidCallback onTap;

  const _SpeedButton({
    required this.speed,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCustom = speed != 1.0;
    final label = speed == speed.truncateToDouble()
        ? '${speed.toInt()}×'
        : '$speed×';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isCustom ? accent : Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isCustom ? 4 : 0,
              height: isCustom ? 4 : 0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepTimerSection extends StatelessWidget {
  const _SleepTimerSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerProvider>();
    final hasTimer = provider.hasSleepTimer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Timer de Sono',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasTimer)
              GestureDetector(
                onTap: () => context.read<PlayerProvider>().cancelSleepTimer(),
                child: Row(
                  children: [
                    ValueListenableBuilder<Duration?>(
                      valueListenable: provider.sleepTimerRemaining,
                      builder: (context, remaining, _) => Text(
                        remaining == null ? '' : formatDuration(remaining),
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.close_rounded,
                        color: AppTheme.accent, size: 16),
                  ],
                ),
              ),
          ],
        ),
        if (!hasTimer) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [15, 30, 45, 60].map((min) {
              return GestureDetector(
                onTap: () {
                  context
                      .read<PlayerProvider>()
                      .setSleepTimer(Duration(minutes: min));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.3), width: 0.5),
                  ),
                  child: Text(
                    '${min}min',
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

}
