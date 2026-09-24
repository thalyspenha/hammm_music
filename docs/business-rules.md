# Regras de negócio

Todas as regras abaixo foram extraídas diretamente do código-fonte (principalmente `lib/providers/player_provider.dart`). Referências de arquivo:linha usam o estado do código no momento desta análise.

## Biblioteca de músicas

- **Filtro de duração mínima**: faixas com duração ≤ 30000 ms (30 segundos) são excluídas da biblioteca ao carregar, para remover toques/efeitos sonoros curtos do `MediaStore`. (`player_provider.dart:145-149`)
- **Ordenação padrão**: por título (`SortField.title`), case-insensitive, alfabética. (`_sortField` inicial = `SortField.title`)
- **Campos ordenáveis**: título, artista ou álbum — sempre case-insensitive (`toLowerCase()` antes de comparar).
- **Artista/álbum desconhecidos**: quando o `MediaStore` não retorna artista ou álbum, o app substitui por `'Artista Desconhecido'` / `'Álbum Desconhecido'` (`song.dart:25-26`).
- **Agrupamento alfabético na UI**: `HomeScreen` agrupa a lista por letra inicial do campo de ordenação ativo; caracteres não-A-Z (números, símbolos) caem no grupo `#`.

## Busca

- Busca é **case-insensitive** e por **substring** (não por prefixo), aplicada simultaneamente sobre título, artista e álbum.
- Query é `trim()`-ada antes de aplicar o filtro; string vazia após trim desativa a busca (volta a mostrar a lista completa ordenada).
- A lista de resultados de busca (`_displaySongs`) é recalculada a cada chamada de `search()` ou `sortBy()`.

## Reprodução

- Ao tocar uma música (`playSong`), a fila de reprodução é definida como a lista passada em `playlist` (ou a lista atualmente exibida, `songs`, se nenhuma for informada) — ou seja, tocar uma música da tela inicial cria uma fila com **todas** as músicas visíveis naquele momento, na ordem exibida.
- Se a música tocada não for encontrada na lista fornecida, a reprodução começa do índice 0.
- **Seek** é sempre relativo/proporcional: `seekTo(value)` recebe um `double` 0.0–1.0 e converte para posição absoluta multiplicando pela duração total.
- **Progresso** (`progress` getter) retorna `0` quando a duração é `0` (evita divisão por zero), e é sempre limitado (`clamp`) a `[0.0, 1.0]`.
- **Velocidade de reprodução**: valores predefinidos no ciclo da UI (`player_screen.dart`): `0.5, 0.75, 1.0, 1.25, 1.5, 2.0×`; o provider aceita qualquer `double`, mas a UI só oferece esse ciclo.
- **`onTaskRemoved`**: se a task do app for removida da lista de recentes do Android, a reprodução é parada automaticamente (`audio_handler.dart:122-124`) — evita playback "fantasma" sem o app visível.

## Repeat / Shuffle

- Modo de repetição cicla em ordem fixa: `none → one → all → none` (`cycleRepeatMode()`), delegando o loop real ao `just_audio` (`LoopMode.off/one/all`).
- Shuffle é um toggle booleano simples, delegado a `just_audio.setShuffleModeEnabled()`.

## Favoritos

- Favoritos são identificados apenas por `songId` (não pelo objeto `Song` inteiro). Se a música for removida do dispositivo, o ID é removido automaticamente na próxima `loadSongs()` bem-sucedida via `_pruneOrphans()`, que também persiste a remoção em `SharedPreferences`.
- Toggle é otimista: o estado em memória e a UI são atualizados via `notifyListeners()` **antes** da escrita assíncrona em `SharedPreferences` completar. Escritas em favoritos/playlists aguardam (`await`) o carregamento inicial do disco (`_favoritesLoaded`/`_playlistsLoaded`) antes de mutar o estado, evitando que uma ação do usuário logo após o boot sobrescreva dados ainda não lidos.

## Playlists

- **ID de playlist**: gerado como `DateTime.now().millisecondsSinceEpoch.toString()` — não há verificação de colisão (extremamente improvável, mas não é um UUID formal).
- **Nome de playlist**: sempre `trim()`-ado antes de salvar; criação/renomeação com nome vazio (após trim) é **bloqueada** silenciosamente (early return, sem feedback de erro ao usuário) — ver `_CreatePlaylistDialogState._create()` e `_RenamePlaylistDialogState._rename()` em `playlists_screen.dart`.
- **Adição de música**: idempotente — `addSongToPlaylist` verifica `!playlist.songIds.contains(songId)` antes de adicionar; tentar adicionar uma música já presente é uma operação sem efeito (não gera erro, mas o botão correspondente na UI já aparece desabilitado com indicação "já adicionada").
- **Exclusão de playlist**: requer confirmação explícita do usuário via `AlertDialog` ("Esta ação não pode ser desfeita").
- **Resolução de músicas da playlist**: `getPlaylistSongs()` mapeia `songIds` para objetos `Song` da biblioteca atual, descartando na exibição IDs que não existem mais (`whereType<Song>()`). Além disso, `_pruneOrphans()` remove esses IDs do `songIds` persistido de cada playlist na próxima `loadSongs()` bem-sucedida — a lista salva também é limpa, não só a exibição.
- **"Tocar tudo"**: se a playlist resolvida estiver vazia (todas as músicas foram removidas do dispositivo), a ação não faz nada (early return).

## Sleep Timer

- Apenas um sleep timer pode estar ativo por vez — iniciar um novo cancela o anterior (`_sleepTimer?.cancel()` antes de agendar).
- Ao expirar, chama `_handler.stop()` (para completamente a reprodução, não apenas pausa).
- Opções pré-definidas na UI: 15, 30, 45, 60 minutos (`player_screen.dart`); o método do provider aceita qualquer `Duration`.
- Um `Timer.periodic` de 1 segundo roda em paralelo apenas para atualizar a UI com a contagem regressiva (`notifyListeners()` a cada segundo enquanto o timer está ativo).

## Capa de álbum (artwork)

- **Ordem de prioridade de exibição**: (1) URL de capa em cache/rede (iTunes Search API) → (2) artwork embutida no arquivo local (via `on_audio_query`) → (3) gradiente placeholder determinístico gerado a partir do hash do título da música.
- **Cor de destaque (accent color) do player em tela cheia**: prioriza a cor dominante extraída via `palette_generator` da capa de rede; se indisponível, usa a cor artwork local; se nenhuma disponível, usa `songAccentColor(title)` (determinístico por hash).
- Busca de artwork externo tem **timeout de 8 segundos** por requisição HTTP; falhas são silenciosamente ignoradas (`catch (_) {}`), sem retry automático.
- Resultado da busca por artwork é **cacheado permanentemente** por `songId` em `SharedPreferences` — uma vez encontrada, a URL não é buscada novamente (nem revalidada).

## Permissões

- Fluxo de permissão: tenta `Permission.audio` primeiro (Android 13+); se negado, tenta `Permission.storage` (fallback para versões mais antigas do Android).
- Sem permissão concedida, a tela inicial exibe um estado de bloqueio pedindo acesso — a biblioteca não é carregada.
- Se a permissão for negada permanentemente (usuário marcou "não perguntar de novo", ou negou duas vezes — comportamento varia por versão do Android), o sistema para de exibir o diálogo nativo em chamadas futuras de `.request()`. Nesse caso, o botão de acesso na tela de bloqueio muda para "Abrir Configurações" (`PlayerProvider.isPermissionPermanentlyDenied` / `openPermissionSettings()`), redirecionando o usuário às configurações do app em vez de tentar `.request()` de novo (que não teria efeito).

## Não identificado

- Não há regras de negócio documentadas fora do código (não há wiki, ADRs formais ou especificação funcional em texto).
- Não há regras de limite de uso, quotas, ou validações de negócio server-side (não há servidor).
