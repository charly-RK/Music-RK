import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as youtube_explode;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import 'notification_service.dart';
import 'permission_service.dart';
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

  /// Busca videos en YouTube a través del backend (ahora local usando youtube_explode_dart con fallback)
  Future<List<VideoResult>> searchVideos(String query) async {
    try {
      final cleanQuery = query.trim();
      // Si la consulta es una URL de Spotify, devolvemos un único resultado placeholder
      // que permita gatillar la descarga de Spotify
      if (cleanQuery.contains('spotify.com') || cleanQuery.startsWith('spotify:')) {
        debugPrint('Consulta de Spotify detectada, retornando placeholder');
        return [
          VideoResult(
            id: 'spotify_${cleanQuery.hashCode}',
            title: 'Descargar Pista de Spotify',
            url: cleanQuery,
            thumbnail: 'https://img.icons8.com/color/96/spotify--v1.png',
            duration: 0.0,
            author: 'Spotify Link',
          )
        ];
      }

      debugPrint('Buscando directamente en YouTube con youtube_explode_dart: $query');
      final yt = youtube_explode.YoutubeExplode();
      final searchList = await yt.search.search(query);
      final List<VideoResult> results = [];
      for (final video in searchList) {
        results.add(VideoResult(
          id: video.id.value,
          title: video.title,
          url: video.url,
          thumbnail: video.thumbnails.mediumResUrl,
          duration: video.duration?.inSeconds.toDouble() ?? 0.0,
          author: video.author,
        ));
      }
      yt.close();
      debugPrint('Se encontraron ${results.length} resultados desde el cliente');
      return results;
    } catch (e) {
      debugPrint('Error en la búsqueda local, usando fallback de backend: $e');
      return _searchVideosFallback(query);
    }
  }

  Future<List<VideoResult>> _searchVideosFallback(String query) async {
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
        debugPrint('Se encontraron ${results.length} resultados desde el backend');
        return results;
      } else {
        debugPrint('Error en la búsqueda de fallback: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error en la búsqueda de fallback: $e');
      return [];
    }
  }

  /// Busca álbumes oficiales en YouTube
  Future<List<AlbumResult>> searchAlbums(String query) async {
    try {
      debugPrint('Buscando álbumes directamente con youtube_explode_dart: $query');
      final yt = youtube_explode.YoutubeExplode();
      // Usamos el filtro de playlist y el sufijo OLAK5uy para álbumes oficiales
      final searchResults = await yt.search.searchContent(
        query,
        filter: youtube_explode.TypeFilters.playlist,
      );
      final List<AlbumResult> results = [];
      for (final item in searchResults) {
        if (item is youtube_explode.SearchPlaylist) {
          final thumbnail = item.thumbnails.isNotEmpty ? item.thumbnails.first.url.toString() : '';
          results.add(AlbumResult(
            id: item.id.value,
            title: item.title,
            thumbnail: thumbnail,
            author: 'YouTube',
            trackCount: item.videoCount,
          ));
        }
      }
      yt.close();
      debugPrint('Se encontraron ${results.length} álbumes desde el cliente');
      return results;
    } catch (e) {
      debugPrint('Error en la búsqueda de álbumes local, usando fallback: $e');
      return _searchAlbumsFallback(query);
    }
  }

  Future<List<AlbumResult>> _searchAlbumsFallback(String query) async {
    try {
      debugPrint('Buscando álbumes vía backend: $query');
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
        debugPrint('Se encontraron ${results.length} álbumes desde el backend');
        return results;
      } else {
        debugPrint('Error en búsqueda de álbumes de fallback: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error en búsqueda de álbumes de fallback: $e');
      return [];
    }
  }

  /// Obtiene las canciones de un álbum
  Future<List<VideoResult>> getAlbumTracks(String playlistId) async {
    try {
      debugPrint('Obteniendo canciones del álbum localmente: $playlistId');
      final yt = youtube_explode.YoutubeExplode();
      final videos = await yt.playlists.getVideos(playlistId).toList();
      final List<VideoResult> tracks = [];
      for (final video in videos) {
        tracks.add(VideoResult(
          id: video.id.value,
          title: video.title,
          url: video.url,
          thumbnail: video.thumbnails.mediumResUrl,
          duration: video.duration?.inSeconds.toDouble() ?? 0.0,
          author: video.author,
        ));
      }
      yt.close();
      debugPrint('Se encontraron ${tracks.length} canciones en el álbum localmente');
      return tracks;
    } catch (e) {
      debugPrint('Error obteniendo canciones localmente, usando fallback: $e');
      return _getAlbumTracksFallback(playlistId);
    }
  }

  Future<List<VideoResult>> _getAlbumTracksFallback(String playlistId) async {
    try {
      debugPrint('Obteniendo canciones del álbum vía backend: $playlistId');
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
        debugPrint('Se encontraron ${tracks.length} canciones desde el backend');
        return tracks;
      } else {
        debugPrint('Error obteniendo canciones de fallback: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error obteniendo canciones de fallback: $e');
      return [];
    }
  }

  /// Descarga audio y convierte a MP3 a través del backend o directamente
  void downloadAndConvertToMp3Async(VideoResult video) {
    _executeDownload(video);
  }

  /// Descarga álbum completo de forma asíncrona
  void downloadAlbumAsync(AlbumResult album) {
    _executeAlbumDownload(album);
  }

  Future<void> _executeDownload(VideoResult video) async {
    final notificationId = _notificationId++;
    debugPrint('Iniciando proceso de descarga para: ${video.title}');
    
    // Detectar si es un enlace de Spotify
    final isSpotify = video.url.contains('spotify.com') || video.id.startsWith('spotify:');
    
    if (isSpotify) {
      await _executeSpotifyDownload(video, notificationId);
      return;
    }

    // Descarga directa de YouTube usando youtube_explode_dart
    File? tempAudioFile;
    File? tempArtFile;
    
    try {
      // 1. Validar permisos usando PermissionService
      final hasPermission = await PermissionService().requestStoragePermission();
      if (!hasPermission) {
        debugPrint('Permiso de almacenamiento denegado');
        await _notificationService.showDownloadError(video.title, notificationId);
        return;
      }
      
      // 2. Obtener ruta de descarga y verificar duplicados
      final prefs = await SharedPreferences.getInstance();
      final downloadPath = prefs.getString('download_path') ?? '/storage/emulated/0/Music';
      final dir = Directory(downloadPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      
      // Limpiar el título para el nombre del archivo
      final safeTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final localPath = '${dir.path}/$safeTitle.mp3';
      final file = File(localPath);
      
      if (await file.exists()) {
        debugPrint('El archivo ya existe en: $localPath');
        await _notificationService.showDownloadCompleted('${video.title} (Ya existe)', notificationId);
        return;
      }
      
      await _notificationService.showDownloadStarted(video.title, notificationId);
      
      // 3. Obtener el stream de audio con mayor tasa de bits desde YouTube
      debugPrint('Obteniendo stream para video ID: ${video.id}');
      final yt = youtube_explode.YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(video.id).timeout(const Duration(seconds: 15));
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      final stream = yt.videos.streamsClient.get(streamInfo);
      
      final containerExt = streamInfo.container.name;
      final tempDir = await getTemporaryDirectory();
      tempAudioFile = File('${tempDir.path}/temp_${video.id}.$containerExt');
      final fileStream = tempAudioFile.openWrite();
      
      int downloadedBytes = 0;
      final totalBytes = streamInfo.size.totalBytes;
      
      await for (final data in stream.timeout(const Duration(seconds: 15))) {
        fileStream.add(data);
        downloadedBytes += data.length;
        final progress = totalBytes > 0 ? ((downloadedBytes / totalBytes) * 100).toInt() : 0;
        // El progreso de descarga representa el 0-80% de la barra
        final mappedProgress = (progress * 0.8).toInt();
        await _notificationService.updateDownloadProgress(video.title, notificationId, mappedProgress);
      }
      await fileStream.flush();
      await fileStream.close();
      yt.close();
      
      await _notificationService.updateDownloadProgress(video.title, notificationId, 80);
      
      // 4. Descargar carátula
      tempArtFile = File('${tempDir.path}/temp_art_${video.id}.jpg');
      if (video.thumbnail.isNotEmpty) {
        try {
          final imgResponse = await http.get(Uri.parse(video.thumbnail)).timeout(const Duration(seconds: 15));
          if (imgResponse.statusCode == 200) {
            await tempArtFile.writeAsBytes(imgResponse.bodyBytes);
          }
        } catch (e) {
          debugPrint('No se pudo descargar la portada: $e');
        }
      }
      
      await _notificationService.updateDownloadProgress(video.title, notificationId, 85);
      
      // 5. Convertir a MP3 y añadir etiquetas de metadatos con FFmpeg
      debugPrint('Ejecutando conversión FFmpeg local...');
      String escapeMetadata(String text) {
        return text.replaceAll('"', '\\"').replaceAll("'", "\\'");
      }
      final escapedTitle = escapeMetadata(video.title);
      final escapedArtist = escapeMetadata(video.author);
      
      String ffmpegCommand;
      final hasArt = await tempArtFile.exists() && (await tempArtFile.length() > 0);
      
      if (hasArt) {
        ffmpegCommand = '-y -i "${tempAudioFile.path}" -i "${tempArtFile.path}" -map 0:a -map 1:0 -c:a libmp3lame -b:a 320k -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -metadata title="$escapedTitle" -metadata artist="$escapedArtist" "$localPath"';
      } else {
        ffmpegCommand = '-y -i "${tempAudioFile.path}" -c:a libmp3lame -b:a 320k -id3v2_version 3 -metadata title="$escapedTitle" -metadata artist="$escapedArtist" "$localPath"';
      }
      
      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        await _notificationService.showDownloadCompleted(video.title, notificationId);
        
        await DatabaseHelper.instance.addNotification({
          'tipo': 'cancion',
          'titulo': 'Descarga Completada',
          'descripcion': video.title,
          'cantidad': 1,
        });
      } else {
        final logs = await session.getLogs();
        final failLogs = logs.map((l) => l.getMessage()).join('\n');
        debugPrint('Error de conversión FFmpeg:\n$failLogs');
        throw Exception('Fallo en la conversión de audio');
      }
    } catch (e) {
      debugPrint('Error crítico en descarga youtube_explode, usando fallback de backend: $e');
      await _executeDownloadFallback(video, notificationId);
    } finally {
      // Limpieza de temporales
      try {
        if (tempAudioFile != null && await tempAudioFile.exists()) {
          await tempAudioFile.delete();
        }
        if (tempArtFile != null && await tempArtFile.exists()) {
          await tempArtFile.delete();
        }
      } catch (e) {
        debugPrint('Error limpiando archivos temporales: $e');
      }
    }
  }

  Future<void> _executeSpotifyDownload(VideoResult video, int notificationId) async {
    try {
      await _notificationService.showDownloadStarted('${video.title} (Spotify)', notificationId);
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/download_spotify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'spotify_url': video.url}),
      ).timeout(const Duration(minutes: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await _notificationService.updateDownloadProgress(video.title, notificationId, 50);
          
          final filename = data['file_path'];
          final fileUrl = '${ApiConfig.baseUrl}/download_file/$filename';
          
          // Obtener ruta de descarga local
          final prefs = await SharedPreferences.getInstance();
          final downloadPath = prefs.getString('download_path') ?? '/storage/emulated/0/Music';
          final dir = Directory(downloadPath);
          final localPath = '${dir.path}/$filename';
          final file = File(localPath);
          
          final request = http.Request('GET', Uri.parse(fileUrl));
          final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
          
          if (streamedResponse.statusCode == 200) {
            final sink = file.openWrite();
            try {
              await streamedResponse.stream.pipe(sink);
              await sink.close();
              
              await _notificationService.showDownloadCompleted(video.title, notificationId);
              
              await DatabaseHelper.instance.addNotification({
                'tipo': 'cancion',
                'titulo': 'Descarga Completada (Spotify)',
                'descripcion': video.title,
                'cantidad': 1,
              });
            } catch (e) {
              await sink.close();
              if (await file.exists()) await file.delete();
              rethrow;
            }
          } else {
            throw Exception('Error al descargar archivo de Spotify del servidor: ${streamedResponse.statusCode}');
          }
        } else {
          throw Exception('Backend falló al procesar la descarga de Spotify');
        }
      } else {
        throw Exception('Servidor de descarga no disponible (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error en la descarga de Spotify: $e');
      await _notificationService.showDownloadError(video.title, notificationId);
    }
  }

  Future<void> _executeAlbumDownload(AlbumResult album) async {
    final notificationId = _notificationId++;
    debugPrint('Iniciando descarga de álbum local: ${album.title}');
    
    try {
      final hasPermission = await PermissionService().requestStoragePermission();
      if (!hasPermission) {
        await _notificationService.showDownloadError(album.title, notificationId);
        return;
      }
      
      await _notificationService.showAlbumDownloadStarted(album.title, notificationId);
      
      // Obtener canciones
      final tracks = await getAlbumTracks(album.id);
      if (tracks.isEmpty) {
        throw Exception('No se encontraron canciones en el álbum');
      }
      
      final prefs = await SharedPreferences.getInstance();
      final downloadPath = prefs.getString('download_path') ?? '/storage/emulated/0/Music';
      
      final safeAlbumName = album.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final albumDir = Directory('$downloadPath/$safeAlbumName');
      if (!await albumDir.exists()) await albumDir.create(recursive: true);
      
      int downloadedCount = 0;
      final yt = youtube_explode.YoutubeExplode();
      final tempDir = await getTemporaryDirectory();
      
      for (final track in tracks) {
        File? tempAudioFile;
        File? tempArtFile;
        try {
          final safeTrackTitle = track.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          final localTrackPath = '${albumDir.path}/$safeTrackTitle.mp3';
          final trackFile = File(localTrackPath);
          
          if (await trackFile.exists()) {
            downloadedCount++;
            await _notificationService.updateAlbumDownloadProgress(
              album.title, downloadedCount, tracks.length, notificationId
            );
            continue;
          }
          
          // Stream de audio
          final manifest = await yt.videos.streamsClient.getManifest(track.id).timeout(const Duration(seconds: 15));
          final streamInfo = manifest.audioOnly.withHighestBitrate();
          final stream = yt.videos.streamsClient.get(streamInfo);
          
          final containerExt = streamInfo.container.name;
          tempAudioFile = File('${tempDir.path}/temp_${track.id}.$containerExt');
          final fileStream = tempAudioFile.openWrite();
          await stream.timeout(const Duration(seconds: 15)).pipe(fileStream);
          await fileStream.close();
          
          // Portada
          tempArtFile = File('${tempDir.path}/temp_art_${track.id}.jpg');
          if (track.thumbnail.isNotEmpty) {
            try {
              final imgResponse = await http.get(Uri.parse(track.thumbnail)).timeout(const Duration(seconds: 15));
              if (imgResponse.statusCode == 200) {
                await tempArtFile.writeAsBytes(imgResponse.bodyBytes);
              }
            } catch (e) {
              debugPrint('Error descargando carátula del track: $e');
            }
          }
          
          // Conversión y metadatos
          String escapeMetadata(String text) {
            return text.replaceAll('"', '\\"').replaceAll("'", "\\'");
          }
          final escapedTitle = escapeMetadata(track.title);
          final escapedArtist = escapeMetadata(track.author);
          final escapedAlbum = escapeMetadata(album.title);
          
          String ffmpegCommand;
          final hasArt = await tempArtFile.exists() && (await tempArtFile.length() > 0);
          
          if (hasArt) {
            ffmpegCommand = '-y -i "${tempAudioFile.path}" -i "${tempArtFile.path}" -map 0:a -map 1:0 -c:a libmp3lame -b:a 320k -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -metadata title="$escapedTitle" -metadata artist="$escapedArtist" -metadata album="$escapedAlbum" "$localTrackPath"';
          } else {
            ffmpegCommand = '-y -i "${tempAudioFile.path}" -c:a libmp3lame -b:a 320k -id3v2_version 3 -metadata title="$escapedTitle" -metadata artist="$escapedArtist" -metadata album="$escapedAlbum" "$localTrackPath"';
          }
          
          final session = await FFmpegKit.execute(ffmpegCommand);
          final returnCode = await session.getReturnCode();
          
          if (ReturnCode.isSuccess(returnCode)) {
            downloadedCount++;
            await _notificationService.updateAlbumDownloadProgress(
              album.title, downloadedCount, tracks.length, notificationId
            );
          }
        } catch (e) {
          debugPrint('Error descargando pista en álbum: $e');
        } finally {
          try {
            if (tempAudioFile != null && await tempAudioFile.exists()) {
              await tempAudioFile.delete();
            }
            if (tempArtFile != null && await tempArtFile.exists()) {
              await tempArtFile.delete();
            }
          } catch (e) {
            debugPrint('Error limpiando temporales de pista: $e');
          }
        }
      }
      
      yt.close();
      await _notificationService.showAlbumDownloadCompleted(album.title, notificationId);
      
      await DatabaseHelper.instance.addNotification({
        'tipo': 'album',
        'titulo': 'Descarga Completada',
        'descripcion': album.title,
        'cantidad': downloadedCount,
      });
    } catch (e) {
      debugPrint('Error en descarga de álbum local, usando fallback de backend: $e');
      await _executeAlbumDownloadFallback(album, notificationId);
    }
  }

  Future<void> _executeDownloadFallback(VideoResult video, int notificationId) async {
    try {
      debugPrint('Solicitando descarga al backend para: ${video.title}');
      await _notificationService.updateDownloadProgress(video.title, notificationId, 15);
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.downloadEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'video_id': video.id,
          'title': video.title,
        }),
      ).timeout(const Duration(minutes: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          debugPrint('Descarga en el backend exitosa');
          await _notificationService.updateDownloadProgress(video.title, notificationId, 50);
          
          final filename = data['file_path'].split('/').last;
          final encodedFilename = Uri.encodeComponent(filename);
          final fileUrl = '${ApiConfig.baseUrl}/download_file/$encodedFilename';
          
          debugPrint('Descargando archivo desde el backend: $fileUrl');
          
          final request = http.Request('GET', Uri.parse(fileUrl));
          final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
          
          if (streamedResponse.statusCode == 200) {
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
              await streamedResponse.stream.pipe(sink);
              await sink.close();
              
              final fileSize = await file.length();
              debugPrint('Archivo guardado: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
              
              await _notificationService.showDownloadCompleted(video.title, notificationId);
              
              await DatabaseHelper.instance.addNotification({
                'tipo': 'cancion',
                'titulo': 'Canción descargada',
                'descripcion': video.title,
                'cantidad': 1,
              });
            } catch (e) {
              debugPrint('Error guardando archivo del backend: $e');
              await sink.close();
              if (await file.exists()) {
                await file.delete();
              }
              await _notificationService.showDownloadError(video.title, notificationId);
            }
          } else {
            debugPrint('Error en descarga de archivo del backend: ${streamedResponse.statusCode}');
            await _notificationService.showDownloadError(video.title, notificationId);
          }
        } else {
          debugPrint('Error en respuesta del backend');
          await _notificationService.showDownloadError(video.title, notificationId);
        }
      } else {
        debugPrint('Error en solicitud al backend: ${response.statusCode}');
        await _notificationService.showDownloadError(video.title, notificationId);
      }
    } catch (e) {
      debugPrint('Error general en fallback de descarga: $e');
      await _notificationService.showDownloadError(video.title, notificationId);
    }
  }

  Future<void> _executeAlbumDownloadFallback(AlbumResult album, int notificationId) async {
    try {
      debugPrint('Solicitando descarga del álbum desde el backend: ${album.title}');
      await _notificationService.showAlbumDownloadStarted('${album.title} (Backend)', notificationId);
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.downloadAlbumEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'playlist_id': album.id,
          'album_title': album.title,
        }),
      ).timeout(const Duration(minutes: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final albumFolder = data['album_folder'];
          final downloadedFiles = data['downloaded_files'] as List;
          
          debugPrint('Álbum descargado en el backend: $albumFolder');
          
          final prefs = await SharedPreferences.getInstance();
          final downloadPath = prefs.getString('download_path') ?? '/storage/emulated/0/Music';
          
          final albumDir = Directory('$downloadPath/$albumFolder');
          if (!await albumDir.exists()) {
            await albumDir.create(recursive: true);
          }
          
          int downloaded = 0;
          for (var fileInfo in downloadedFiles) {
            final filename = fileInfo['file_path'];
            final encodedParts = filename.split('/').map((p) => Uri.encodeComponent(p)).join('/');
            final fileUrl = '${ApiConfig.baseUrl}/download_file/$encodedParts';
            
            try {
              final request = http.Request('GET', Uri.parse(fileUrl));
              final fileResponse = await request.send().timeout(const Duration(minutes: 5));
              
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
              debugPrint('Error descargando pista de backend: $e');
              continue;
            }
          }
          
          await _notificationService.showAlbumDownloadCompleted(album.title, notificationId);
        } else {
          throw Exception('Error devuelto por el backend de descarga de álbum');
        }
      } else {
        throw Exception('Servidor de descarga de álbum no disponible (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error general en fallback de descarga de álbum: $e');
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