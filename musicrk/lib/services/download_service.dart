import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'notification_service.dart';
import 'database_helper.dart';

class VideoResult {
  final String id;
  final String title;
  final String url;
  final String thumbnail;
  final double duration;
  final String author;

  VideoResult({
    required this.id,
    required this.title,
    required this.url,
    required this.thumbnail,
    required this.duration,
    required this.author,
  });

  factory VideoResult.fromJson(Map<String, dynamic> json) {
    return VideoResult(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      duration: (json['duration'] ?? 0).toDouble(),
      author: json['author'] ?? '',
    );
  }
}

class AlbumResult {
  final String id;
  final String title;
  final String thumbnail;
  final String author;
  final int trackCount;

  AlbumResult({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.author,
    required this.trackCount,
  });

  factory AlbumResult.fromJson(Map<String, dynamic> json) {
    return AlbumResult(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      author: json['author'] ?? '',
      trackCount: json['track_count'] ?? 0,
    );
  }
}

class DownloadService {
  final _notificationService = NotificationService();
  int _notificationId = 0;

  /// Busca videos en YouTube a través del backend
  Future<List<VideoResult>> searchVideos(String query) async {
    try {
      debugPrint('Buscando a través del backend: $query');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.searchEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = (data['results'] as List)
            .map((json) => VideoResult.fromJson(json))
            .toList();
        debugPrint('Se encontraron ${results.length} resultados');
        return results;
      } else {
        debugPrint('Error en la búsqueda: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error en la búsqueda: $e');
      return [];
    }
  }

  /// Busca álbumes oficiales en YouTube
  Future<List<AlbumResult>> searchAlbums(String query) async {
    try {
      debugPrint('Buscando álbumes: $query');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.searchAlbumsEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = (data['results'] as List)
            .map((json) => AlbumResult.fromJson(json))
            .toList();
        debugPrint('Se encontraron ${results.length} álbumes');
        return results;
      } else {
        debugPrint('Error en búsqueda de álbumes: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error en búsqueda de álbumes: $e');
      return [];
    }
  }

  /// Obtiene las canciones de un álbum
  Future<List<VideoResult>> getAlbumTracks(String playlistId) async {
    try {
      debugPrint('Obteniendo canciones del álbum: $playlistId');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.albumTracksEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'playlist_id': playlistId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = (data['tracks'] as List)
            .map((json) => VideoResult.fromJson(json))
            .toList();
        debugPrint('Se encontraron ${tracks.length} canciones en el álbum');
        return tracks;
      } else {
        debugPrint('Error obteniendo canciones: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error obteniendo canciones: $e');
      return [];
    }
  }

  /// Descarga audio y convierte a MP3 a través del backend
  void downloadAndConvertToMp3Async(VideoResult video) {
    _executeDownload(video);
  }

  /// Descarga álbum completo de forma asíncrona
  void downloadAlbumAsync(AlbumResult album) {
    _executeAlbumDownload(album);
  }

  Future<void> _executeDownload(VideoResult video) async {
    final notificationId = _notificationId++;
    debugPrint('Descargando: ${video.title}');
    
    try {
      await _notificationService.requestPermission();
      
      if (await Permission.storage.request().isDenied) {
        if (await Permission.manageExternalStorage.request().isDenied) {
          debugPrint('Permiso denegado');
          await _notificationService.showDownloadError(video.title, notificationId);
          return;
        }
      }
      
      await _notificationService.showDownloadStarted(video.title, notificationId);
      
      debugPrint('Solicitando descarga desde el backend...');
      
      // Solicitar descarga al backend
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.downloadEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'video_id': video.id,
          'title': video.title,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          debugPrint('Descarga en el backend exitosa');
          
          // Actualizar progreso al 50% (backend descargado)
          await _notificationService.updateDownloadProgress(video.title, notificationId, 50);
          
          // Descargar archivo desde el backend al dispositivo
          final filename = data['file_path'].split('/').last;
          final fileUrl = '${ApiConfig.baseUrl}/download_file/$filename';
          
          debugPrint('Descargando archivo desde el backend: $fileUrl');
          
          // Descargar archivo en fragmentos para evitar timeout
          final request = http.Request('GET', Uri.parse(fileUrl));
          final response = await request.send();
          
          if (response.statusCode == 200) {
            // Obtener ruta de descarga configurada
            final prefs = await SharedPreferences.getInstance();
            final downloadPath = prefs.getString('download_path') ?? '/storage/emulated/0/Music';
            
            final dir = Directory(downloadPath);
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
            
            final localPath = '${dir.path}/$filename';
            final file = File(localPath);
            final sink = file.openWrite();
            
            debugPrint('Guardando archivo en: $localPath');
            
            try {
              // Descargar en fragmentos
              await response.stream.pipe(sink);
              await sink.close();
              
              final fileSize = await file.length();
              debugPrint('Archivo guardado: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
              
              await _notificationService.showDownloadCompleted(video.title, notificationId);
              
              // Save notification to database
              await DatabaseHelper.instance.addNotification({
                'tipo': 'cancion',
                'titulo': 'Canción descargada',
                'descripcion': video.title,
                'cantidad': 1,
              });
            } catch (e) {
              debugPrint('Error guardando archivo: $e');
              await sink.close();
              if (await file.exists()) {
                await file.delete();
              }
              await _notificationService.showDownloadError(video.title, notificationId);
            }
          } else {
            debugPrint('Error en descarga de archivo: ${response.statusCode}');
            await _notificationService.showDownloadError(video.title, notificationId);
          }
        } else {
          debugPrint('Error en descarga del backend');
          await _notificationService.showDownloadError(video.title, notificationId);
        }
      } else {
        debugPrint('Error en solicitud al backend: ${response.statusCode}');
        await _notificationService.showDownloadError(video.title, notificationId);
      }
    } catch (e) {
      debugPrint('Error general en descarga: $e');
      await _notificationService.showDownloadError(video.title, notificationId);
    }
  }

  Future<void> _executeAlbumDownload(AlbumResult album) async {
    final notificationId = _notificationId++;
    debugPrint('Descargando álbum: ${album.title}');
    
    try {
      await _notificationService.requestPermission();
      
      if (await Permission.storage.request().isDenied) {
        if (await Permission.manageExternalStorage.request().isDenied) {
          debugPrint('Permiso denegado');
          await _notificationService.showDownloadError(album.title, notificationId);
          return;
        }
      }
      
      await _notificationService.showAlbumDownloadStarted(album.title, notificationId);
      
      debugPrint('Solicitando descarga del álbum desde el backend...');
      
      // Solicitar descarga del álbum al backend
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.downloadAlbumEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'playlist_id': album.id,
          'album_title': album.title,
        }),
      ).timeout(const Duration(minutes: 30)); // Timeout largo para álbumes

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final albumFolder = data['album_folder'];
          final downloadedFiles = data['downloaded_files'] as List;
          final totalTracks = data['total_tracks'];
          
          debugPrint('Álbum descargado en el backend: $albumFolder');
          debugPrint('Canciones descargadas: ${downloadedFiles.length}/$totalTracks');
          
          // Obtener ruta de descarga configurada
          final prefs = await SharedPreferences.getInstance();
          final downloadPath = prefs.getString('download_path') ?? '/storage/emulated/0/Music';
          
          // Crear carpeta del álbum en el dispositivo
          final albumDir = Directory('$downloadPath/$albumFolder');
          if (!await albumDir.exists()) {
            await albumDir.create(recursive: true);
          }
          
          // Descargar cada archivo del backend al dispositivo
          int downloaded = 0;
          for (var fileInfo in downloadedFiles) {
            final filename = fileInfo['file_path'];
            final fileUrl = '${ApiConfig.baseUrl}/download_file/$filename';
            
            try {
              final request = http.Request('GET', Uri.parse(fileUrl));
              final fileResponse = await request.send();
              
              if (fileResponse.statusCode == 200) {
                final localFilename = filename.split('/').last;
                final localPath = '${albumDir.path}/$localFilename';
                final file = File(localPath);
                final sink = file.openWrite();
                
                await fileResponse.stream.pipe(sink);
                await sink.close();
                
                downloaded++;
                await _notificationService.updateAlbumDownloadProgress(
                  album.title, 
                  downloaded, 
                  downloadedFiles.length, 
                  notificationId
                );
              }
            } catch (e) {
              debugPrint('Error descargando archivo: $e');
              continue;
            }
          }
          
          await _notificationService.showAlbumDownloadCompleted(album.title, notificationId);
        } else {
          debugPrint('Error en descarga del álbum');
          await _notificationService.showDownloadError(album.title, notificationId);
        }
      } else {
        debugPrint('Error en solicitud al backend: ${response.statusCode}');
        await _notificationService.showDownloadError(album.title, notificationId);
      }
    } catch (e) {
      debugPrint('Error general en descarga de álbum: $e');
      await _notificationService.showDownloadError(album.title, notificationId);
    }
  }

  Future<bool> checkBackendHealth() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.healthEndpoint}'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error de conexión con el backend: $e');
      return false;
    }
  }
  
  void dispose() {
    // No se necesita limpieza
  }
}