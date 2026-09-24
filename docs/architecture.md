# Arquitetura

## Visão geral

Hammm Music é um **aplicativo móvel Flutter, Android-only, 100% local** (offline-first por natureza: não existe backend próprio). Não há servidor, banco de dados relacional, API REST exposta pelo projeto, autenticação de usuário ou infraestrutura de deploy — é um app cliente que lê a biblioteca de mídia do próprio aparelho (`MediaStore` do Android) e reproduz os arquivos de áudio localmente.

A única comunicação de rede feita pelo app é **outbound**, para a API pública do iTunes Search (busca de capa de álbum em alta resolução). Ver [integrations.md](./integrations.md).

## Estilo arquitetural

- **Camadas**: separação por responsabilidade em pastas (`models`, `providers`, `services`, `screens`, `widgets`, `theme`), típica de apps Flutter de porte pequeno/médio.
- **Gerenciamento de estado**: `provider` (pacote `provider: ^6.1.2`), com um único `ChangeNotifier` global — `PlayerProvider` — injetado na raiz da árvore de widgets em `lib/main.dart` via `ChangeNotifierProvider`.
- **Sem camada de repositório/DAO formal**: `PlayerProvider` acessa diretamente `OnAudioQuery`, `SharedPreferences` e `http`. Não há abstração de "repository" ou "use case" — a lógica de negócio vive no provider.
- **Sem injeção de dependência via pacote (get_it, riverpod, etc.)**: a única dependência injetada manualmente é `HammmAudioHandler`, construída em `main()` e passada ao `PlayerProvider` por construtor.

## Diagrama de dependência entre camadas

```
main.dart
  └── initAudioService() ──────────────► services/audio_handler.dart (HammmAudioHandler)
  └── ChangeNotifierProvider
        └── PlayerProvider(handler) ───► providers/player_provider.dart
              ├── usa: models/song.dart, models/playlist.dart
              ├── usa: services/audio_handler.dart (playback)
              ├── usa: on_audio_query (MediaStore)
              ├── usa: shared_preferences (favoritos, playlists, cache de capas)
              ├── usa: http (iTunes Search API)
              └── usa: palette_generator (cor dominante da capa)
  └── HammmApp (MaterialApp)
        └── HomeScreen ──► PlaylistsScreen ──► PlaylistDetailScreen
              └── MiniPlayer ──► PlayerScreen ──► QueueScreen
        (todas as telas consomem PlayerProvider via Consumer/context.watch/context.read)
```

## Fluxo de dados

1. `main()` inicializa `audio_service` (`initAudioService()`), cria `HammmAudioHandler` (que encapsula um `AudioPlayer` do pacote `just_audio`) e injeta `PlayerProvider` na árvore de widgets.
2. No primeiro frame, `HammmApp` solicita permissão de mídia (`PlayerProvider.requestPermission()`) e, se concedida, carrega a biblioteca (`PlayerProvider.loadSongs()`), que consulta `OnAudioQuery().querySongs()`. `HammmApp` também observa o ciclo de vida e chama `refreshPermission()` ao voltar para o primeiro plano.
3. As telas (`screens/*.dart`) são `Consumer`/`context.watch` de `PlayerProvider` e se redesenham reativamente a cada `notifyListeners()`. Exceção: estado de alta frequência (posição da faixa, contagem do sleep timer) fica em `ValueNotifier`s separados (`positionListenable`, `sleepTimerRemaining`), consumidos via `ValueListenableBuilder` só pelos widgets que exibem esses valores.
4. Ações do usuário (tocar, pausar, pular, buscar, favoritar, criar playlist) chamam métodos públicos do `PlayerProvider`, que por sua vez delegam a reprodução real ao `HammmAudioHandler` (`just_audio`) e persistem estado auxiliar (favoritos, playlists, cache de URLs de capa) em `SharedPreferences`.
5. O `HammmAudioHandler` expõe streams (`positionStream`, `durationStream`, `playbackState`, `mediaItem`, `queue`) que o `PlayerProvider` assina em `_subscribeToStreams()` para manter seu próprio estado sincronizado com o player real e notificar a UI.
6. Notificação de mídia em segundo plano (controles na tela de bloqueio / barra de notificações) é gerenciada pelo pacote `audio_service`, que registra `HammmAudioHandler` como `AudioHandler` do sistema Android (serviço `com.ryanheise.audioservice.AudioService` no `AndroidManifest.xml`).

## Estrutura de arquivos (`lib/`)

```
lib/
├── main.dart                        # bootstrap, DI manual, MaterialApp
├── models/
│   ├── song.dart                    # entidade Song (imutável) + mapeamento p/ SongModel e MediaItem
│   └── playlist.dart                # entidade Playlist (mutável) + (de)serialização JSON
├── providers/
│   └── player_provider.dart         # único ChangeNotifier: estado de player, biblioteca, favoritos, playlists, sleep timer, artwork
├── services/
│   └── audio_handler.dart           # HammmAudioHandler extends BaseAudioHandler (audio_service) — encapsula just_audio
├── screens/
│   ├── home_screen.dart             # lista de músicas, busca, ordenação
│   ├── player_screen.dart           # player full-screen (vinyl, seekbar, controles, sleep timer)
│   ├── playlists_screen.dart        # CRUD de playlists
│   ├── playlist_detail_screen.dart  # músicas de uma playlist
│   └── queue_screen.dart            # fila de reprodução atual
├── widgets/
│   ├── mini_player.dart             # player compacto persistente (frosted glass)
│   ├── song_tile.dart               # item de lista de música
│   └── gradient_album_art.dart      # capa com fallback em gradiente + vinyl art
└── theme/
    └── app_theme.dart               # paleta de cores e ThemeData único (dark theme fixo)
```

## Padrão de widget "screen"

Cada tela em `screens/` segue o mesmo padrão: um `Scaffold` público (`StatelessWidget` ou `StatefulWidget`) contendo widgets privados internos (prefixados com `_`) para header, corpo, estados vazios/loading, bottom sheets e diálogos — tudo no mesmo arquivo, sem exportar sub-widgets.

## Não identificado

- Não há documentação prévia de arquitetura (README é o template padrão gerado pelo `flutter create`).
- Não há diagramas de arquitetura pré-existentes no repositório.
