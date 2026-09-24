package com.hammm.music

import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service exige que a Activity estenda AudioServiceActivity (não
// FlutterActivity puro), senão o plugin não consegue acessar a FlutterEngine
// e o configure() falha com "wrong AndroidManifest" no boot do app.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Expõe a versão da API do Android para o Dart escolher a permissão
        // de mídia correta (READ_MEDIA_AUDIO no 13+, READ_EXTERNAL_STORAGE abaixo).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hammm.music/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            }
    }
}
