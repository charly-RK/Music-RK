import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_service.dart';

/// Servicio para mostrar notificación de reproductor de música
class MediaNotificationService {
  static final MediaNotificationService _instance = MediaNotificationService._internal();
  factory MediaNotificationService() => _instance;
  MediaNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final AudioService _audioService = AudioService();
  bool _initialized = false;
  static const int _notificationId = 999;
  Timer? _progressTimer;

  /// Solicitar permiso de notificaciones
  Future<bool> requestPermission() async {
    if (await Permission.notification.isGranted) {
      return true;
    }
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Inicializar el servicio de notificaciones
  Future<void> initialize() async {
    if (_initialized) return;

    // Solicitar permiso primero
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      print('⚠️ Permiso de notificaciones denegado');
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;

    // Escuchar cambios en la canción actual
    _audioService.currentSongStream.listen((song) {
      if (song != null) {
        showMediaNotification(song);
        _startProgressUpdates();
      }
    });

    // Escuchar cambios en el estado de reproducción
    _audioService.playingStream.listen((isPlaying) {
      if (_audioService.currentSong != null) {
        showMediaNotification(_audioService.currentSong!);
        if (isPlaying) {
          _startProgressUpdates();
        } else {
          _stopProgressUpdates();
        }
      }
    });
  }

  /// Iniciar actualizaciones de progreso
  void _startProgressUpdates() {
    _stopProgressUpdates();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_audioService.currentSong != null && _audioService.player.playing) {
        showMediaNotification(_audioService.currentSong!);
      }
    });
  }

  /// Detener actualizaciones de progreso
  void _stopProgressUpdates() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// Mostrar notificación de reproductor
  Future<void> showMediaNotification(SongModel song) async {
    if (!_initialized) return;

    final isPlaying = _audioService.player.playing;
    final position = _audioService.player.position;
    final duration = _audioService.player.duration ?? Duration.zero;
    
    // Obtener artwork
    final artworkBytes = await _audioService.getAlbumArt(song.id, size: 300);
    
    // Crear bitmap para el artwork
    final BigPictureStyleInformation? bigPictureStyle = artworkBytes != null
        ? BigPictureStyleInformation(
            ByteArrayAndroidBitmap.fromBase64String(
              Uri.dataFromBytes(artworkBytes).toString().split(',')[1]
            ),
            largeIcon: ByteArrayAndroidBitmap.fromBase64String(
              Uri.dataFromBytes(artworkBytes).toString().split(',')[1]
            ),
            contentTitle: song.title,
            htmlFormatContentTitle: true,
            summaryText: '${song.artist ?? 'Desconocido'} • ${song.album ?? 'Desconocido'}',
            htmlFormatSummaryText: true,
          )
        : null;
    
    final androidDetails = AndroidNotificationDetails(
      'media_playback',
      'Reproductor de Música',
      channelDescription: 'Controles de reproducción de música',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      usesChronometer: false,
      showProgress: duration.inSeconds > 0,
      maxProgress: duration.inSeconds,
      progress: position.inSeconds,
      largeIcon: artworkBytes != null 
          ? ByteArrayAndroidBitmap.fromBase64String(
              Uri.dataFromBytes(artworkBytes).toString().split(',')[1])
          : null,
      styleInformation: bigPictureStyle,
      actions: [
        const AndroidNotificationAction(
          'previous',
          'Anterior',
          icon: DrawableResourceAndroidBitmap('ic_previous'),
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          isPlaying ? 'pause' : 'play',
          isPlaying ? 'Pausar' : 'Reproducir',
          icon: DrawableResourceAndroidBitmap(isPlaying ? 'ic_pause' : 'ic_play'),
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          'next',
          'Siguiente',
          icon: DrawableResourceAndroidBitmap('ic_next'),
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          'close',
          'Cerrar',
          icon: DrawableResourceAndroidBitmap('ic_close'),
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    await _notifications.show(
      _notificationId,
      song.title,
      '${song.artist ?? 'Desconocido'} • ${song.album ?? 'Desconocido'}',
      NotificationDetails(android: androidDetails),
    );
  }

  /// Manejar taps en la notificación
  void _onNotificationTap(NotificationResponse response) {
    print('🔔 Notificación tap: ${response.actionId}');
    
    final action = response.actionId;
    
    if (action == null) return;
    
    switch (action) {
      case 'previous':
        print('⏮️ Anterior');
        _audioService.playPrevious();
        break;
      case 'play':
        print('▶️ Play');
        _audioService.play();
        break;
      case 'pause':
        print('⏸️ Pause');
        _audioService.pause();
        break;
      case 'next':
        print('⏭️ Siguiente');
        _audioService.playNext();
        break;
      case 'close':
        print('❌ Cerrar');
        _stopProgressUpdates();
        cancelNotification();
        _audioService.pause();
        break;
    }
  }

  /// Cancelar notificación
  Future<void> cancelNotification() async {
    _stopProgressUpdates();
    await _notifications.cancel(_notificationId);
  }

  /// Limpiar recursos
  void dispose() {
    _stopProgressUpdates();
    cancelNotification();
  }
}
