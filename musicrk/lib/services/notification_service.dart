import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Inicializar el servicio de notificaciones
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(initSettings);
    _initialized = true;
  }

  /// Solicitar permiso de notificaciones (Android 13+)
  Future<bool> requestPermission() async {
    if (await Permission.notification.isGranted) {
      return true;
    }
    
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Mostrar notificación de descarga iniciada
  Future<void> showDownloadStarted(String songTitle, int notificationId) async {
    await initialize();
    
    const androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Descargas',
      channelDescription: 'Notificaciones de descarga de música',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: 0,
      ongoing: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      notificationId,
      'Descargando',
      songTitle,
      notificationDetails,
    );
  }

  /// Actualizar progreso de descarga
  Future<void> updateDownloadProgress(
    String songTitle,
    int notificationId,
    int progress,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Descargas',
      channelDescription: 'Notificaciones de descarga de música',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      notificationId,
      'Descargando ($progress%)',
      songTitle,
      notificationDetails,
    );
  }

  /// Mostrar notificación de descarga completada
  Future<void> showDownloadCompleted(String songTitle, int notificationId) async {
    const androidDetails = AndroidNotificationDetails(
      'download_complete_channel',
      'Descargas Completadas',
      channelDescription: 'Notificaciones de descargas completadas',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      notificationId,
      'Descarga completada',
      '$songTitle agregada correctamente',
      notificationDetails,
    );
  }

  /// Mostrar notificación de error en descarga
  Future<void> showDownloadError(String songTitle, int notificationId) async {
    const androidDetails = AndroidNotificationDetails(
      'download_error_channel',
      'Errores de Descarga',
      channelDescription: 'Notificaciones de errores en descargas',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      notificationId,
      'Error en descarga',
      'No se pudo descargar $songTitle',
      notificationDetails,
    );
  }

  /// Mostrar notificación de descarga de álbum iniciada
  Future<void> showAlbumDownloadStarted(String albumTitle, int notificationId) async {
    await initialize();
    
    const androidDetails = AndroidNotificationDetails(
      'album_download_channel',
      'Descargas de Álbumes',
      channelDescription: 'Notificaciones de descarga de álbumes completos',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      notificationId,
      'Descargando álbum',
      albumTitle,
      notificationDetails,
    );
  }

  /// Actualizar progreso de descarga de álbum
  Future<void> updateAlbumDownloadProgress(
    String albumTitle,
    int current,
    int total,
    int notificationId,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      'album_download_channel',
      'Descargas de Álbumes',
      channelDescription: 'Notificaciones de descarga de álbumes completos',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: total,
      progress: current,
      ongoing: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      notificationId,
      'Descargando álbum ($current/$total)',
      albumTitle,
      notificationDetails,
    );
  }

  /// Mostrar notificación de descarga de álbum completada
  Future<void> showAlbumDownloadCompleted(String albumTitle, int notificationId) async {
    const androidDetails = AndroidNotificationDetails(
      'album_complete_channel',
      'Álbumes Completados',
      channelDescription: 'Notificaciones de álbumes descargados',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      notificationId,
      '¡Álbum descargado!',
      '$albumTitle se descargó correctamente',
      notificationDetails,
    );
  }

  /// Cancelar notificación
  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(notificationId);
  }
}