# Hammm Music

Player de música **local e offline** para Android, feito em Flutter. Sem streaming, sem conta, sem internet obrigatória — toca os arquivos de áudio que já estão no aparelho.

Projeto pessoal/hobby, sem publicação na Google Play.

## Features

- Biblioteca lida direto do `MediaStore` do Android (MP3, FLAC, OGG, AAC, M4A, WAV)
- Busca e ordenação (título / artista / álbum) com agrupamento alfabético
- Player em tela cheia com vinyl art rotativo, seekbar customizada e cor de destaque por música
- Mini player persistente (frosted glass) com anel de progresso e swipe pra pular faixa
- Playlists (criar, renomear, excluir, adicionar/remover música)
- Favoritos persistentes
- Fila de reprodução com navegação direta
- Shuffle, repeat (nenhum / uma / todas) e controle de velocidade
- Sleep timer
- Capa de álbum em alta resolução via iTunes Search API, com fallback pra artwork local e depois gradiente gerado por música
- Controles de mídia na notificação / tela de bloqueio (via `audio_service`)

## Stack

Flutter/Dart · `just_audio` + `audio_service` (reprodução e notificação) · `on_audio_query` (MediaStore) · `provider` (estado) · `shared_preferences` (persistência local) · `permission_handler` · `palette_generator` · `http`

Detalhes completos em [`docs/dependencies.md`](./docs/dependencies.md).

## Requisitos

- Flutter SDK compatível com Dart `>=3.3.0 <4.0.0`
- Android SDK — `minSdk 26` (Android 8.0+)
- Dispositivo ou emulador Android (projeto é Android-only, sem suporte a iOS/web/desktop)

## Como rodar

```bash
flutter pub get
flutter run
```

No primeiro uso, o app pede permissão de acesso a mídia (`READ_MEDIA_AUDIO` no Android 13+, `READ_EXTERNAL_STORAGE` em versões anteriores) para escanear a biblioteca local.

## Estrutura do projeto

```
lib/
├── main.dart          # bootstrap e injeção do PlayerProvider
├── models/            # Song, Playlist
├── providers/         # PlayerProvider (estado global único)
├── services/          # HammmAudioHandler (just_audio + audio_service)
├── screens/           # Home, Player, Playlists, PlaylistDetail, Queue
├── widgets/           # MiniPlayer, SongTile, GradientAlbumArt/VinylAlbumArt
└── theme/             # AppTheme (paleta e ThemeData)
```

## Documentação

Documentação técnica detalhada em [`/docs`](./docs), incluindo arquitetura, regras de negócio, persistência de dados, integrações e infraestrutura de build — ver também [`CLAUDE.md`](./CLAUDE.md) para um resumo rápido.

- [`docs/architecture.md`](./docs/architecture.md)
- [`docs/modules.md`](./docs/modules.md)
- [`docs/database.md`](./docs/database.md)
- [`docs/api.md`](./docs/api.md)
- [`docs/business-rules.md`](./docs/business-rules.md)
- [`docs/integrations.md`](./docs/integrations.md)
- [`docs/infrastructure.md`](./docs/infrastructure.md)
- [`docs/testing.md`](./docs/testing.md)
- [`docs/dependencies.md`](./docs/dependencies.md)
- [`docs/decisions.md`](./docs/decisions.md)
- [`docs/backlog.md`](./docs/backlog.md)
