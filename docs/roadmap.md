# Roadmap

Features planejadas e decisões técnicas em aberto. Bugs e melhorias do código existente ficam em [backlog.md](./backlog.md). Ao concluir um item, remova-o daqui no mesmo commit.

## Próximos passos imediatos

Validado no Galaxy S25 (Android 16) em 2026-09-24: permissão `READ_MEDIA_AUDIO` e reprodução de FLAC. Falta:

1. **Testar OGG/M4A** — não havia arquivos desses formatos na validação.
2. **Splash screen** — não existe hoje. Sugestão: `flutter_native_splash` (logo + fundo `#0A0A0F`).

## Features

### Curto prazo
- **Seek no mini player:** o mini player mostra o progresso mas não permite seek. Adicionar `GestureDetector` horizontal na `_ProgressLine`.

### Médio prazo
- **Tela de álbuns/artistas:** nova aba no `HomeScreen` com `BottomNavigationBar`, usando `on_audio_query.queryAlbums()` e `queryArtists()`.
- **Reordenar fila:** `QueueScreen` só lista e pula; falta reordenar/remover itens.
- **Pesquisa por voz:** `speech_to_text` no campo de busca.
- **Capa na notificação de mídia:** `MediaItem.artUri` não é preenchido. A capa embutida já é lida e guardada em memória por `_CachedLocalArtwork` (`gradient_album_art.dart`), mas a notificação precisa de uma URI: `queryArtwork` → bytes → arquivo temporário → `Uri.file` em `artUri` (ou a URL do iTunes, quando houver).

### Longo prazo
- **Equalizador:** `just_audio` expõe `AndroidEqualizer` via `AudioPipeline`. Tela com presets (Rock, Pop, Classical etc.).
- **Crossfade entre faixas:** verificar se o `just_audio` suporta ou se exige implementação manual com dois players.
- **Letras:** arquivo `.lrc` local (mesmo diretório da música) ou API pública.
- **Tema claro / dinâmico:** `ThemeMode.system` + Material You (`dynamic_color`, Android 12+).
- **Backup/restore:** exportar favoritos e playlists como JSON.

## Decisões técnicas em aberto

- **Um provider ou vários:** hoje só existe `PlayerProvider`. Se crescer, considerar separar em `LibraryProvider` (músicas, busca, ordenação), `PlayerProvider` (reprodução) e `SettingsProvider` (tema, equalizador, preferências).
- **Persistência:** `shared_preferences` atende. Migrar para `hive`/`drift` só se surgir necessidade de consultas.
