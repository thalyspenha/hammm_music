# Backlog

Pendências conhecidas do projeto, verificadas contra o código em 2026-09-24. Origem: auditoria de bugs/melhorias feita em 2026-09-24 e validação no aparelho (Galaxy S25, Android 16).

Ao resolver um item, remova-o daqui no mesmo commit e atualize as docs afetadas.

## Já resolvido (referência)

Tudo abaixo foi validado no Galaxy S25. Regras resultantes em [business-rules.md](./business-rules.md); detalhes de dependências em [dependencies.md](./dependencies.md).

| Commit | O que resolveu |
|---|---|
| `748beaf` | B1–B6: shuffle/índices da fila, `stop()` com `StateError`, poda de órfãos em massa, rebuild por posição, fim da fila, permissão concedida nas Configurações |
| `5794f4c`, `e508fb6` | B7–B11: permissão por versão do Android, erro ao tocar vira SnackBar, race da cor de destaque, validação/cache negativo do iTunes; build com JDK 21 |
| `91ffb67` | B12–B15, reconciliação de favoritos/playlists por caminho, `context.select` + cache de capa local, shuffle/repeat/velocidade persistidos, "anterior" reinicia a faixa |
| `1c4ac6f` | Contraste da cor de destaque com capas escuras; fila não é reenviada a cada troca de faixa; `RangeError` do `sequenceStateStream` com shuffle |
| `38190f7` | `just_audio` 0.10, `audio_service` 0.18.19, `flutter_lints` 6; cor da capa reaproveita o `ImageCache` (sem download duplicado) |
| `15d8e13` | Código morto removido, `flutter analyze` sem avisos, animação do mini player, `RECEIVE_BOOT_COMPLETED` removida; faixa atual "piscando" ao carregar fila nova |
| `1a3e345` | Cache de capas versionado — capas aceitas antes da validação descartadas uma vez |

Descartado: "sessão de áudio não configurada" — o `just_audio` já usa `AudioSessionConfiguration.music()` como padrão. B13 (pedidos de permissão concorrentes) foi corrigido mas não pôde ser reproduzido no aparelho.

## Prioridade média

### Duração de faixas com 1 hora ou mais
- **Onde:** `Song.formattedDuration` (`lib/models/song.dart`) e as funções de formatação duplicadas `_fmt` (`queue_screen.dart`, `player_screen.dart`), `_fmtDuration` e `_fmtRemaining` (`player_screen.dart`).
- **Problema:** todas usam `inMinutes.remainder(60)`, então 1h05min aparece como `05:00`. O teste em `test/song_test.dart` trata isso como comportamento esperado.
- **Sugestão:** uma única função de formatação (`h:mm:ss` quando houver horas) usada em todos os lugares; ajustar o teste.

### Cor de destaque inconsistente entre telas
- **Onde:** `lib/screens/player_screen.dart` (mesma expressão nas linhas do `PlayerScreen` e do `_PlayPauseButton`) e `lib/widgets/mini_player.dart`.
- **Problema:** a cor de destaque é calculada duas vezes no player, e o mini player usa só `songAccentColor()`, ignorando `paletteAccent` — por isso a cor difere entre o mini player e o player em tela cheia.
- **Sugestão:** um getter no provider (ex.: `accentFor(song)`) usado pelas duas telas.

### SnackBar de erro e faixa com falha
- **Onde:** `lib/main.dart` (listener de `PlayerProvider.errors`) e `PlayerProvider.playSong`.
- **Problema:** o SnackBar usa o tema claro padrão, fora do visual escuro do app. Após falha ao tocar, a faixa com erro continua como "atual" no mini player (parada).
- **Sugestão:** definir `snackBarTheme` em `AppTheme.dark`; decidir se a faixa com falha deve ser pulada automaticamente para a próxima.

### `palette_generator` descontinuado
- **Onde:** `pubspec.yaml`, `PlayerProvider._dominantColor()`.
- **Problema:** pacote marcado como descontinuado no pub.dev (funciona, mas não recebe correções).
- **Sugestão:** trocar por `material_color_utilities` (`QuantizerCelebi` + `Score`, algoritmo do Material You, já presente via Flutter). Muda as cores extraídas — validar visualmente.

### `on_audio_query` sem manutenção
- Mantido de propósito (alternativas são forks sem publisher verificado que substituem o código nativo — ver [dependencies.md](./dependencies.md)). Reavaliar se o build quebrar em versão futura do AGP/Gradle.

### `permission_handler` 13 disponível
- Atualização major não aplicada (11 → 13). Uso no código é mínimo; revisar o changelog antes.

## Prioridade baixa

### Cores fixas no código (viola a convenção do `AppTheme`)
- `player_screen.dart` — `Color(0xFFF72585)` no favorito.
- `home_screen.dart` — `Color(0xFF9B8BFF)` num gradiente.
- `playlists_screen.dart` — `Colors.redAccent` (excluir) em dois lugares.
- `gradient_album_art.dart` — `Color(0xFF111111)` no vinil.
- `audio_handler.dart` — `Color(0xFF7C6AFF)` repete `AppTheme.accent`.
- **Sugestão:** criar `AppTheme.favorite`, `AppTheme.destructive`, `AppTheme.vinyl` e usar `AppTheme.accent` na notificação.

### Testes que faltam
- Ordenação + filtro de busca (`_applySortAndFilter`) — extrair para função pura e testar.
- `HammmAudioHandler`: conversão de índices com shuffle, `stop()`, rewind ao completar a fila, "anterior" com >3 s — exigiria mock de `AudioPlayer`.
- Reconciliação por caminho aplicada ao estado do provider (hoje só a função pura `remapIdsByPath` é testada).

### Artefato de build versionado
- `android/build/reports/problems/problems-report.html` está no git e muda a cada build. Remover do índice (`git rm --cached`) e ignorar `android/build/`.

## Não aplicável ao escopo atual

- Build de release assinado com a chave de debug (`android/app/build.gradle`): o app é de uso pessoal e não será publicado na Google Play. Ver [decisions.md](./decisions.md).

## Dados do usuário (não é código)

- As playlists "Hip Hop" (21 músicas) e "Rock" (1) no S25 aparecem vazias: foram salvas só com IDs, antes de o caminho do arquivo existir, e o `MediaStore` já tinha trocado esses IDs. Não são recuperáveis automaticamente; recriá-las ou excluí-las é decisão do usuário.
