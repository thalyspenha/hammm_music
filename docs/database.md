# Banco de dados

## Resumo

**Não há banco de dados relacional, NoSQL ou servidor de dados no projeto.** Não há `sqflite`, `drift`, `hive`, `isar`, `firebase`, ORM ou schema de migrations no `pubspec.yaml` nem no código.

Toda persistência local é feita via **`shared_preferences`** (armazenamento chave-valor simples do sistema operacional, `SharedPreferences` no Android). Adicionalmente, o app **lê** (não escreve) a biblioteca de mídia do dispositivo através do **`MediaStore`** do Android, via o pacote `on_audio_query`.

## Armazenamento local (`shared_preferences`)

Todas as chaves são lidas/escritas exclusivamente em `lib/providers/player_provider.dart`.

| Chave | Tipo armazenado | Formato | Escrita em | Leitura em |
|---|---|---|---|---|
| `favorites` | `List<String>` (IDs de música como string) | lista de strings nativa do `SharedPreferences`; valores não numéricos são ignorados na leitura | `_saveFavorites()` | `_loadFavorites()` (no construtor do provider) |
| `favorite_paths` | `String` (JSON) | `Map<String songId, String path>` — caminho do arquivo de cada favorito, usado para reconciliar IDs (ver Relacionamentos) | `_saveFavorites()` | `_loadFavorites()` |
| `shuffle` | `bool` | nativo | `toggleShuffle()` | `_loadPlaybackPrefs()` (no construtor) |
| `repeat_mode` | `int` | índice de `RepeatMode` (`none`=0, `one`=1, `all`=2) | `cycleRepeatMode()` | `_loadPlaybackPrefs()` |
| `speed` | `double` | nativo | `setSpeed()` | `_loadPlaybackPrefs()` |
| `playlists` | `String` (JSON) | `Playlist.encodeList()` → `jsonEncode(List<Map>)` | `_savePlaylists()` (chamado após create/delete/rename/add/remove) | `_loadPlaylists()` (no construtor do provider) |
| `artwork_url_cache` | `String` (JSON) | `Map<String songId, String artworkUrl>` serializado, limitado a `_maxArtworkCacheEntries` (500) entradas — ao exceder, remove a mais antiga (FIFO, ordem de inserção do `Map`) | `_saveArtworkCaches()` | `_loadArtworkUrlCache()` (no construtor do provider) |
| `artwork_miss_cache` | `String` (JSON) | `Map<String songId, int epochMs>` — instante da última busca no iTunes sem resultado compatível; mesmo limite de 500 entradas (FIFO). Entradas valem por 7 dias (`_artworkMissTtl`) | `_saveArtworkCaches()` | `_loadArtworkUrlCache()` (no construtor do provider) |

Nenhuma dessas chaves possui expiração no `SharedPreferences` (a validade de 7 dias do `artwork_miss_cache` é checada em código), versionamento de schema ou migração — mudanças de formato exigiriam tratamento manual de compatibilidade (não implementado).

### Entidade: Favoritos
- Representado apenas como `Set<int>` em memória (`PlayerProvider._favorites`), sem entidade própria.
- Persistido como lista de strings (conversão `int → String` na escrita, `String → int` na leitura via `int.parse`).

### Entidade: Playlist
Ver [`models/playlist.dart`](../lib/models/playlist.dart) — campos `id` (String), `name` (String), `songIds` (`List<int>`), `songPaths` (`Map<int, String>`, caminho do arquivo de cada música; JSON `{"songId": "path"}`, ausente em playlists salvas antes de 2026-09-24). `fromJson` ignora IDs/caminhos inválidos em vez de falhar. Serializada/desserializada manualmente (sem codegen).

### Cache: Artwork URL
- `Map<int songId, String url>` em memória (`PlayerProvider._artworkUrlCache`), persistido como JSON.
- Cache de URLs de capa em alta resolução obtidas da iTunes Search API (ver [integrations.md](./integrations.md)) — evita repetir a busca de rede para a mesma música.

## Fonte de dados externa: `MediaStore` (Android)

O app não possui seu próprio catálogo de músicas — ele consulta o `MediaStore` do Android (índice nativo de mídia do sistema operacional) através de `OnAudioQuery().querySongs()` (pacote `on_audio_query`), em `PlayerProvider.loadSongs()`.

- **Somente leitura**: o app nunca escreve no `MediaStore`.
- **Filtro aplicado no cliente**: faixas com duração ≤ 30000ms (30s) são descartadas (heurística para excluir toques de notificação/efeitos sonoros curtos — ver `loadSongs()` em `player_provider.dart`).
- **Campos consultados por música**: `id`, `title`, `artist`, `album`, `duration`, `data` (caminho do arquivo) — mapeados para a entidade `Song`.
- **Artwork embutida**: `OnAudioQuery().queryArtwork(songId, ArtworkType.AUDIO)` é usado como fallback quando não há capa em cache da API externa.

## Relacionamentos

```
Song (não persistida — vem do MediaStore a cada loadSongs())
  ├─ id (chave usada como referência em outras estruturas)
  │
  ├──< Playlist.songIds        (N:N lógico — um songId pode estar em N playlists)
  │      + Playlist.songPaths   (songId → caminho do arquivo)
  │
  ├──< PlayerProvider._favorites (N:N lógico — Set de IDs favoritados)
  │      + favorite_paths       (songId → caminho do arquivo)
  │
  └──< artwork_url_cache        (1:1 — no máximo uma URL de capa em cache por songId)
```

Não há chaves estrangeiras reais nem constraints de banco — a integridade é mantida em código. A cada `loadSongs()` bem-sucedido, primeiro `PlayerProvider._reconcileByPath()` troca IDs que não existem mais pelo ID atual do **mesmo arquivo** (casando pelo caminho salvo — `remapIdsByPath()`), cobrindo o caso do `MediaStore` reindexar a biblioteca e trocar os IDs; também preenche o caminho de IDs válidos que ainda não o tinham. Depois, `PlayerProvider._pruneOrphans()` (`player_provider.dart`) compara `favorites`/`Playlist.songIds` com o conjunto atual de IDs do `MediaStore` e remove (e persiste a remoção) qualquer `songId` que não existe mais — evita acúmulo de IDs órfãos quando um arquivo é apagado do dispositivo. A poda é adiada se a biblioteca vier vazia ou se mais de 50% dos IDs referenciados sumirem de uma vez (`orphanIdsToPrune()`), para não apagar dados quando o `MediaStore` está incompleto. `artwork_url_cache` não passa por essa limpeza de órfãos, mas tem tamanho limitado (ver tabela acima) para não crescer sem limite.

## Não identificado

- Não há schema versionado, migrations ou ferramenta de administração de dados.
- Não há backup/restore de dados do usuário (favoritos/playlists) — mencionado como ideia futura em memória de projeto, mas não implementado no código atual.
