import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, _) {
          final playlists = provider.playlists;
          if (playlists.isEmpty) {
            return const _EmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              return _PlaylistCard(playlist: playlists[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreatePlaylistDialog(),
    );
  }
}

// ───────────────────────────────────────────────
// Card de playlist
// ───────────────────────────────────────────────

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;

  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final songCount = playlist.songIds.length;
    final subtitle = songCount == 1 ? '1 música' : '$songCount músicas';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlaylistDetailScreen(playlist: playlist),
            ),
          );
        },
        onLongPress: () => _showOptionsSheet(context),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.queue_music_rounded,
                    color: AppTheme.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaylistOptionsSheet(playlist: playlist),
    );
  }
}

// ───────────────────────────────────────────────
// Bottom sheet de opções (long press)
// ───────────────────────────────────────────────

class _PlaylistOptionsSheet extends StatelessWidget {
  final Playlist playlist;

  const _PlaylistOptionsSheet({required this.playlist});

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
                color: AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Text(
                  playlist.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _SheetOption(
            icon: Icons.drive_file_rename_outline_rounded,
            label: 'Renomear',
            onTap: () {
              // Usa o context do navigator (não o da sheet, que é desmontada
              // pelo pop) para abrir o diálogo.
              final navigator = Navigator.of(context);
              navigator.pop();
              showDialog(
                context: navigator.context,
                builder: (_) => _RenamePlaylistDialog(playlist: playlist),
              );
            },
          ),
          _SheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Excluir',
            isDestructive: true,
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              _showDeleteConfirmation(navigator.context);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Excluir playlist',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Tem certeza que deseja excluir "${playlist.name}"? Esta ação não pode ser desfeita.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<PlayerProvider>().deletePlaylist(playlist.id);
              Navigator.pop(context);
            },
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : AppTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────
// Dialog: criar playlist
// ───────────────────────────────────────────────

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _create() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Digite um nome para a playlist');
      return;
    }
    context.read<PlayerProvider>().createPlaylist(name);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Nova playlist',
        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        cursorColor: AppTheme.accent,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _create(),
        decoration: InputDecoration(
          hintText: 'Nome da playlist',
          errorText: _error,
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.6),
            fontSize: 14,
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.divider),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.accent),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _create,
          child: const Text(
            'Criar',
            style: TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────
// Dialog: renomear playlist
// ───────────────────────────────────────────────

class _RenamePlaylistDialog extends StatefulWidget {
  final Playlist playlist;

  const _RenamePlaylistDialog({required this.playlist});

  @override
  State<_RenamePlaylistDialog> createState() => _RenamePlaylistDialogState();
}

class _RenamePlaylistDialogState extends State<_RenamePlaylistDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.playlist.name);
    _ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _ctrl.text.length,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _rename() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Digite um nome para a playlist');
      return;
    }
    context.read<PlayerProvider>().renamePlaylist(widget.playlist.id, name);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Renomear playlist',
        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        cursorColor: AppTheme.accent,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _rename(),
        decoration: InputDecoration(
          hintText: 'Novo nome',
          errorText: _error,
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.6),
            fontSize: 14,
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.divider),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.accent),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _rename,
          child: const Text(
            'Salvar',
            style: TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────
// Estado vazio
// ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.card,
            ),
            child: const Icon(
              Icons.queue_music_rounded,
              color: AppTheme.textSecondary,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhuma playlist criada',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toque em + para criar sua primeira playlist.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
