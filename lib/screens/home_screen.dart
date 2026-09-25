import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import 'playlists_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _searchActive = false;
  bool _headerCompact = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final compact = _scrollCtrl.offset > 60;
      if (compact != _headerCompact) setState(() => _headerCompact = compact);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchCtrl.clear();
        context.read<PlayerProvider>().search('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              compact: _headerCompact,
              searchActive: _searchActive,
              searchCtrl: _searchCtrl,
              onToggleSearch: _toggleSearch,
              onSort: () => _showSortSheet(context),
              onPlaylists: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
              ),
            ),
            Expanded(child: _Body(scrollCtrl: _scrollCtrl)),
            const MiniPlayer(),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SortBottomSheet(),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Cabeçalho com busca embutida e efeito compact no scroll
// ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool compact;
  final bool searchActive;
  final TextEditingController searchCtrl;
  final VoidCallback onToggleSearch;
  final VoidCallback onSort;
  final VoidCallback onPlaylists;

  const _Header({
    required this.compact,
    required this.searchActive,
    required this.searchCtrl,
    required this.onToggleSearch,
    required this.onSort,
    required this.onPlaylists,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(20, compact ? 10 : 18, 12, 8),
      decoration: BoxDecoration(
        color: compact
            ? AppTheme.background.withValues(alpha: 0.95)
            : Colors.transparent,
        border: compact
            ? const Border(
                bottom: BorderSide(color: AppTheme.divider, width: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo / título
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: compact ? 20 : 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: compact ? -0.5 : -1.2,
                ),
                child: const Text('Hammm'),
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                Consumer<PlayerProvider>(
                  builder: (_, p, __) => AnimatedOpacity(
                    opacity: p.totalSongs > 0 ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${p.totalSongs}',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              _HeaderIcon(
                icon: Icons.queue_music_rounded,
                onTap: onPlaylists,
              ),
              // Botão de busca
              _HeaderIcon(
                icon: searchActive
                    ? Icons.close_rounded
                    : Icons.search_rounded,
                onTap: onToggleSearch,
              ),
              _HeaderIcon(
                icon: Icons.tune_rounded,
                onTap: onSort,
              ),
            ],
          ),
          // Barra de busca expansível
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: searchActive
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _SearchBar(ctrl: searchCtrl),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(icon, key: ValueKey(icon), color: AppTheme.textPrimary, size: 24),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  const _SearchBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: TextField(
        controller: ctrl,
        autofocus: true,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
        ),
        cursorColor: AppTheme.accent,
        decoration: InputDecoration(
          hintText: 'Buscar músicas, artistas, álbuns…',
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.textSecondary,
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          isDense: true,
        ),
        onChanged: (v) => context.read<PlayerProvider>().search(v),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Corpo: lista de músicas com separadores alfabéticos
// ──────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final ScrollController scrollCtrl;
  const _Body({required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        if (!provider.hasPermission) {
          return _PermissionState(
            permanentlyDenied: provider.isPermissionPermanentlyDenied,
            onRequest: () async {
              final ok = await provider.requestPermission();
              if (ok) await provider.loadSongs();
            },
            onOpenSettings: () => provider.openPermissionSettings(),
          );
        }

        if (provider.isLoading) {
          return const _LoadingState();
        }

        final songs = provider.songs;
        if (songs.isEmpty) {
          return const _EmptyState();
        }

        return _SongList(
          songs: songs,
          scrollCtrl: scrollCtrl,
          sortField: provider.sortField,
        );
      },
    );
  }
}

class _SongList extends StatelessWidget {
  final List<Song> songs;
  final ScrollController scrollCtrl;
  final SortField sortField;

  const _SongList({
    required this.songs,
    required this.scrollCtrl,
    required this.sortField,
  });

  @override
  Widget build(BuildContext context) {
    final items = _buildItems(songs);

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is _SongEntry) {
          return SongTile(song: item.song, playlist: songs, index: item.index);
        }
        if (item is String) return _AlphaHeader(letter: item);
        return const SizedBox.shrink();
      },
    );
  }

  String _groupKey(Song s) {
    final field = switch (sortField) {
      SortField.title  => s.title,
      SortField.artist => s.artist,
      SortField.album  => s.album,
    };
    if (field.isEmpty) return '#';
    final letter = field[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(letter) ? letter : '#';
  }

  List<Object> _buildItems(List<Song> songs) {
    final result = <Object>[];
    String lastGroup = '';
    int songIndex = 0;
    for (final s in songs) {
      final group = _groupKey(s);
      if (group != lastGroup) {
        result.add(group);
        lastGroup = group;
      }
      result.add(_SongEntry(song: s, index: songIndex));
      songIndex++;
    }
    return result;
  }
}

class _SongEntry {
  final Song song;
  final int index;
  const _SongEntry({required this.song, required this.index});
}

class _AlphaHeader extends StatelessWidget {
  final String letter;
  const _AlphaHeader({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Row(
        children: [
          Text(
            letter,
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 0.5, color: AppTheme.divider),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Estados: permissão, carregando, vazio
// ──────────────────────────────────────────────────────────────

class _LoadingState extends StatefulWidget {
  const _LoadingState();

  @override
  State<_LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<_LoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withValues(alpha: 0.1 + 0.1 * _ctrl.value),
              ),
              child: const Icon(
                Icons.library_music_rounded,
                color: AppTheme.accent,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Escaneando sua biblioteca…',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              backgroundColor: AppTheme.divider,
              valueColor:
                  const AlwaysStoppedAnimation(AppTheme.accent),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.card,
            ),
            child: const Icon(
              Icons.music_off_rounded,
              color: AppTheme.textSecondary,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhuma música encontrada',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adicione arquivos de áudio ao\narmazenamento interno do dispositivo.',
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

class _PermissionState extends StatelessWidget {
  final bool permanentlyDenied;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  const _PermissionState({
    required this.permanentlyDenied,
    required this.onRequest,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone com glow
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.accentLight, AppTheme.accent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.library_music_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Biblioteca de Músicas',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              permanentlyDenied
                  ? 'O acesso à sua música foi negado.\nAbra as configurações do app para permitir manualmente.'
                  : 'Permita o acesso ao armazenamento\npara ver suas músicas locais.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: permanentlyDenied ? onOpenSettings : onRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  permanentlyDenied ? 'Abrir Configurações' : 'Permitir Acesso',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Bottom sheet de ordenação
// ──────────────────────────────────────────────────────────────

class _SortBottomSheet extends StatelessWidget {
  const _SortBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        final current = provider.sortField;
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
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    const Text(
                      'Ordenar por',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _SortOption(
                icon: Icons.sort_by_alpha_rounded,
                label: 'Título',
                subtitle: 'A → Z pelo nome da música',
                isActive: current == SortField.title,
                onTap: () {
                  provider.sortBy(SortField.title);
                  Navigator.pop(context);
                },
              ),
              _SortOption(
                icon: Icons.person_rounded,
                label: 'Artista',
                subtitle: 'Agrupado por intérprete',
                isActive: current == SortField.artist,
                onTap: () {
                  provider.sortBy(SortField.artist);
                  Navigator.pop(context);
                },
              ),
              _SortOption(
                icon: Icons.album_rounded,
                label: 'Álbum',
                subtitle: 'Agrupado por álbum',
                isActive: current == SortField.album,
                onTap: () {
                  provider.sortBy(SortField.album);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  const _SortOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: isActive ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? AppTheme.accent : AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_rounded, color: AppTheme.accent, size: 18),
          ],
        ),
      ),
    );
  }
}
