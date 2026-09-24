# Integrações externas

## Resumo

O app tem **uma única integração de rede externa**: a **iTunes Search API** (Apple), usada para buscar capas de álbum em alta resolução. Todas as demais "integrações" são com APIs/serviços **do próprio sistema operacional Android** (não são serviços de terceiros na rede).

## iTunes Search API

- **Endpoint**: `https://itunes.apple.com/search`
- **Uso**: `PlayerProvider._fetchNetworkArtwork()` (`player_provider.dart`)
- **Parâmetros enviados**: `term` (URL-encoded `"$artist $title"`), `entity=song`, `limit=5`, `media=music`
- **Autenticação**: nenhuma (API pública, sem chave/token).
- **Uso da resposta**: pega `artworkUrl100` do primeiro resultado e faz replace de `100x100bb` por `500x500bb` na URL para obter uma versão em maior resolução.
- **Timeout**: 8 segundos (`.timeout(const Duration(seconds: 8))`), tanto na busca quanto no download da imagem em `_loadPaletteFromUrl()`.
- **Tratamento de erro**: todas as exceções são capturadas silenciosamente (`catch (_) {}`) — sem log, sem retry, sem feedback ao usuário. Falha na integração degrada graciosamente para artwork local ou placeholder em gradiente (ver [business-rules.md](./business-rules.md)).
- **Cache**: resultado (URL) é armazenado permanentemente em `SharedPreferences` por `songId` — a API só é chamada uma vez por música (por instalação do app, até o cache ser limpo/desinstalado).
- **Rate limiting**: não implementado no lado do cliente (não identificado nenhum controle de taxa de chamadas).

## Integrações com o sistema operacional Android

Não são "integrações externas" no sentido de rede, mas são dependências de plataforma relevantes:

| Serviço/API Android | Pacote Flutter | Uso |
|---|---|---|
| `MediaStore` | `on_audio_query` | Consulta biblioteca de músicas e artwork embutida do dispositivo |
| Media Session / Notificação de mídia | `audio_service` | Controles de reprodução na tela de bloqueio/notificação, integração com botões de mídia de fone/Bluetooth |
| Runtime Permissions (`READ_MEDIA_AUDIO`/`READ_EXTERNAL_STORAGE`) | `permission_handler` | Solicitação de permissão de acesso a mídia |
| `SharedPreferences` (Android) | `shared_preferences` | Armazenamento chave-valor local |
| ExoPlayer (via `just_audio`) | `just_audio` | Decodificação e reprodução de áudio (MP3, FLAC, OGG, AAC, M4A, WAV) |

## Não identificado

- Não há integração com serviços de streaming de música (Spotify, YouTube Music, etc.).
- Não há autenticação OAuth, login social ou backend próprio de usuários.
- Não há analytics, crash reporting (Sentry/Crashlytics) ou telemetria integrados no código atual.
- Não há webhooks, filas de mensagens (SQS/RabbitMQ/Kafka) ou integrações server-to-server — não aplicável a este projeto.
