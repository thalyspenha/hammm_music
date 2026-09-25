import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  // Cópia local da fila: arrastar/remover atualiza a lista na hora, sem
  // esperar o player aplicar a mudança (senão o item "volta" por um frame e o
  // `Dismissible` reclama de continuar na árvore). Ressincronizada a cada
  // mudança da fila no provider (cada emissão de `queue` é uma lista nova).
  List<MediaItem> _items = const [];
  List<MediaItem>? _syncedQueue;

  void _onReorder(PlayerProvider provider, int from, int to) {
    if (from == to) return;
    setState(() => _items.insert(to, _items.removeAt(from)));
    provider.moveInQueue(from, to);
  }

  void _onRemove(PlayerProvider provider, int index) {
    setState(() => _items.removeAt(index));
    provider.removeFromQueue(index);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerProvider>();
    final queue = provider.currentQueue;
    if (!identical(queue, _syncedQueue)) {
      _syncedQueue = queue;
      _items = List.of(queue);
    }
    final currentPath = provider.currentSong?.path;
    final canReorder = !provider.isShuffle;
    final accent = provider.currentAccent;

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
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music_rounded,
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                      size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma fila ativa',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _QueueHint(canReorder: canReorder),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    buildDefaultDragHandles: false,
                    itemCount: _items.length,
                    onReorderItem: (from, to) => _onReorder(provider, from, to),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final isCurrent = item.id == currentPath;
                      final tile = _QueueTile(
                        item: item,
                        index: i,
                        isCurrent: isCurrent,
                        accent: accent,
                        canReorder: canReorder,
                        onTap: () {
                          provider.skipToQueueItem(i);
                          Navigator.pop(context);
                        },
                      );
                      // A faixa atual não pode ser removida (ver
                      // `HammmAudioHandler.removeQueueItemAt`).
                      if (isCurrent) {
                        return KeyedSubtree(key: ValueKey(item.id), child: tile);
                      }
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: const _RemoveBackground(),
                        onDismissed: (_) => _onRemove(provider, i),
                        child: tile,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _QueueHint extends StatelessWidget {
  final bool canReorder;

  const _QueueHint({required this.canReorder});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Text(
        canReorder
            ? 'Arraste ☰ para reordenar · deslize para a esquerda para remover'
            : 'Desligue o aleatório para reordenar · deslize para a esquerda para remover',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.textSecondary.withValues(alpha: 0.7),
          fontSize: 11,
        ),
      ),
    );
  }
}

class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.destructive.withValues(alpha: 0.15),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Icon(Icons.delete_outline_rounded,
          color: AppTheme.destructive),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final MediaItem item;
  final int index;
  final bool isCurrent;
  final Color accent;
  final bool canReorder;
  final VoidCallback onTap;

  const _QueueTile({
    required this.item,
    required this.index,
    required this.isCurrent,
    required this.accent,
    required this.canReorder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        // Fundo opaco: o item arrastado e o deslizado não mostram o que está
        // por baixo.
        decoration: isCurrent
            ? BoxDecoration(
                color: Color.alphaBlend(
                    accent.withValues(alpha: 0.08),
                    AppTheme.background),
                border: Border(
                  left: BorderSide(color: accent, width: 3),
                ),
              )
            : const BoxDecoration(color: AppTheme.background),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: isCurrent
                  ? Icon(Icons.equalizer_rounded,
                      color: accent, size: 18)
                  : Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
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
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent
                          ? accent
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
                formatDuration(item.duration!),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            if (canReorder)
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.drag_handle_rounded,
                      color: AppTheme.textSecondary, size: 22),
                ),
              ),
          ],
        ),
      ),
    );
  }

}
