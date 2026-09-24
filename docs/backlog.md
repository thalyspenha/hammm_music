# Backlog

Pendências conhecidas do projeto, verificadas contra o código em 2026-09-24. Origem: auditoria de bugs/melhorias feita em 2026-09-24 e validação no aparelho (Galaxy S25, Android 16).

Ao resolver um item, remova-o daqui no mesmo commit e atualize as docs afetadas.

## Já resolvido (referência)

Da auditoria de 2026-09-24, os bugs B1–B15 foram corrigidos e validados no aparelho (exceto B13, não reproduzível com o diálogo do sistema na frente). Ver commits `748beaf`, `5794f4c`, `e508fb6` e `91ffb67`, e as regras resultantes em [business-rules.md](./business-rules.md).

## Prioridade alta

### Contraste dos ícones ativos com cor de destaque escura
- **Onde:** `lib/screens/player_screen.dart` — controles de shuffle, repeat e velocidade.
- **Problema:** quando a cor dominante extraída da capa (`paletteAccent`) é escura, os ícones ativos ficam quase invisíveis sobre o fundo escuro. Observado no S25 com capas escuras (ex.: "Asylum", "Bad Boy for Life").
- **Sugestão:** garantir contraste mínimo — clarear a cor extraída (ex.: ajustar a luminosidade em HSL) ou cair para `songAccentColor()`/`AppTheme.accent` quando o contraste com `AppTheme.background` for baixo.

### Fila inteira reenviada ao Android a cada troca de faixa
- **Onde:** `lib/services/audio_handler.dart` — listener de `sequenceStateStream` (`queue.add(...)`).
- **Problema:** cada troca de faixa serializa a fila inteira para a `MediaSession`. Com milhares de músicas há risco de `TransactionTooLargeException` (risco teórico, não medido) e custo desnecessário.
- **Sugestão:** só chamar `queue.add` quando a sequência ou a ordem mudarem de fato (comparar com a anterior), não a cada troca de índice.

## Prioridade média

### Sessão de áudio não configurada
- **Onde:** `lib/main.dart` / `initAudioService()`.
- **Problema:** não há `AudioSession.instance.configure(AudioSessionConfiguration.music())`. O `just_audio` já pausa ao desconectar o fone, mas foco de áudio e "ducking" ficam com a configuração padrão.
- **Sugestão:** configurar a sessão como música antes de `initAudioService()`.

### Capa de rede baixada duas vezes
- **Onde:** `PlayerProvider._paletteFromUrl()` e `Image.network` em `gradient_album_art.dart`.
- **Problema:** a capa de 500 px é baixada com `http.get` para extrair a cor e de novo pelo `Image.network` para exibir; a cada vez que uma faixa com capa em cache toca, os bytes são baixados de novo.
- **Sugestão:** usar `NetworkImage(url)` no `PaletteGenerator.fromImageProvider` para reaproveitar o `ImageCache`.

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

### Dependências
- `on_audio_query ^2.9.0` sem manutenção — depende do workaround de namespace/JVM em `android/build.gradle` e de uma edição manual no pub-cache (ver [infrastructure.md](./infrastructure.md)). Avaliar alternativa mantida.
- `just_audio ^0.9.40` (já existe 0.10.x) — atualizar exige revisar APIs usadas no handler.
- `flutter_lints ^4.0.0` (já existe 6.x).

## Prioridade baixa

### Cores fixas no código (viola a convenção do `AppTheme`)
- `player_screen.dart` — `Color(0xFFF72585)` no favorito.
- `home_screen.dart` — `Color(0xFF9B8BFF)` num gradiente.
- `playlists_screen.dart` — `Colors.redAccent` (excluir) em dois lugares.
- `gradient_album_art.dart` — `Color(0xFF111111)` no vinil.
- `audio_handler.dart` — `Color(0xFF7C6AFF)` repete `AppTheme.accent`.
- **Sugestão:** criar `AppTheme.favorite`, `AppTheme.destructive`, `AppTheme.vinyl` e usar `AppTheme.accent` na notificação.

### Código morto e avisos do analyzer
- Getter `HammmAudioHandler.player` sem uso.
- `AppTheme.accentGlow`, `AppTheme.cardElevated` e `bottomNavigationBarTheme` sem uso.
- `item.title ?? 'Desconhecido'` em `queue_screen.dart` — `title` não é nulo (único `warning` do `flutter analyze`).
- ~80 avisos `info`, a maioria `withOpacity` obsoleto (trocar por `withValues`) e `prefer_const`.

### Pequenos ajustes de UX
- Mini player recebe `ValueKey(song.id)` (`mini_player.dart`), então a animação de entrada roda de novo a cada troca de faixa.
- Permissão `RECEIVE_BOOT_COMPLETED` declarada no `AndroidManifest.xml` sem nenhum receiver que a use — remover.

### Capas antigas não revalidadas
- Capas guardadas em `artwork_url_cache` antes da validação de artista/título (`pickArtworkUrl`) não são revalidadas e podem estar erradas.
- **Sugestão:** versionar o cache (ex.: chave nova ou campo de versão) para descartá-lo uma vez, ou revalidar sob demanda.

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
