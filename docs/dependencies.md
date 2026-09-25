# Dependências

Fonte: `pubspec.yaml` (versões declaradas) e `pubspec.lock` (versões resolvidas, quando relevante).

## SDK

| Requisito | Valor |
|---|---|
| Dart SDK | `>=3.3.0 <4.0.0` |
| Flutter | não fixado por versão específica no `pubspec.yaml` (usa o SDK do Flutter instalado) |

## Dependências de produção

| Pacote | Versão declarada | Uso no projeto (comentário do `pubspec.yaml`) |
|---|---|---|
| `flutter` | SDK | Framework base |
| `just_audio` | `^0.10.6` | Reprodução de áudio com suporte amplo de codecs (MP3, FLAC, OGG, AAC, M4A, WAV) |
| `audio_service` | `^0.18.19` | Handler de mídia em background/notificação (`services/audio_handler.dart`) |
| `on_audio_query` | `^2.9.0` | Consulta ao `MediaStore` do Android |
| `permission_handler` | `^13.0.2` | Gerenciamento de permissões (Android 13+ / legacy) |
| `provider` | `^6.1.2` | Gerenciamento de estado |
| `material_color_utilities` | `any` (fixada pelo Flutter SDK; 0.13.0 hoje) | Cor de destaque a partir da capa: `QuantizerCelebi` + `Score` (`seedColorFromPixels()` em `app_theme.dart`). Substituiu o `palette_generator`, descontinuado, em 2026-09-25 |
| `shared_preferences` | `^2.3.0` | Persistência de favoritos, playlists e cache de URLs de capa |
| `http` | `^1.2.0` | Cliente HTTP para a iTunes Search API |

## Dependências de desenvolvimento

| Pacote | Versão declarada | Uso |
|---|---|---|
| `flutter_test` | SDK | Framework de testes (ver [testing.md](./testing.md)) |
| `flutter_lints` | `^6.0.0` | Regras de lint padrão Flutter |
| `flutter_launcher_icons` | `^0.14.3` | Geração do ícone do app a partir de `assets/icon/` |
| `flutter_native_splash` | `^2.4.8` | Splash nativa (fundo `#0A0A0F` + `icon_foreground.png`, inclusive Android 12+); regenerar com `dart run flutter_native_splash:create` |

## Dependências transitivas notáveis

- `rxdart` aparece em `pubspec.lock` mas **não é declarado diretamente** em `pubspec.yaml` — é dependência transitiva (provavelmente de `audio_service` e/ou `just_audio`, que usam `Stream`/`BehaviorSubject` do RxDart internamente). Não deve ser importado diretamente pelo código da aplicação.

- `audio_session` (via `just_audio`/`audio_service`, 0.1.x — o `audio_service` 0.18 ainda não aceita a 0.2): o `just_audio` ativa a sessão com `AudioSessionConfiguration.music()` como configuração padrão quando o app não configura nenhuma, então foco de áudio/ducking já seguem o comportamento de player de música sem código próprio.

## Situação das dependências (revisada em 2026-09-24)

- **`just_audio` 0.9 → 0.10**: migrado. Mudanças que afetaram o código: `ConcatenatingAudioSource` substituído por `AudioPlayer.setAudioSources`; erros de reprodução passaram do `playbackEventStream` para `errorStream`; `SequenceState`/`effectiveIndices` deixaram de ser anuláveis. Exige AGP ≥ 8.5.2 (o projeto usa 9.0.1).
- **`on_audio_query` 2.9.0** (maio/2023, sem releases desde então): mantido. Alternativas avaliadas no pub.dev — `on_audio_query_pluse` 3.0.7 (fork ativo, junho/2026, ~540 downloads/mês), `on_audio_query_forked`, `device_audio_query`, `media_manager` — são todas de baixa adoção e publicadas por contas pessoais sem publisher verificado, e substituiriam o código nativo Android que recebe a permissão de leitura de mídia. O original tem publisher verificado (`lucasjosino.com`). Decisão: não trocar por ora; reavaliar se o build quebrar em versão futura do AGP/Gradle. Os ajustes de build necessários estão em [infrastructure.md](./infrastructure.md).

## Configuração adicional relacionada a dependências (`pubspec.yaml`)

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/icon/

flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "#0A0A0F"
  adaptive_icon_foreground: "assets/icon/icon_foreground.png"
  min_sdk_android: 26
```

## Não identificado

- Não há lockfile de outra natureza (ex. `Podfile.lock` — não aplicável, sem alvo iOS).
- Não foi executada auditoria de vulnerabilidades de dependências (a revisão de 2026-09-24 usou `flutter pub outdated` e metadados do pub.dev, sem ferramenta de CVE).
