# hammm_music

## Contexto essencial

Hammm Music é um player de música **local e offline** para Android, em Flutter. Não há backend, conta de usuário ou streaming — o app lê a biblioteca de áudio do próprio dispositivo (`MediaStore`) e reproduz os arquivos localmente. A única chamada de rede é para a iTunes Search API, usada apenas para buscar capas de álbum em alta resolução (feature acessória, com fallback gracioso).

## Stack

- **Flutter/Dart** (SDK `>=3.3.0 <4.0.0`), Android-only (sem iOS/web/desktop).
- Reprodução: `just_audio` (ExoPlayer) + `audio_service` (notificação/mídia em background).
- Biblioteca: `on_audio_query` (consulta ao `MediaStore`).
- Estado: `provider` — um único `ChangeNotifier` (`PlayerProvider`) concentra todo o estado da aplicação.
- Persistência local: `shared_preferences` (chave-valor; favoritos, playlists, cache de URLs de capa) — **não há banco de dados**.
- Rede: `http` (apenas para a iTunes Search API).
- `minSdk 26`, `compileSdk 36`, `targetSdk 34`, Java/Kotlin 17.

## Arquitetura resumida

```
main.dart → PlayerProvider (ChangeNotifier único) → HammmAudioHandler (just_audio + audio_service)
                     ↓
        screens/ (Home, Player, Playlists, PlaylistDetail, Queue)
                     ↓
        widgets/ (MiniPlayer, SongTile, GradientAlbumArt/VinylAlbumArt)
```

Sem camada de repositório/DAO: o `PlayerProvider` acessa diretamente `on_audio_query`, `shared_preferences` e `http`. Detalhes completos em [`docs/architecture.md`](./docs/architecture.md).

## Regras importantes

- Faixas com duração ≤ 30s são filtradas ao carregar a biblioteca (heurística para excluir toques/efeitos).
- Favoritos e playlists referenciam músicas só por `songId` (int); `PlayerProvider._pruneOrphans()` remove automaticamente IDs de músicas apagadas do dispositivo a cada `loadSongs()` bem-sucedido — exceto se a biblioteca vier vazia ou >50% dos IDs sumirem de uma vez (`orphanIdsToPrune()`), para não apagar dados com `MediaStore` incompleto.
- Posição da faixa e contagem do sleep timer ficam em `ValueNotifier`s (`positionListenable`, `sleepTimerRemaining`), **fora** do `notifyListeners()` — não voltar a notificar o provider a cada tick (reconstrói a árvore inteira várias vezes por segundo).
- `queue` do handler usa a ordem **efetiva** (embaralhada com shuffle); `just_audio` `currentIndex`/`seek(index:)` usam a ordem original. Converter via `effectiveIndices` — nunca indexar `queue` com `currentIndex`.
- `HammmAudioHandler.stop()` não pode chamar `super.stop()` (`StateError` por causa do `pipe` em `playbackState`).
- Escritas em favoritos/playlists (`toggleFavorite`, `createPlaylist`, etc.) aguardam o load inicial do `SharedPreferences` (`_favoritesLoaded`/`_playlistsLoaded`) antes de mutar estado — não remover esse `await` ao editar esses métodos.
- Build de release atualmente assina com a chave de **debug** (`android/app/build.gradle`) — não é keystore de produção. Ver [`docs/infrastructure.md`](./docs/infrastructure.md) antes de qualquer publicação.
- Testes unitários cobrem só `lib/models/` e funções puras top-level (ex.: `orphanIdsToPrune`). `PlayerProvider`/telas não têm testes (exigiriam mock de plugins de plataforma). Ver [`docs/testing.md`](./docs/testing.md).

## Convenções de desenvolvimento

- Cada tela em `lib/screens/` expõe um único widget público (`Scaffold`); sub-widgets privados (`_Foo`) ficam no mesmo arquivo, não são exportados.
- Cores/tema centralizados em `lib/theme/app_theme.dart` (`AppTheme`) — não hardcodar cores nos widgets; usar as constantes de `AppTheme` ou `songAccentColor()`/`songGradient()` (`widgets/gradient_album_art.dart`) para cor por música.
- Toda alteração de estado que afeta a UI passa por métodos do `PlayerProvider` seguidos de `notifyListeners()` — não manipular `on_audio_query`/`shared_preferences`/`just_audio` diretamente das telas.
- Serialização de modelos é manual (sem codegen/`json_serializable`) — seguir o padrão de `toJson()`/`fromJson()` já usado em `Playlist`.

## Documentação

Documentação detalhada e verificada contra o código atual está em [`/docs`](./docs):

- [`architecture.md`](./docs/architecture.md) — arquitetura, camadas, fluxo de dados
- [`modules.md`](./docs/modules.md) — responsabilidade de cada arquivo/módulo
- [`database.md`](./docs/database.md) — persistência local (`shared_preferences`) e `MediaStore`
- [`api.md`](./docs/api.md) — superfície pública de `PlayerProvider`/`HammmAudioHandler`
- [`business-rules.md`](./docs/business-rules.md) — regras de negócio extraídas do código
- [`integrations.md`](./docs/integrations.md) — iTunes Search API e integrações com o Android
- [`infrastructure.md`](./docs/infrastructure.md) — build Android, assinatura, permissões
- [`testing.md`](./docs/testing.md) — estado atual de testes
- [`dependencies.md`](./docs/dependencies.md) — pacotes de produção/dev
- [`decisions.md`](./docs/decisions.md) — decisões técnicas rastreadas no código

Onde algo não pôde ser determinado pelo código, os documentos marcam explicitamente "Não identificado" — não presumir informações além do que está lá.
