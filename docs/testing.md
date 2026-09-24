# Testes

## Resumo

Existe um conjunto pequeno de **testes unitários** cobrindo a lógica pura dos modelos (`lib/models/`), em `test/`. Não há testes de widget, de integração, nem E2E — a cobertura é intencionalmente limitada ao que é testável sem mockar plugins de plataforma (`on_audio_query`, `audio_service`, `shared_preferences`, `permission_handler`), que exigiriam infraestrutura de mocks não configurada neste projeto.

## Testes existentes

| Arquivo | Cobre |
|---|---|
| `test/song_test.dart` | `Song.formattedDuration` (mm:ss, zero, >1h), igualdade/`hashCode` por `id`, `toMediaItem()` |
| `test/playlist_test.dart` | `Playlist.toJson()`/`fromJson()` roundtrip, construtor sem `songIds`, `encodeList()`/`decodeList()` roundtrip (múltiplas playlists e lista vazia), mutabilidade de `name`/`songIds` |

Rodar com:

```bash
flutter test
```

## Configuração de teste presente

- `pubspec.yaml` declara `dev_dependencies: flutter_test: sdk: flutter`.
- `flutter_lints: ^4.0.0` está configurado (`analysis_options.yaml` inclui `package:flutter_lints/flutter.yaml`) — há análise estática/lint além dos testes.

## Cobertura

- Cobertura restrita a `lib/models/` (lógica pura, sem dependência de plugin). `PlayerProvider`, `HammmAudioHandler` e as telas **não têm testes** — exigiriam mocks de `on_audio_query`, `audio_service`, `just_audio`, `shared_preferences` e `permission_handler`, ou testes de widget/integração rodando em ambiente com plugins registrados.
- Não identificado nenhum framework de teste E2E (ex. `patrol`, `integration_test` do próprio Flutter) configurado.
- Não há relatório de cobertura (`coverage/lcov.info`) gerado/versionado.

## Áreas ainda sem cobertura (risco de regressão silenciosa)

Com base nas regras de negócio levantadas em [business-rules.md](./business-rules.md):

- `PlayerProvider._applySortAndFilter()` — ordenação + filtro de busca combinados.
- `PlayerProvider.playSong()` / resolução de fila de reprodução.
- `PlayerProvider.getPlaylistSongs()` / `_pruneOrphans()` — resolução e limpeza de IDs órfãos.
- Lógica de sleep timer (`setSleepTimer`/`cancelSleepTimer`) — uso de `Timer`/`Timer.periodic`.
- `_fetchNetworkArtwork()`/`_loadPaletteFromUrl()` — integração de rede com múltiplos pontos de falha silenciosa.
- Fluxo de permissão (`requestPermission()`/`isPermissionPermanentlyDenied`) — depende de `permission_handler`, não testável sem mock de platform channel.

## Não identificado

- Não há testes manuais documentados (roteiros de QA, checklists de regressão).
- Não há pipeline de CI que rode `flutter test`/`flutter analyze` automaticamente (ver [infrastructure.md](./infrastructure.md)).
