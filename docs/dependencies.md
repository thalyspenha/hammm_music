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
| `just_audio` | `^0.9.40` | Reprodução de áudio com suporte amplo de codecs (MP3, FLAC, OGG, AAC, M4A, WAV) |
| `audio_service` | `^0.18.15` | Handler de mídia em background/notificação (`services/audio_handler.dart`) |
| `on_audio_query` | `^2.9.0` | Consulta ao `MediaStore` do Android |
| `permission_handler` | `^11.3.1` | Gerenciamento de permissões (Android 13+ / legacy) |
| `provider` | `^6.1.2` | Gerenciamento de estado |
| `palette_generator` | `^0.3.3+3` | Cores dinâmicas a partir da arte do álbum |
| `shared_preferences` | `^2.3.0` | Persistência de favoritos, playlists e cache de URLs de capa |
| `http` | `^1.2.0` | Cliente HTTP para a iTunes Search API |

## Dependências de desenvolvimento

| Pacote | Versão declarada | Uso |
|---|---|---|
| `flutter_test` | SDK | Framework de testes (presente, mas sem testes escritos — ver [testing.md](./testing.md)) |
| `flutter_lints` | `^4.0.0` | Regras de lint padrão Flutter |
| `flutter_launcher_icons` | `^0.14.3` | Geração do ícone do app a partir de `assets/icon/` |

## Dependências transitivas notáveis

- `rxdart` aparece em `pubspec.lock` mas **não é declarado diretamente** em `pubspec.yaml` — é dependência transitiva (provavelmente de `audio_service` e/ou `just_audio`, que usam `Stream`/`BehaviorSubject` do RxDart internamente). Não deve ser importado diretamente pelo código da aplicação.

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
- Não foi executada auditoria de vulnerabilidades de dependências (`dart pub outdated`/`flutter pub deps` não executados como parte desta análise — apenas leitura estática dos manifestos).
