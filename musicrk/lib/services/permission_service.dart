import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request storage permissions for audio files
  Future<bool> requestStoragePermission() async {
    try {
      // For Android 13+ (API 33+), use READ_MEDIA_AUDIO
      // For older versions, use READ_EXTERNAL_STORAGE
      if (Platform.isAndroid) {
        // Try audio permission first (Android 13+)
        var status = await Permission.audio.status;
        
        if (status.isGranted) {
          return true;
        }
        
        if (status.isDenied) {
          status = await Permission.audio.request();
          if (status.isGranted) {
            return true;
          }
        }
        
        // Fallback to storage permission for older Android versions
        var storageStatus = await Permission.storage.status;
        
        if (storageStatus.isGranted) {
          return true;
        }
        
        if (storageStatus.isDenied) {
          storageStatus = await Permission.storage.request();
          return storageStatus.isGranted;
        }
        
        // If permanently denied, return false
        return false;
      }
      
      // For iOS or other platforms
      return true;
    } catch (e) {
      // If permission check fails, try to continue anyway
      // This handles cases where Permission.audio might not be available
      try {
        var storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      } catch (e2) {
        // Last resort - return true and let the app try to work
        return true;
      }
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
      return true; // Assume granted if check fails
    }
  }

  /// Request notification permissions
  Future<bool> requestNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.notification.status;
        
        if (status.isGranted) {
          return true;
        }
        
        if (status.isDenied) {
          status = await Permission.notification.request();
          return status.isGranted;
        }
        
        return false;
      }
      
      // For iOS or other platforms
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Check if notification permission is granted
  Future<bool> hasNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        return await Permission.notification.isGranted;
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
}
