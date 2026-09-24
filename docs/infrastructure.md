# Infraestrutura

## Resumo

O projeto **não possui infraestrutura de backend, deploy em nuvem, containers ou CI/CD configurados no repositório**. É um app móvel distribuído via build local/manual (APK/AAB), sem qualquer arquivo de orquestração, Dockerfile ou pipeline encontrado.

Busca explícita realizada e sem resultado:
- `Dockerfile` / `docker-compose*`: não encontrado.
- `.github/workflows/*` (GitHub Actions): não encontrado.
- Qualquer outro diretório de CI (`.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/`, `bitrise.yml`, `codemagic.yaml`): não encontrado.

## Plataforma alvo

- **Somente Android** (`flutter_launcher_icons: android: true, ios: false` em `pubspec.yaml`). Não há diretório `ios/`, `web/`, `macos/`, `windows/` ou `linux/` no repositório — apenas `android/`.
- **Application ID**: `com.hammm.music` (`android/app/build.gradle`).
- **Nome do app**: "Hammm" (`AndroidManifest.xml`, `android:label`).

## Build (`android/app/build.gradle`)

| Configuração | Valor | Observação |
|---|---|---|
| `compileSdk` | 36 | Comentário no código: exigido por plugins como `audio_service`/`sqflite_android` |
| `minSdk` | 26 (Android 8.0) | Comentário no código: garante suporte nativo a FLAC e compatibilidade com `audio_service` |
| `targetSdk` | 34 | — |
| `ndkVersion` | `flutter.ndkVersion` (herdado do Flutter SDK) | — |
| Java/Kotlin target | 17 | `sourceCompatibility`/`targetCompatibility`/`jvmTarget` |
| `versionCode`/`versionName` | herdados do Flutter (`pubspec.yaml: version: 1.0.0+1`) | — |

### Build de release
- `signingConfig signingConfigs.debug` — o build de release usa a chave de debug, não uma keystore de produção própria. Não identificado nenhum arquivo `key.properties` ou keystore customizada no repositório. **Contexto do projeto: uso pessoal/hobby, sem publicação na Google Play — não é um problema a resolver, apenas documentado para o caso de o escopo mudar no futuro.**
- `minifyEnabled true` com ProGuard (`proguard-android-optimize.txt` + `proguard-rules.pro` customizado, que preserva classes de `com.ryanheise.*` — pacotes `audio_service`/`just_audio` — e do ExoPlayer, evitando quebra por ofuscação).

### Workaround de build (`android/build.gradle`)
Bloco `afterEvaluate` customizado que corrige `namespace` ausente e alinha `compileSdk`/Java target para subprojetos (plugins) que ainda não declaram `namespace` — comentário no código explica que isso é necessário para compatibilidade entre plugins antigos (ex.: `on_audio_query_android`) e AGP9/JDK17.

O mesmo bloco também alinha, para **todo** plugin Android, o `jvmTarget` do Kotlin ao `targetCompatibility` Java do próprio plugin (lido dentro do `configureEach`, pois o valor só é finalizado após a avaliação). Sem isso, com o JDK 21 embutido no Android Studio, o build falhava em `:on_audio_query_android:compileDebugKotlin` com "Inconsistent JVM-target compatibility detected for tasks 'compileDebugJavaWithJavac' (17) and 'compileDebugKotlin' (21)". O caso aparece mesmo quando o plugin já declara `namespace` e, por isso, não entra no primeiro `if`: o `build.gradle` do `on_audio_query_android` no pub-cache local foi editado à mão, ganhando `namespace` e Java 17. Um `flutter pub cache repair` desfaz essa edição e o plugin volta a cair no primeiro `if`.

## Permissões e serviços Android declarados

Ver `AndroidManifest.xml` (detalhado em [architecture.md](./architecture.md)):
- `READ_MEDIA_AUDIO` (Android 13+), `READ_EXTERNAL_STORAGE` (≤ Android 12, `maxSdkVersion=32`)
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK` (`RECEIVE_BOOT_COMPLETED` removida em 2026-09-24 — não havia receiver que a usasse)
- Serviço `com.ryanheise.audioservice.AudioService` (foreground, tipo `mediaPlayback`)
- Receiver `com.ryanheise.audioservice.MediaButtonReceiver`
- `android:allowBackup="false"` — dados do app (favoritos/playlists em `SharedPreferences`) **não são incluídos em backups automáticos do Android**.

## Configuração de Gradle (`android/gradle.properties`)

```
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=true
android.builtInKotlin=false
android.newDsl=false
```

## Ambientes / variáveis de ambiente

- Não identificado nenhum arquivo `.env`, `--dart-define`, `flutter_flavors` ou configuração de múltiplos ambientes (dev/staging/prod) no projeto. Existe apenas um `AndroidManifest.xml` principal e variantes padrão do Flutter (`debug`/`profile`) sem diferenças de conteúdo relevantes.

## Ícone do app

- Gerado via `flutter_launcher_icons` a partir de `assets/icon/icon.png` / `icon_foreground.png`, com fundo adaptativo `#0A0A0F` (mesma cor de fundo do tema do app), `min_sdk_android: 26`.

## Não identificado

- Não há pipeline de CI/CD, deploy automatizado ou publicação em loja de aplicativos configurados no repositório.
- Não há infraestrutura de nuvem (servidores, banco de dados gerenciado, CDN) — não aplicável, o app não depende de backend próprio.
- Não há processo documentado de release/versionamento além do `versionCode`/`versionName` padrão do Flutter — não aplicável, projeto é para uso pessoal (não distribuído via loja).
