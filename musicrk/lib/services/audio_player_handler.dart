import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'database_helper.dart';

/// Handler para el servicio de audio en segundo plano
/// Gestiona la notificación de reproducción con controles
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  List<SongModel> _songs = [];
  int _currentIndex = 0;
  bool _isFavorite = false;
  
  // Callbacks para delegar acciones al AudioService
  Function()? onSkipToNext;
  Function()? onSkipToPrevious;

  AudioPlayerHandler(this._player) {
    // Escuchar cambios de estado del reproductor
    _player.playbackEventStream.listen(_broadcastState);
    
    // Escuchar cambios de posición para actualizar la barra de progreso
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
    
    // Escuchar cambios de duración para actualizar MediaItem cuando esté disponible
    _player.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        final currentItem = mediaItem.value!;
        // Solo actualizar si la duración cambió (de 0 a un valor real)
        if (currentItem.duration != duration && duration.inMilliseconds > 0) {
          mediaItem.add(currentItem.copyWith(duration: duration));
        }
      }
    });
  }

  /// Actualizar la lista de canciones (método personalizado, no override)
  Future<void> updateSongQueue(List<SongModel> songs, int currentIndex, [String? playlistContext]) async {
    _songs = songs;
    _currentIndex = currentIndex;
    
    if (songs.isNotEmpty && currentIndex < songs.length) {
      await _updateMediaItem(songs[currentIndex], playlistContext);
    }
  }

  /// Actualizar el MediaItem actual (información de la notificación)
  Future<void> _updateMediaItem(SongModel song, [String? playlistContext]) async {
    // Verificar si es favorito
    _isFavorite = await _dbHelper.isFavorite(song.id);
    
    // Obtener artwork usando archivo temporal para evitar límites de Android
    Uri? artUri = await _getArtworkUri(song);
    
    final mediaItem = MediaItem(
      id: song.id.toString(),
      title: song.title,
      artist: song.artist ?? 'Desconocido',
      album: song.album ?? 'Desconocido',
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: artUri,
      extras: {
        'isFavorite': _isFavorite,
        'playlistContext': playlistContext,
      },
    );
    
    this.mediaItem.add(mediaItem);
    _broadcastState(_player.playbackEvent);
  }

  /// Obtener URI de artwork, guardando en archivo temporal si es necesario
  Future<Uri?> _getArtworkUri(SongModel song) async {
    try {
      // Intento 1: Artwork del audio
      final artworkBytes = await _audioQuery.queryArtwork(
        song.id,
        ArtworkType.AUDIO,
        size: 500,
        quality: 100,
      );
      
      if (artworkBytes != null && artworkBytes.isNotEmpty) {
        // Guardar en archivo temporal para evitar límites de transacción de Android
        final tempDir = await getTemporaryDirectory();
        final artworkFile = File('${tempDir.path}/artwork_${song.id}.jpg');
        await artworkFile.writeAsBytes(artworkBytes);
        return Uri.file(artworkFile.path);
      }
      
      // Intento 2: Artwork del álbum
      final albumArt = await _audioQuery.queryArtwork(
        song.id,
        ArtworkType.ALBUM,
        size: 500,
        quality: 100,
      );
      
      if (albumArt != null && albumArt.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final artworkFile = File('${tempDir.path}/artwork_${song.id}.jpg');
        await artworkFile.writeAsBytes(albumArt);
        return Uri.file(artworkFile.path);
      }
      
      return _createFallbackArtUri(song.title);
    } catch (e) {
      return _createFallbackArtUri(song.title);
    }
  }

  /// Crear una imagen de respaldo simple (1x1 pixel de color)
  Uri _createFallbackArtUri(String title) {
    // Generar un color basado en el hash del título
    final hash = title.hashCode.abs();
    final r = ((hash & 0xFF0000) >> 16).clamp(80, 220);
    final g = ((hash & 0x00FF00) >> 8).clamp(80, 220);
    final b = (hash & 0x0000FF).clamp(80, 220);
    
    // Crear una imagen PNG 1x1 con el color
    // PNG header + IHDR + IDAT + IEND chunks
    final pngBytes = Uint8List.fromList([
      // PNG signature
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      // IHDR chunk
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
      // IDAT chunk with RGB pixel
      0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,
      0x08, 0xD7, 0x63, r, g, b, 0x00, 0x00, 0x00, 0x04,
      0x00, 0x01, 0x00, 0x00,
      // IEND chunk
      0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
      0xAE, 0x42, 0x60, 0x82
    ]);
    
    return Uri.dataFromBytes(pngBytes, mimeType: 'image/png');
  }

  /// Transmitir el estado actual del reproductor
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    
    playbackState.add(playbackState.value.copyWith(
      controls: [
        // Botón de favorito (dinámico según el estado)
        MediaControl(
          androidIcon: _isFavorite ? 'drawable/ic_favorite' : 'drawable/ic_favorite_border',
          label: _isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
          action: MediaAction.custom,
          customAction: const CustomMediaAction(name: 'toggle_favorite'),
        ),
        // Anterior
        MediaControl.skipToPrevious,
        // Play/Pause
        if (playing) MediaControl.pause else MediaControl.play,
        // Siguiente
        MediaControl.skipToNext,
        // Cerrar
        const MediaControl(
          androidIcon: 'drawable/ic_close',
          label: 'Cerrar',
          action: MediaAction.stop,
        ),
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [1, 2, 3], // Anterior, Play/Pause, Siguiente
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    ));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    // Delegar al AudioService para que respete la playlist activa
    if (onSkipToNext != null) {
      await onSkipToNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // Delegar al AudioService para que respete la playlist activa
    if (onSkipToPrevious != null) {
      await onSkipToPrevious!();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  /// Manejar acciones personalizadas (como toggle favorite)
  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'toggle_favorite') {
      await _toggleFavorite();
    }
    return super.customAction(name, extras);
  }

  /// Alternar estado de favorito
  Future<void> _toggleFavorite() async {
    if (_songs.isEmpty || _currentIndex >= _songs.length) return;
    
    final song = _songs[_currentIndex];
    
    if (_isFavorite) {
      // Quitar de favoritos
      await _dbHelper.removeFavorite(song.id);
      _isFavorite = false;
    } else {
      // Agregar a favoritos
      await _dbHelper.addFavorite({
        'song_id': song.id,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'data': song.data,
        'duration': song.duration,
      });
      _isFavorite = true;
    }
    
    // Actualizar la notificación
    await _updateMediaItem(song);
  }

  int get currentIndex => _currentIndex;
  bool get isFavorite => _isFavorite;
}
