# Integrações externas

## Resumo

O app tem **uma única integração de rede externa**: a **iTunes Search API** (Apple), usada para buscar capas de álbum em alta resolução. Todas as demais "integrações" são com APIs/serviços **do próprio sistema operacional Android** (não são serviços de terceiros na rede).

## iTunes Search API

- **Endpoint**: `https://itunes.apple.com/search`
- **Uso**: `PlayerProvider._resolveArtworkUrl()` (`player_provider.dart`)
- **Quando não busca**: faixas sem artista conhecido (`Song.hasKnownArtist` falso — placeholder `'Artista Desconhecido'` ou `<unknown>` do `MediaStore`). Buscar só pelo título casaria com qualquer faixa homônima.
- **Parâmetros enviados**: `term` (URL-encoded `"$artist $title"`), `entity=song`, `limit=5`, `media=music`
- **Autenticação**: nenhuma (API pública, sem chave/token).
- **Uso da resposta**: `pickArtworkUrl()` escolhe o primeiro resultado cujo `artistName` **e** `trackName` batem com a faixa (comparação sem caixa/pontuação/espaços, aceitando que um contenha o outro — ex.: "Faixa (Remastered)", "Artista feat. Outro"). Da URL `artworkUrl100` faz replace de `100x100bb` por `500x500bb` para obter maior resolução. Se nenhum resultado bater, não usa capa de rede.
- **Timeout**: 8 segundos (`.timeout(const Duration(seconds: 8))`), tanto na busca quanto na extração de cor em `_paletteFromUrl()`. A imagem para a cor é carregada como `NetworkImage(url)` — a mesma chave do `Image.network` que exibe a capa —, então o `ImageCache` do Flutter compartilha o download/decodificação entre os dois.
- **Tratamento de erro**: todas as exceções são capturadas silenciosamente — sem log, sem retry imediato, sem feedback ao usuário. Erro de rede/timeout **não** entra no cache negativo (tenta de novo na próxima vez que a faixa tocar). Falha na integração degrada graciosamente para artwork local ou placeholder em gradiente (ver [business-rules.md](./business-rules.md)).
- **Cache positivo**: URL encontrada é armazenada permanentemente em `SharedPreferences` por `songId` (`artwork_url_cache`). O cache é versionado (`artwork_cache_version`): mudar a regra de escolha de capa e incrementar `_artworkCacheVersion` descarta o cache antigo uma vez.
- **Cache negativo**: resposta 200 sem resultado compatível grava o instante da busca em `artwork_miss_cache`; a faixa não é buscada de novo por 7 dias (`_artworkMissTtl`).
- **Rate limiting**: não implementado no lado do cliente (não identificado nenhum controle de taxa de chamadas).

## Integrações com o sistema operacional Android

Não são "integrações externas" no sentido de rede, mas são dependências de plataforma relevantes:

| Serviço/API Android | Pacote Flutter | Uso |
|---|---|---|
| `MediaStore` | `on_audio_query` | Consulta biblioteca de músicas e artwork embutida do dispositivo |
| Media Session / Notificação de mídia | `audio_service` | Controles de reprodução na tela de bloqueio/notificação, integração com botões de mídia de fone/Bluetooth |
| Runtime Permissions (`READ_MEDIA_AUDIO`/`READ_EXTERNAL_STORAGE`) | `permission_handler` | Solicitação de permissão de acesso a mídia |
| `Build.VERSION.SDK_INT` | `MethodChannel` próprio `com.hammm.music/platform` (método `sdkInt`, em `MainActivity.kt`) | Informa a versão da API ao Dart para escolher a permissão de mídia correta |
| `SharedPreferences` (Android) | `shared_preferences` | Armazenamento chave-valor local |
| ExoPlayer (via `just_audio`) | `just_audio` | Decodificação e reprodução de áudio (MP3, FLAC, OGG, AAC, M4A, WAV) |

## Não identificado

- Não há integração com serviços de streaming de música (Spotify, YouTube Music, etc.).
- Não há autenticação OAuth, login social ou backend próprio de usuários.
- Não há analytics, crash reporting (Sentry/Crashlytics) ou telemetria integrados no código atual.
- Não há webhooks, filas de mensagens (SQS/RabbitMQ/Kafka) ou integrações server-to-server — não aplicável a este projeto.
