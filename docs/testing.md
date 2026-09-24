# Testes

## Resumo

Existe um conjunto pequeno de **testes unitários** cobrindo a lógica pura dos modelos (`lib/models/`) e funções puras top-level do provider, em `test/`. Não há testes de widget, de integração, nem E2E — a cobertura é intencionalmente limitada ao que é testável sem mockar plugins de plataforma (`on_audio_query`, `audio_service`, `shared_preferences`, `permission_handler`), que exigiriam infraestrutura de mocks não configurada neste projeto.

## Testes existentes

| Arquivo | Cobre |
|---|---|
| `test/song_test.dart` | `Song.formattedDuration` (mm:ss, zero, >1h), igualdade/`hashCode` por `id`, `toMediaItem()`, `hasKnownArtist` |
| `test/artwork_match_test.dart` | `pickArtworkUrl()`: aceita resultado com artista+título compatíveis (inclui variações "Remastered"/"feat.", caixa e pontuação), ignora outros artistas e campos ausentes |
| `test/readable_accent_test.dart` | `readableAccent()`/`accentFromPalette()`/`contrastRatio()`: mantém cor já legível, clareia cor escura até o contraste mínimo preservando o matiz, preto não trava, cinzas descartados |
| `test/remap_by_path_test.dart` | `remapIdsByPath()`: troca ID antigo pelo novo via caminho, ignora IDs válidos e caminhos que sumiram |
| `test/orphan_prune_test.dart` | `orphanIdsToPrune()` (`player_provider.dart`): remoção de órfãos, guard de biblioteca vazia e de sumiço em massa (>50%), limite inclusivo |
| `test/playlist_test.dart` | `songPaths` no roundtrip, JSON antigo sem `songPaths`, descarte de IDs/caminhos inválidos; `Playlist.toJson()`/`fromJson()` roundtrip, construtor sem `songIds`, `encodeList()`/`decodeList()` roundtrip (múltiplas playlists e lista vazia), mutabilidade de `name`/`songIds` |

Rodar com:

```bash
flutter test
```

## Configuração de teste presente

- `pubspec.yaml` declara `dev_dependencies: flutter_test: sdk: flutter`.
- `flutter_lints: ^6.0.0` está configurado (`analysis_options.yaml` inclui `package:flutter_lints/flutter.yaml`) — há análise estática/lint além dos testes; `flutter analyze` está sem nenhum aviso.

## Cobertura

- Cobertura restrita a `lib/models/` e a funções puras top-level (ex.: `orphanIdsToPrune`, `pickArtworkUrl`, `remapIdsByPath`, marcadas `@visibleForTesting`). A classe `PlayerProvider`, o `HammmAudioHandler` e as telas **não têm testes** — exigiriam mocks de `on_audio_query`, `audio_service`, `just_audio`, `shared_preferences` e `permission_handler`, ou testes de widget/integração rodando em ambiente com plugins registrados.
- Não identificado nenhum framework de teste E2E (ex. `patrol`, `integration_test` do próprio Flutter) configurado.
- Não há relatório de cobertura (`coverage/lcov.info`) gerado/versionado.

## Áreas ainda sem cobertura (risco de regressão silenciosa)

Com base nas regras de negócio levantadas em [business-rules.md](./business-rules.md):

- `PlayerProvider._applySortAndFilter()` — ordenação + filtro de busca combinados.
- `PlayerProvider.playSong()` / resolução de fila de reprodução.
- `PlayerProvider.getPlaylistSongs()` / `_pruneOrphans()` — resolução e persistência da limpeza (a decisão de quais IDs podar já é testada via `orphanIdsToPrune`).
- `HammmAudioHandler` — conversão de índices com shuffle (`skipToQueueItem`, `queueIndex`), `stop()` e rewind ao completar a fila.
- Lógica de sleep timer (`setSleepTimer`/`cancelSleepTimer`) — uso de `Timer`/`Timer.periodic`.
- `_resolveArtworkUrl()`/`_paletteFromUrl()` — requisições HTTP, cache negativo com TTL e descarte de cor de faixa antiga (a escolha do resultado já é testada via `pickArtworkUrl`).
- Fluxo de permissão (`requestPermission()`/`isPermissionPermanentlyDenied`) — depende de `permission_handler`, não testável sem mock de platform channel.

## Não identificado

- Não há testes manuais documentados (roteiros de QA, checklists de regressão).
- Não há pipeline de CI que rode `flutter test`/`flutter analyze` automaticamente (ver [infrastructure.md](./infrastructure.md)).
