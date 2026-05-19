import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Solicitar permisos iniciales de forma ordenada
  Future<void> requestInitialPermissions() async {
    if (!Platform.isAndroid) return;

    try {
      // 1. Notificaciones
      await Permission.notification.request();

      // 2. Almacenamiento / Audio
      // En Android 13+ (API 33), se usa READ_MEDIA_AUDIO
      // En versiones anteriores, READ_EXTERNAL_STORAGE
      // Intentamos ambos de forma secuencial para máxima compatibilidad
      
      await Permission.audio.request();
      await Permission.storage.request();
      
      // Opcional: MANAGE_EXTERNAL_STORAGE para renombrar/eliminar en Android 11+
      // Solo si el usuario realmente lo necesita, pero por ahora lo pedimos 
      // si ya denegaron los básicos para intentar una vía más amplia.
    } catch (e) {
      debugPrint('Error en requestInitialPermissions: $e');
    }
  }

  /// Verifica si tenemos los permisos críticos para funcionar
  Future<bool> hasCriticalPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      final audioStatus = await Permission.audio.status;
      final storageStatus = await Permission.storage.status;
      
      return audioStatus.isGranted || storageStatus.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Request storage permissions for audio files (específico)
  Future<bool> requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.audio.request();
        if (status.isGranted) return true;
        
        var storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if storage permission is granted
  Future<bool> hasStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final audioGranted = await Permission.audio.isGranted;
        final storageGranted = await Permission.storage.isGranted;
        return audioGranted || storageGranted;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> requestNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.notification.request();
        return status.isGranted;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Open app settings if permission is permanently denied
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Manejo profesional de estados de permiso
  Future<String?> getPermissionErrorMessage() async {
    if (!Platform.isAndroid) return null;

    final audio = await Permission.audio.status;
    final storage = await Permission.storage.status;

    if (audio.isPermanentlyDenied || storage.isPermanentlyDenied) {
      return "El permiso ha sido denegado permanentemente. Por favor, actívalo en los ajustes del sistema.";
    }
    
    if (audio.isDenied && storage.isDenied) {
      return "Se requiere acceso a tus archivos de audio para mostrar y reproducir tu música.";
    }

    return null;
  }
}
