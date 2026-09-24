# Módulos

O projeto é um único módulo Flutter/Dart (`hammm_music`, `pubspec.yaml`), sem monorepo, sem múltiplos pacotes internos e sem workspace. Não há separação em `packages/*` nem módulos Gradle além do padrão `android/app`. A organização abaixo é por pasta/responsabilidade dentro de `lib/`.

## `lib/main.dart`

Ponto de entrada. Responsabilidades:
- Inicializa bindings do Flutter (`WidgetsFlutterBinding.ensureInitialized()`).
- Configura a barra de status/navegação do sistema (transparente, ícones claros).
- Força orientação retrato (`portraitUp`/`portraitDown`).
- Inicializa `audio_service` via `initAudioService()`.
- Cria o `ChangeNotifierProvider<PlayerProvider>` raiz.
- Define `HammmApp` (`MaterialApp`, tema único `AppTheme.dark`, tela inicial `HomeScreen`).
- No primeiro frame pós-build, solicita permissão de mídia e, se concedida, carrega a biblioteca de músicas.

## `lib/models/`

### `song.dart` — `Song`
Entidade imutável representando uma faixa de áudio.
- Campos: `id` (int, ID do `MediaStore`), `title`, `artist`, `album`, `duration` (ms), `path` (caminho do arquivo).
- `Song.fromSongModel(SongModel)`: constrói a partir do `SongModel` do pacote `on_audio_query`, com fallback `'Artista Desconhecido'` / `'Álbum Desconhecido'` quando ausentes.
- `toMediaItem()`: converte para `MediaItem` (pacote `audio_service`), usado pelo handler de reprodução.
- `formattedDuration`: getter `mm:ss`.
- Igualdade (`==`/`hashCode`) por `id`.

### `playlist.dart` — `Playlist`
Entidade mutável (não `final`) representando uma playlist definida pelo usuário.
- Campos: `id` (String, timestamp), `name` (String, mutável), `songIds` (`List<int>`, mutável).
- `toJson()`/`fromJson()`: serialização manual (sem `json_serializable`/codegen).
- `encodeList()`/`decodeList()`: (de)serializa uma lista inteira de playlists para/de uma única string JSON — é assim que é persistida em `SharedPreferences` (chave `'playlists'`).

## `lib/providers/player_provider.dart` — `PlayerProvider`

Único `ChangeNotifier` da aplicação. Concentra **todo** o estado e regras de negócio. Ver detalhamento de API em [api.md](./api.md) e regras em [business-rules.md](./business-rules.md).

Áreas de responsabilidade dentro da mesma classe:
1. Biblioteca de músicas (carregamento via `MediaStore`, ordenação, busca/filtro).
2. Estado de reprodução (música atual, play/pause, posição, duração, shuffle, repeat, velocidade).
3. Favoritos (persistidos em `SharedPreferences`).
4. Playlists (CRUD, persistidas em `SharedPreferences` como JSON).
5. Sleep timer (`Timer` + `Timer.periodic` para contagem regressiva).
6. Artwork externo (busca na iTunes Search API, cache de URL em `SharedPreferences`, extração de cor dominante via `palette_generator`).

## `lib/services/audio_handler.dart`

### `initAudioService()`
Função top-level que inicializa `AudioService.init(...)` do pacote `audio_service`, configurando canal de notificação Android (`com.hammm.music.channel.audio`), ícone e cor da notificação.

### `HammmAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler`
Encapsula um `AudioPlayer` (pacote `just_audio`) e traduz seus eventos para o modelo `audio_service` (`PlaybackState`, `MediaItem`, `queue`). Expõe:
- `setPlaylist(items, initialIndex)` — monta `ConcatenatingAudioSource` e inicia reprodução.
- `play/pause/stop/seek/skipToNext/skipToPrevious/skipToQueueItem` — overrides de `BaseAudioHandler`.
- `setLoopMode`, `setShuffleModeEnabled`, `setSpeed` — controles adicionais.
- `positionStream`, `durationStream` — streams expostas para o provider.
- `onTaskRemoved()` — para o player quando a task é removida do recents (evita playback "fantasma").

## `lib/screens/`

| Arquivo | Responsabilidade |
|---|---|
| `home_screen.dart` | Tela principal: header animado (compacta no scroll), busca embutida, lista de músicas agrupada por letra inicial, bottom sheet de ordenação, estados de permissão/loading/vazio. |
| `player_screen.dart` | Player em tela cheia: fundo em gradiente animado por música, vinyl art rotativo, seekbar com glow customizado, controles principais/secundários, sleep timer, sheet de detalhes da faixa. |
| `playlists_screen.dart` | Lista de playlists, criar/renomear/excluir (dialogs + bottom sheet de opções via long-press). |
| `playlist_detail_screen.dart` | Músicas de uma playlist específica, botão "Tocar tudo", remoção individual de faixa. |
| `queue_screen.dart` | Fila de reprodução atual (`handler.queue.value`), toque para pular direto para o item. |

## `lib/widgets/`

| Arquivo | Responsabilidade |
|---|---|
| `mini_player.dart` | Player compacto persistente (frosted glass/`BackdropFilter`) acima da bottom safe area; abre `PlayerScreen` ao tocar; swipe horizontal para pular faixa; anel de progresso circular na capa. |
| `song_tile.dart` | Item de lista de música (usado em `HomeScreen`): capa, título, artista, duração ou barras de equalizer animadas quando tocando; long-press abre sheet "adicionar à playlist". |
| `gradient_album_art.dart` | `GradientAlbumArt` (capa com fallback determinístico em gradiente por hash do título) e `VinylAlbumArt` (disco de vinil rotativo usado no player). Também expõe `songGradient()`/`songAccentColor()`, usados em várias telas para cor de destaque. |

## `lib/theme/app_theme.dart`

`AppTheme` — classe estática com paleta de cores (dark, fixa, sem suporte a light mode) e `ThemeData` único (`AppTheme.dark`) usado no `MaterialApp`.

## Não identificado

- Não há módulos de backend, workers, filas ou serviços externos além do consumo direto de `on_audio_query`, `audio_service`, `shared_preferences` e `http`.
- Não há separação em pacotes Dart internos (`packages:` no `pubspec.yaml` — inexistente).
