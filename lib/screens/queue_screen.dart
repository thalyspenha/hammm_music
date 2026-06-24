import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textPrimary, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'FILA DE REPRODUÇÃO',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, _) {
          final queue = provider.currentQueue;
          final currentIndex = provider.currentQueueIndex;

          if (queue.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music_rounded,
                      color: AppTheme.textSecondary.withOpacity(0.4), size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma fila ativa',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            itemCount: queue.length,
            itemBuilder: (context, i) {
              final item = queue[i];
              final isCurrent = i == currentIndex;
              return _QueueTile(
                item: item,
                index: i,
                isCurrent: isCurrent,
                onTap: () {
                  provider.skipToQueueItem(i);
                  Navigator.pop(context);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final MediaItem item;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;

  const _QueueTile({
    required this.item,
    required this.index,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: isCurrent
            ? BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                border: const Border(
                  left: BorderSide(color: AppTheme.accent, width: 3),
                ),
              )
            : null,
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: isCurrent
                  ? const Icon(Icons.equalizer_rounded,
                      color: AppTheme.accent, size: 18)
                  : Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title ?? 'Desconhecido',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent
                          ? AppTheme.accent
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: isCurrent
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.artist ?? 'Artista Desconhecido',
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
            if (item.duration != null)
              Text(
                _fmt(item.duration!),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
