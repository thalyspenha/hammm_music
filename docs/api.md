# API

## Resumo

**O projeto não expõe nenhuma API HTTP/REST/GraphQL própria.** É um aplicativo cliente Flutter sem servidor. Não há `server/`, controllers, rotas HTTP ou framework web no repositório.

O único uso de "API" no sentido HTTP é como **consumidor** de uma API pública de terceiros (iTunes Search API), documentado em [integrations.md](./integrations.md).

A "API pública" real deste projeto é a **superfície de métodos do `PlayerProvider`** (`lib/providers/player_provider.dart`), que as telas chamam via `context.read<PlayerProvider>()` / `context.watch<PlayerProvider>()`. Está documentada abaixo como referência de contrato interno.

## Superfície pública de `PlayerProvider`

### Getters (estado exposto)

| Getter | Tipo | Descrição |
|---|---|---|
| `songs` | `List<Song>` | Lista efetiva para exibição: `_displaySongs` (resultado filtrado) se houver busca ativa, senão `_songs` (biblioteca completa ordenada) |
| `currentSong` | `Song?` | Música atualmente carregada no player |
| `isPlaying` | `bool` | Estado de reprodução |
| `isLoading` | `bool` | `true` durante o scan da biblioteca |
| `hasPermission` | `bool` | Permissão de mídia concedida |
| `isShuffle` | `bool` | Shuffle ativo |
| `repeatMode` | `RepeatMode` (`none`/`one`/`all`) | Modo de repetição |
| `position` / `duration` | `Duration` | Posição atual / duração da faixa (`position` é só leitura pontual — não notifica) |
| `positionListenable` | `ValueListenable<Duration>` | Posição da faixa; atualiza sem `notifyListeners()` — usar com `ValueListenableBuilder` |
| `totalSongs` | `int` | Total de músicas na biblioteca |
| `sortField` | `SortField` (`title`/`artist`/`album`) | Campo de ordenação ativo |
| `favorites` | `Set<int>` (imutável) | IDs de músicas favoritadas |
| `playlists` | `List<Playlist>` (imutável) | Playlists do usuário |
| `speed` | `double` | Velocidade de reprodução |
| `paletteAccent` | `Color?` | Cor dominante extraída da capa da faixa atual |
| `hasSleepTimer` | `bool` | Se há timer de desligamento ativo |
| `sleepTimerRemaining` | `ValueListenable<Duration?>` | Tempo restante do sleep timer, atualizado a cada segundo sem `notifyListeners()` |
| `currentQueue` | `List<MediaItem>` | Fila de reprodução atual |
| `currentQueueIndex` | `int` | Índice da faixa atual na fila |
| `progress` | `double` (0.0–1.0) | Progresso normalizado da faixa atual |
| `progressAt(Duration)` | `double` (0.0–1.0) | Progresso normalizado para uma posição (usado dentro de `ValueListenableBuilder`) |

### Métodos (ações)

| Método | Assinatura | Efeito |
|---|---|---|
| `requestPermission()` | `Future<bool>` | Solicita `Permission.audio` (Android 13+) com fallback para `Permission.storage` |
| `refreshPermission()` | `Future<void>` | Checa o status da permissão sem abrir diálogo; se concedida (ex.: nas Configurações), carrega a biblioteca |
| `loadSongs()` | `Future<void>` | Consulta `MediaStore` via `on_audio_query`, filtra faixas ≤30s, aplica sort/filter; ignorada se já houver carga em andamento |
| `sortBy(SortField)` | `void` | Reordena `_songs` e reaplica busca |
| `search(String)` | `void` | Filtra `_songs` por título/artista/álbum (case-insensitive, substring) |
| `toggleFavorite(int id)` | `Future<void>` | Alterna favorito e persiste em `SharedPreferences` |
| `setSpeed(double)` | `Future<void>` | Altera velocidade de reprodução (repassa a `just_audio`) |
| `setSleepTimer(Duration)` | `void` | Agenda parada automática da reprodução |
| `cancelSleepTimer()` | `void` | Cancela o sleep timer ativo |
| `skipToQueueItem(int index)` | `Future<void>` | Pula para item específico da fila (`index` na ordem exibida em `currentQueue`, já considerando shuffle) |
| `playSong(Song, {List<Song>? playlist})` | `Future<void>` | Monta fila a partir de `playlist` (ou `songs` atual) e inicia reprodução a partir de `song` |
| `togglePlayPause()` | `Future<void>` | Alterna play/pause |
| `skipNext()` / `skipPrevious()` | `Future<void>` | Navega na fila |
| `seekTo(double value)` | `Future<void>` | Seek proporcional (0.0–1.0) sobre a duração atual |
| `toggleShuffle()` | `Future<void>` | Alterna shuffle (repassa a `just_audio`; ao ligar, reembaralha com a faixa atual primeiro) |
| `cycleRepeatMode()` | `void` | Alterna entre `none → one → all → none` |
| `createPlaylist(String name)` | `Future<void>` | Cria playlist com ID = timestamp em ms |
| `deletePlaylist(String id)` | `Future<void>` | Remove playlist |
| `renamePlaylist(String id, String name)` | `Future<void>` | Renomeia playlist |
| `addSongToPlaylist(String playlistId, int songId)` | `Future<void>` | Adiciona música (idempotente — verifica duplicidade) |
| `removeSongFromPlaylist(String playlistId, int songId)` | `Future<void>` | Remove música da playlist |
| `getPlaylistSongs(Playlist)` | `List<Song>` | Resolve `songIds` para objetos `Song` presentes na biblioteca atual |
| `playPlaylist(Playlist)` | `Future<void>` | Toca a playlist inteira a partir da primeira faixa |
| `isFavorited(int id)` | `bool` | Consulta se uma música está favoritada |
| `getArtworkUrl(int songId)` | `String?` | Retorna URL de capa em cache, se houver |

Todos os métodos que alteram estado chamam `notifyListeners()` (exceto posição e contagem do sleep timer, ver acima) — o contrato de "resposta" desta API é reatividade via `ChangeNotifier`, não retorno de valor estruturado (a maioria retorna `Future<void>`).

## Superfície pública de `HammmAudioHandler` (`services/audio_handler.dart`)

Implementa a interface `AudioHandler` do pacote `audio_service` (usada pelo sistema operacional Android para expor controles de mídia na notificação/tela de bloqueio). Ver [modules.md](./modules.md) para detalhamento.

## Não identificado

- Não há endpoints HTTP, GraphQL, gRPC ou WebSocket expostos pelo projeto.
- Não há especificação OpenAPI/Swagger.
- Não há versionamento de API (não aplicável — não é uma API de rede).
