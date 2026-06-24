package com.hammm.music

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service exige que a Activity estenda AudioServiceActivity (não
// FlutterActivity puro), senão o plugin não consegue acessar a FlutterEngine
// e o configure() falha com "wrong AndroidManifest" no boot do app.
class MainActivity : AudioServiceActivity()
