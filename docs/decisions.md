# Decisões técnicas

Não há ADRs (Architecture Decision Records) formais no repositório. As decisões abaixo foram reconstruídas a partir de **comentários explícitos deixados no próprio código-fonte** — são as únicas justificativas de decisão rastreáveis de forma confiável. O histórico de commits não ajuda a reconstruir decisões adicionais: o repositório tem um único commit (`47365a7 projeto android`), sem granularidade histórica.

## `minSdk = 26` (Android 8.0)

> Comentário em `android/app/build.gradle:23`: `// Android 8.0 — garante suporte a FLAC nativo e audio_service`

Decisão: não suportar dispositivos abaixo do Android 8.0, para garantir decodificação nativa de FLAC pelo ExoPlayer e compatibilidade sem workarounds com o pacote `audio_service`.

## `compileSdk = 36`

> Comentário em `android/app/build.gradle:9`: `// alguns plugins (audio_service, sqflite_android) exigem >= 35/36`

Decisão: usar uma `compileSdk` mais recente que o `targetSdk` (34) especificamente para satisfazer requisitos mínimos de compilação de dependências de terceiros.

## Workaround de `namespace` para subprojetos Gradle

> Comentário em `android/build.gradle:13-16`: aplica fix de `namespace`/Java target apenas em plugins que ainda não declaram `namespace` (ex.: `on_audio_query_android`), para compatibilidade com AGP9/JDK17, sem afetar plugins já modernizados.

Decisão: manter compatibilidade com plugins desatualizados sem forçar downgrade do Android Gradle Plugin/JDK do projeto.

## Filtro de faixas curtas (≤ 30s)

> `player_provider.dart:145`: `// filtra faixas com menos de 30 segundos (ringtones, efeitos)`

Decisão de produto: excluir da biblioteca qualquer arquivo de áudio curto indexado pelo `MediaStore`, assumindo que são toques/efeitos sonoros e não músicas.

## Prioridade de artwork: rede > local > gradiente

Implícito na ordem de chamadas em `_loadPaletteForSong()` (`player_provider.dart:251-274`): tenta buscar artwork em alta resolução via iTunes Search API primeiro; só recorre à artwork embutida no arquivo local se a busca de rede falhar ou não retornar cor.

Decisão de produto: priorizar qualidade visual (capa em alta resolução) sobre uso de dados/latência, mas com timeout curto (8s) e cache permanente para mitigar o custo repetido.

## `allowBackup="false"`

`AndroidManifest.xml:23`. Decisão (sem comentário explícito no código, mas explícita na configuração): dados do app (favoritos, playlists) não são incluídos em backups automáticos do Android — **não confirmado no código se foi intencional por privacidade/simplicidade ou um valor padrão não revisado**.

## Build de release assinado com chave de debug

`android/app/build.gradle:31`: `signingConfig signingConfigs.debug` no bloco `release`. Não há comentário explicando o motivo, mas é consistente com o escopo do projeto: uso pessoal/hobby, sem publicação na Google Play — uma keystore de produção não é necessária neste contexto. Ver [infrastructure.md](./infrastructure.md).

## Estado global único (`PlayerProvider`)

Não há comentário no código justificando a escolha por um único `ChangeNotifier` monolítico em vez de múltiplos providers especializados. É uma decisão implícita de simplicidade, coerente com o tamanho atual do projeto (app pessoal, sem múltiplos colaboradores).

## Não identificado

- Não há registro de decisões rejeitadas/alternativas consideradas (ex.: por que `provider` e não `riverpod`/`bloc`; por que `shared_preferences` e não `hive`/`sqflite`) além do que está implícito na escolha final.
- Não há changelog (`CHANGELOG.md`) ou release notes no repositório.
- Não há discussões de PR/issues a consultar (histórico de git é de um único commit).
