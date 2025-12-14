import 'package:flutter/material.dart';
import 'package:musicrk/pag/main_screen.dart';
import 'package:audio_service/audio_service.dart';
import 'package:musicrk/services/audio_player_handler.dart';
import 'package:musicrk/services/audio_service.dart' as app_audio;
import 'package:musicrk/services/permission_service.dart';

// Referencia global al handler de audio
AudioPlayerHandler? _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Solicitar permisos de notificación al iniciar
  final permissionService = PermissionService();
  await permissionService.requestNotificationPermission();
  
  // Inicializar el servicio de audio en segundo plano
  try {
    final audioService = app_audio.AudioService();
    
    _audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(audioService.player),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.musicrk.audio',
        androidNotificationChannelName: 'Reproductor de Música',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
    
    // Conectar el handler con el servicio de audio
    audioService.setAudioHandler(_audioHandler);
  } catch (e) {
    debugPrint('Error inicializando audio service: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Music RK',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MainScreen(), 
    );
  }
}
