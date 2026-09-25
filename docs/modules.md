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
- Observa o ciclo de vida (`WidgetsBindingObserver`): ao voltar para o primeiro plano, chama `PlayerProvider.refreshPermission()`.
- Escuta `PlayerProvider.errors` e mostra cada mensagem como SnackBar via `scaffoldMessengerKey` do `MaterialApp`.

## `lib/models/`

### `song.dart` — `Song`
Entidade imutável representando uma faixa de áudio.
- Campos: `id` (int, ID do `MediaStore`), `title`, `artist`, `album`, `duration` (ms), `path` (caminho do arquivo).
- `Song.fromSongModel(SongModel)`: constrói a partir do `SongModel` do pacote `on_audio_query`, com fallback `Song.unknownArtist` (`'Artista Desconhecido'`) / `'Álbum Desconhecido'` quando ausentes. `hasKnownArtist` indica se há artista real (usado para decidir a busca de capa no iTunes).
- `toMediaItem()`: converte para `MediaItem` (pacote `audio_service`), usado pelo handler de reprodução.
- `formattedDuration`: getter `mm:ss` (`h:mm:ss` a partir de 1 hora), via a função top-level `formatDuration()` — usada também pelo player e pela fila.
- Igualdade (`==`/`hashCode`) por `id`.

### `playlist.dart` — `Playlist`
Entidade mutável (não `final`) representando uma playlist definida pelo usuário.
- Campos: `id` (String, timestamp), `name` (String, mutável), `songIds` (`List<int>`, mutável), `songPaths` (`Map<int, String>`, caminho do arquivo por `songId`).
- `toJson()`/`fromJson()`: serialização manual (sem `json_serializable`/codegen). `fromJson` tolera JSON antigo (sem `songPaths`) e descarta valores inválidos.
- `decodeIdPathMap()` (top-level): decodifica `{"songId": "path"}` descartando entradas inválidas; usado também para `favorite_paths`.
- `encodeList()`/`decodeList()`: (de)serializa uma lista inteira de playlists para/de uma única string JSON — é assim que é persistida em `SharedPreferences` (chave `'playlists'`).

## `lib/providers/player_provider.dart` — `PlayerProvider`

Único `ChangeNotifier` da aplicação. Concentra **todo** o estado e regras de negócio. Ver detalhamento de API em [api.md](./api.md) e regras em [business-rules.md](./business-rules.md).

Áreas de responsabilidade dentro da mesma classe:
1. Biblioteca de músicas (carregamento via `MediaStore`, ordenação, busca/filtro).
2. Estado de reprodução (música atual, play/pause, posição, duração, shuffle, repeat, velocidade).
3. Favoritos (persistidos em `SharedPreferences`).
4. Playlists (CRUD, persistidas em `SharedPreferences` como JSON).
5. Sleep timer (`Timer` + `Timer.periodic` para contagem regressiva).
6. Artwork externo (busca na iTunes Search API validada por `pickArtworkUrl()`, cache positivo e negativo em `SharedPreferences`, extração da cor da capa via `material_color_utilities` — `_dominantColor()` resolve a imagem pelo `ImageCache`, amostra até 10 mil pixels e chama `seedColorFromPixels()`).

## `lib/services/audio_handler.dart`

### `initAudioService()`
Função top-level que inicializa `AudioService.init(...)` do pacote `audio_service`, configurando canal de notificação Android (`com.hammm.music.channel.audio`), ícone e cor da notificação.

### `HammmAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler`
Encapsula um `AudioPlayer` (pacote `just_audio`) e traduz seus eventos para o modelo `audio_service` (`PlaybackState`, `MediaItem`, `queue`). Expõe:
- `setPlaylist(items, initialIndex)` — carrega a fila com `AudioPlayer.setAudioSources` e inicia reprodução (sem efeito com lista vazia). `queue` e `mediaItem` são atualizados a partir de `sequenceStateStream` (ordem efetiva e `currentSource.tag`). A fila só é reenviada à `MediaSession` quando a sequência efetiva muda (`_lastQueueSources`), não a cada troca de faixa. Estados transitórios inconsistentes do `sequenceStateStream` (índices de shuffle/atual da fila anterior ao carregar uma nova com shuffle ligado) são ignorados (`_isConsistent`) — sem isso, `effectiveSequence` lançava `RangeError`.
- `play/pause/stop/seek/skipToNext/skipToPrevious/skipToQueueItem` — overrides de `BaseAudioHandler`. `stop()` não chama `super.stop()` (conflito com o `pipe` de `playbackState`); `skipToQueueItem` converte o índice da fila exibida para a ordem original.
- Ao atingir `ProcessingState.completed`, pausa e volta ao início da fila.
- Faixa que falha ao carregar é pulada pelo próprio player (`AudioPlayer(maxSkipsOnError: 5)`); o erro chega pelo `errorStream` (just_audio 0.10, inclusive o da faixa inicial) e a faixa com falha sai em `failures` (`Stream<MediaItem>`), que o provider transforma em mensagem de `errors`.
- `setArtUri(itemId, uri)` — capa da notificação por faixa, guardada em `_artUris` e reaplicada a cada `mediaItem` emitido (`MediaItem.==` compara só o `id`).
- `setLoopMode`, `setShuffleModeEnabled`, `setSpeed` — controles adicionais (`setShuffleModeEnabled(true)` reembaralha com a faixa atual primeiro).
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
| `mini_player.dart` | Player compacto persistente (frosted glass/`BackdropFilter`) acima da bottom safe area; abre `PlayerScreen` ao tocar; swipe horizontal para pular faixa; anel de progresso circular na capa; linha de progresso no rodapé com seek por toque/arraste (área de toque de 12 px; arraste começado nela é seek, não swipe; seek só ao soltar). Fica no `bottomNavigationBar` do `HomeScreen`, para o SnackBar flutuante aparecer acima dele. Sem key por música: a animação de entrada roda só quando o mini player aparece, não a cada troca de faixa. |
| `song_tile.dart` | Item de lista de música (usado em `HomeScreen`): capa, título, artista, duração ou barras de equalizer animadas quando tocando; long-press abre sheet "adicionar à playlist". Usa `context.select` (só reconstrói quando muda se ele é a faixa atual/está tocando). A faixa atual usa `currentAccent` (mesma cor do player); as demais, `songAccentColor()`. |
| `gradient_album_art.dart` | `GradientAlbumArt` (capa com fallback determinístico em gradiente por hash do título) e `VinylAlbumArt` (disco de vinil rotativo usado no player). Também expõe `songGradient()`/`songAccentColor()`, usados em várias telas para cor de destaque. A URL de capa de rede é lida com `context.select`; a capa embutida vem de `_CachedLocalArtwork`, que consulta o `MediaStore` uma vez por música/tamanho e guarda os bytes em cache em memória (até 300 entradas, FIFO) — substitui o `QueryArtworkWidget`, que refazia a consulta a cada rebuild. |

## `lib/theme/app_theme.dart`

`AppTheme` — classe estática com paleta de cores (dark, fixa, sem suporte a light mode) e `ThemeData` único (`AppTheme.dark`) usado no `MaterialApp`.

Funções top-level para a cor de destaque extraída das capas: `contrastRatio()` (razão WCAG), `readableAccent()` (clareia até `minAccentContrast` = 4.5 contra o fundo) e `accentFromPalette()` (descarta cinzas abaixo de `minAccentSaturation` = 0.15 e aplica `readableAccent`). Usadas pelo `PlayerProvider` ao definir `paletteAccent`. `seedColorFromPixels()` escolhe a cor da capa a partir dos pixels (`QuantizerCelebi` + `Score` do `material_color_utilities`; `null` sem cor com croma suficiente).

Constantes além da paleta base: `accentLight`, `favorite`, `destructive`, `vinyl`. `AppTheme.dark` define `snackBarTheme` (fundo `card`, flutuante).

## Não identificado

- Não há módulos de backend, workers, filas ou serviços externos além do consumo direto de `on_audio_query`, `audio_service`, `shared_preferences` e `http`.
- Não há separação em pacotes Dart internos (`packages:` no `pubspec.yaml` — inexistente).
