# Testes

## Resumo

**Não há testes automatizados no projeto.** Busca explícita por diretórios/arquivos de teste:

```
find . -path "*/test*" -not -path "*/build/*" -not -path "*/.dart_tool/*"
```

retornou vazio — não existe diretório `test/` (nem o padrão `test/widget_test.dart` que o `flutter create` normalmente gera), nem `integration_test/`.

## Configuração de teste presente

- `pubspec.yaml` declara `dev_dependencies: flutter_test: sdk: flutter` — a dependência de testes está presente no projeto, mas **nenhum arquivo de teste foi escrito**.
- `flutter_lints: ^4.0.0` está configurado (`analysis_options.yaml` inclui `package:flutter_lints/flutter.yaml`) — há análise estática/lint, mas isso não substitui testes funcionais.

## Cobertura

- **0%** — não há testes unitários, de widget ou de integração.
- Não identificado nenhum framework de teste E2E (ex. `patrol`, `integration_test` do próprio Flutter) configurado.

## Áreas de maior risco por ausência de testes

Com base nas regras de negócio levantadas em [business-rules.md](./business-rules.md), as áreas com lógica não trivial e sem cobertura de teste são:

- `PlayerProvider._applySortAndFilter()` — ordenação + filtro de busca combinados.
- `PlayerProvider.playSong()` / resolução de fila de reprodução.
- `Playlist.toJson()`/`fromJson()`/`encodeList()`/`decodeList()` — serialização manual, sensível a mudanças de schema.
- `PlayerProvider.getPlaylistSongs()` — resolução de IDs órfãos.
- Lógica de sleep timer (`setSleepTimer`/`cancelSleepTimer`) — uso de `Timer`/`Timer.periodic`.
- `_fetchNetworkArtwork()`/`_loadPaletteFromUrl()` — integração de rede com múltiplos pontos de falha silenciosa.

## Não identificado

- Não há relatório de cobertura (`coverage/lcov.info` ou similar).
- Não há testes manuais documentados (roteiros de QA, checklists de regressão).
- Não há pipeline de CI que rode `flutter test`/`flutter analyze` automaticamente (ver [infrastructure.md](./infrastructure.md)).
