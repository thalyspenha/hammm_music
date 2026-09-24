import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'screens/home_screen.dart';
import 'services/audio_handler.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Barra de status transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Força orientação portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final audioHandler = await initAudioService();

  runApp(
    ChangeNotifierProvider(
      create: (_) => PlayerProvider(audioHandler),
      child: const HammmApp(),
    ),
  );
}

class HammmApp extends StatefulWidget {
  const HammmApp({super.key});

  @override
  State<HammmApp> createState() => _HammmAppState();
}

class _HammmAppState extends State<HammmApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Inicia escaneamento logo após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PlayerProvider>();
      final granted = await provider.requestPermission();
      if (granted) await provider.loadSongs();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Usuário pode conceder a permissão nas Configurações do sistema (após
  // negar permanentemente) — rechecar ao voltar para o app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PlayerProvider>().refreshPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hammm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
