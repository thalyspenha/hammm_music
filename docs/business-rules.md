# Regras de negócio

Todas as regras abaixo foram extraídas diretamente do código-fonte (principalmente `lib/providers/player_provider.dart`). Referências de arquivo:linha usam o estado do código no momento desta análise.

## Biblioteca de músicas

- **Filtro de duração mínima**: faixas com duração ≤ 30000 ms (30 segundos) são excluídas da biblioteca ao carregar, para remover toques/efeitos sonoros curtos do `MediaStore`. (`PlayerProvider.loadSongs()`)
- **Ordenação padrão**: por título (`SortField.title`), case-insensitive, alfabética. (`_sortField` inicial = `SortField.title`)
- **Campos ordenáveis**: título, artista ou álbum — sempre case-insensitive (`toLowerCase()` antes de comparar).
- **Artista/álbum desconhecidos**: quando o `MediaStore` não retorna artista ou álbum, o app substitui por `'Artista Desconhecido'` / `'Álbum Desconhecido'` (`Song.fromSongModel()`). `Song.hasKnownArtist` trata esse placeholder, string vazia e o `<unknown>` do `MediaStore` como artista desconhecido.
- **Agrupamento alfabético na UI**: `HomeScreen` agrupa a lista por letra inicial do campo de ordenação ativo; caracteres não-A-Z (números, símbolos) caem no grupo `#`.

## Busca

- Busca é **case-insensitive** e por **substring** (não por prefixo), aplicada simultaneamente sobre título, artista e álbum.
- Query é `trim()`-ada antes de aplicar o filtro; string vazia após trim desativa a busca (volta a mostrar a lista completa ordenada).
- A lista de resultados de busca (`_displaySongs`) é recalculada a cada chamada de `search()` ou `sortBy()`.

## Reprodução

- Ao tocar uma música (`playSong`), a fila de reprodução é definida como a lista passada em `playlist` (ou a lista atualmente exibida, `songs`, se nenhuma for informada) — ou seja, tocar uma música da tela inicial cria uma fila com **todas** as músicas visíveis naquele momento, na ordem exibida.
- Se a música tocada não for encontrada na lista fornecida, a reprodução começa do índice 0.
- **Seek** é sempre relativo/proporcional: `seekTo(value)` recebe um `double` 0.0–1.0 e converte para posição absoluta multiplicando pela duração total.
- **Progresso** (`progress`/`progressAt(position)`) retorna `0` quando a duração é `0` (evita divisão por zero), e é sempre limitado (`clamp`) a `[0.0, 1.0]`.
- **Posição não dispara `notifyListeners()`**: a posição da faixa vive num `ValueNotifier` próprio (`positionListenable`), escutado só pelo seekbar e pelo mini player via `ValueListenableBuilder`. O `positionStream` emite várias vezes por segundo; notificar o provider reconstruiria a árvore inteira (e reconsultaria capas no `MediaStore`) a cada tick.
- **Fim da fila** (repeat desligado): o handler pausa e volta para o início da fila (`_rewindAfterCompletion()`); o próximo play recomeça do primeiro item. Sem isso o `just_audio` mantém `playing == true` em `completed`, deixando a UI em "tocando" e o play sem efeito.
- **Velocidade de reprodução**: valores predefinidos no ciclo da UI (`player_screen.dart`): `0.5, 0.75, 1.0, 1.25, 1.5, 2.0×`; o provider aceita qualquer `double`, mas a UI só oferece esse ciclo.
- **`onTaskRemoved`**: se a task do app for removida da lista de recentes do Android, a reprodução é parada automaticamente (`HammmAudioHandler.onTaskRemoved()`) — evita playback "fantasma" sem o app visível.

## Repeat / Shuffle

- Modo de repetição cicla em ordem fixa: `none → one → all → none` (`cycleRepeatMode()`), delegando o loop real ao `just_audio` (`LoopMode.off/one/all`).
- Shuffle, repeat e velocidade **persistem entre sessões** (`shuffle`, `repeat_mode`, `speed` em `SharedPreferences`) e são reaplicados ao handler na abertura do app (`_loadPlaybackPrefs()`).
- **"Anterior"**: se a faixa atual já passou de 3 s (ou não há faixa anterior), volta ao início dela; só perto do início vai para a faixa anterior (`HammmAudioHandler.skipToPrevious()`).
- Shuffle é um toggle delegado a `just_audio`. Ao ligar, a ordem é reembaralhada com a faixa atual na primeira posição (`_player.shuffle()` antes de `setShuffleModeEnabled(true)`), para nenhuma faixa ficar "antes" dela e ser pulada.
- **Índices da fila**: `queue` (e a `QueueScreen`) expõe a ordem **efetiva** (embaralhada quando o shuffle está ligado), enquanto `currentIndex`/`seek(index:)` do `just_audio` usam a ordem original. O handler converte entre as duas via `effectiveIndices` (`skipToQueueItem`, `queueIndex` do `PlaybackState`), e a faixa atual (`mediaItem`) vem de `sequenceState.currentSource.tag`, não de `queue[currentIndex]`.

## Favoritos

- Favoritos são identificados por `songId` (não pelo objeto `Song` inteiro), com o caminho do arquivo guardado à parte (`favorite_paths`).
- **Reconciliação por caminho**: se o `MediaStore` reindexar a biblioteca e os IDs mudarem, `_reconcileByPath()` troca cada ID antigo pelo ID atual do mesmo arquivo antes da poda de órfãos (vale para favoritos e playlists). Referências salvas antes de o caminho existir só ganham caminho quando o ID ainda é válido — IDs já órfãos sem caminho não são recuperáveis. Se a música for removida do dispositivo, o ID é removido automaticamente na próxima `loadSongs()` bem-sucedida via `_pruneOrphans()`, que também persiste a remoção em `SharedPreferences`.
- **Proteção contra poda em massa**: a poda é adiada quando a biblioteca vem vazia ou quando mais de 50% dos IDs referenciados (favoritos + playlists) sumiriam de uma vez (`orphanIdsToPrune()`, constante `_maxOrphanFraction`). Esse padrão indica `MediaStore` incompleto (cartão SD desmontado, indexação em andamento), não músicas apagadas. IDs órfãos que sobrevivem são inofensivos: a exibição já os descarta.
- Toggle é otimista: o estado em memória e a UI são atualizados via `notifyListeners()` **antes** da escrita assíncrona em `SharedPreferences` completar. Escritas em favoritos/playlists aguardam (`await`) o carregamento inicial do disco (`_favoritesLoaded`/`_playlistsLoaded`) antes de mutar o estado, evitando que uma ação do usuário logo após o boot sobrescreva dados ainda não lidos.

## Playlists

- **ID de playlist**: gerado como `DateTime.now().millisecondsSinceEpoch.toString()` — não há verificação de colisão (extremamente improvável, mas não é um UUID formal).
- **Nome de playlist**: sempre `trim()`-ado antes de salvar; criação/renomeação com nome vazio (após trim) é bloqueada e mostra `errorText` no campo ("Digite um nome para a playlist") — ver `_CreatePlaylistDialogState._create()` e `_RenamePlaylistDialogState._rename()` em `playlists_screen.dart`.
- **Adição de música**: idempotente — `addSongToPlaylist` verifica `!playlist.songIds.contains(songId)` antes de adicionar; tentar adicionar uma música já presente é uma operação sem efeito (não gera erro, mas o botão correspondente na UI já aparece desabilitado com indicação "já adicionada").
- **Exclusão de playlist**: requer confirmação explícita do usuário via `AlertDialog` ("Esta ação não pode ser desfeita").
- **Caminho das músicas**: `addSongToPlaylist` guarda o caminho do arquivo em `Playlist.songPaths`; `removeSongFromPlaylist` e a poda o removem.
- **Resolução de músicas da playlist**: `getPlaylistSongs()` mapeia `songIds` para objetos `Song` da biblioteca atual, descartando na exibição IDs que não existem mais (`whereType<Song>()`). Além disso, `_pruneOrphans()` remove esses IDs do `songIds` persistido de cada playlist na próxima `loadSongs()` bem-sucedida — a lista salva também é limpa, não só a exibição.
- **"Tocar tudo"**: se a playlist resolvida estiver vazia (todas as músicas foram removidas do dispositivo), a ação não faz nada (early return).

## Sleep Timer

- Apenas um sleep timer pode estar ativo por vez — iniciar um novo cancela o anterior (`_sleepTimer?.cancel()` antes de agendar).
- Ao expirar, chama `_handler.stop()` (para completamente a reprodução, não apenas pausa).
- Opções pré-definidas na UI: 15, 30, 45, 60 minutos (`player_screen.dart`); o método do provider aceita qualquer `Duration`.
- Um `Timer.periodic` de 1 segundo roda em paralelo apenas para atualizar a contagem regressiva no `ValueNotifier` `sleepTimerRemaining` (sem `notifyListeners()`).
- A limpeza do estado ao expirar roda em `finally`: mesmo que `_handler.stop()` falhe, a contagem é cancelada.
- `HammmAudioHandler.stop()` não chama `super.stop()`: o `BaseAudioHandler.stop()` faz `playbackState.add(...)`, que lança `StateError` porque `playbackState` já recebe o `pipe` do player.

## Erros de reprodução

- Falha ao carregar a fila (`setAudioSource` — ex.: arquivo apagado ou corrompido) é capturada em `playSong()` e emitida em `PlayerProvider.errors`; `HammmApp` exibe como SnackBar ("Não foi possível tocar ...") em qualquer tela via `scaffoldMessengerKey`.
- `PlayerInterruptedException` (um novo toque carregou outra fila antes da anterior terminar) é esperada e ignorada.
- O mesmo erro também é emitido no `errorStream` do `just_audio` (0.10+), que o handler apenas registra em log. (Na 0.9 ele chegava como evento de erro do `playbackEventStream` e gerava "Unhandled Exception" nos ouvintes de `playbackState`.)
- Com arquivo apagado, o ExoPlayer leva ~3 s para desistir; só então o SnackBar aparece. A faixa com falha continua como "atual" no mini player (em estado parado).

## Capa de álbum (artwork)

- **Ordem de prioridade de exibição**: (1) URL de capa em cache/rede (iTunes Search API) → (2) artwork embutida no arquivo local (via `on_audio_query`) → (3) gradiente placeholder determinístico gerado a partir do hash do título da música.
- **Cor de destaque (accent color) do player em tela cheia**: prioriza a cor dominante extraída via `palette_generator` da capa de rede; se indisponível, usa a cor artwork local; se nenhuma disponível, usa `songAccentColor(title)` (determinístico por hash).
- **Legibilidade da cor extraída** (`accentFromPalette()`, `app_theme.dart`): cores praticamente cinzas (saturação HSL < 0.15) são descartadas e caem para `songAccentColor(title)` — clareadas, ficariam iguais ao cinza dos ícones inativos. As demais são clareadas (mantendo matiz e saturação) até contraste WCAG ≥ 4.5 com `AppTheme.background` (`readableAccent()`), para que ícones ativos e textos de destaque não sumam com capas escuras.
- Busca de artwork externo tem **timeout de 8 segundos** por requisição HTTP; falhas são silenciosamente ignoradas, sem retry automático.
- Faixas sem artista conhecido **não** são buscadas no iTunes; resultados só são aceitos se artista e título baterem com a faixa (`pickArtworkUrl()`). Ver [integrations.md](./integrations.md).
- Resultado da busca por artwork é **cacheado permanentemente** por `songId` em `SharedPreferences` — uma vez encontrada, a URL não é buscada novamente (nem revalidada). Busca sem resultado compatível fica em cache negativo por 7 dias.
- **Troca rápida de faixa**: a cor de destaque só é aplicada se a faixa que a originou ainda for a atual (`_currentSong?.id == song.id` após cada `await`) — respostas atrasadas de faixas anteriores são descartadas.

## Permissões

- Pedidos concorrentes de permissão (ex.: botão "Permitir Acesso" com o diálogo inicial aberto) reaproveitam o pedido em andamento (`_permissionRequest`) — o `permission_handler` lança `PlatformException` quando dois se sobrepõem.

- Fluxo de permissão: pede **uma única** permissão, escolhida pela versão do Android (lida via `MethodChannel` `com.hammm.music/platform`): `Permission.audio` (`READ_MEDIA_AUDIO`) no Android 13+ (API 33+), `Permission.storage` (`READ_EXTERNAL_STORAGE`) abaixo. Pedir a outra como fallback fazia o `permission_handler` reportar "negada permanentemente" (ela não está no manifest daquela versão). Se o canal falhar, assume API 33+.
- Sem permissão concedida, a tela inicial exibe um estado de bloqueio pedindo acesso — a biblioteca não é carregada.
- Se a permissão for negada permanentemente (usuário marcou "não perguntar de novo", ou negou duas vezes — comportamento varia por versão do Android), o sistema para de exibir o diálogo nativo em chamadas futuras de `.request()`. Nesse caso, o botão de acesso na tela de bloqueio muda para "Abrir Configurações" (`PlayerProvider.isPermissionPermanentlyDenied` / `openPermissionSettings()`), redirecionando o usuário às configurações do app em vez de tentar `.request()` de novo (que não teria efeito).
- Ao voltar para o primeiro plano (`AppLifecycleState.resumed`, observado em `HammmApp`), `refreshPermission()` checa o status atual sem abrir diálogo e, se a permissão foi concedida nas Configurações, carrega a biblioteca. `loadSongs()` ignora chamadas enquanto outra carga está em andamento.

## Não identificado

- Não há regras de negócio documentadas fora do código (não há wiki, ADRs formais ou especificação funcional em texto).
- Não há regras de limite de uso, quotas, ou validações de negócio server-side (não há servidor).
