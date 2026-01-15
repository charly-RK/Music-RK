import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        playNext();
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final _songStreamController = StreamController<SongModel?>.broadcast();
  
  // Reference to the audio handler for background notifications
  dynamic _audioHandler;
  
  List<SongModel> _songs = [];
  List<SongModel>? _activePlaylist;
  String? _playlistContext; // Nombre del álbum/playlist actual
  int _currentIndex = 0;
  bool _isSongLoaded = false;

  // Streams
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<SongModel?> get currentSongStream => _songStreamController.stream;
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;

  // Getters
  AudioPlayer get player => _player;
  List<SongModel> get songs => _songs;
  SongModel? get currentSong => _songs.isEmpty ? null : _songs[_currentIndex];
  int get currentIndex => _currentIndex;
  bool get isSongLoaded => _isSongLoaded;
  String? get playlistContext => _playlistContext;

  /// Establecer el handler de audio para notificaciones
  void setAudioHandler(dynamic handler) {
    _audioHandler = handler;
    
    // Configurar callbacks para que el handler delegue las acciones al AudioService
    _audioHandler?.onSkipToNext = () async {
      debugPrint('🎵 Callback onSkipToNext ejecutado');
      await playNext();
    };
    
    _audioHandler?.onSkipToPrevious = () async {
      debugPrint('🎵 Callback onSkipToPrevious ejecutado');
      await playPrevious();
    };
    
    // Escuchar cambios en el MediaItem del handler para sincronizar estado
    // Esto asegura que cuando el usuario cambia de canción desde la notificación,
    // el estado interno del AudioService se actualice
    _audioHandler?.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        final songId = int.tryParse(mediaItem.id);
        if (songId != null && _songs.isNotEmpty) {
          final index = _songs.indexWhere((s) => s.id == songId);
          if (index != -1 && index != _currentIndex) {
            debugPrint('🔄 Sincronizando desde notificación: ${mediaItem.title}');
            _currentIndex = index;
            _songStreamController.add(_songs[index]);
          }
        }
      }
    });
  }

  /// Establecer contexto de playlist (nombre del álbum o null)
  void setPlaylistContext(String? context) {
    _playlistContext = context;
    debugPrint('🎵 Contexto de playlist establecido: ${context ?? "Todas las canciones"}');
  }

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Consultar todos los archivos de audio del dispositivo
  Future<List<SongModel>> querySongs({
    SongSortType sortType = SongSortType.TITLE,
    OrderType orderType = OrderType.ASC_OR_SMALLER,
    bool updateList = true,
  }) async {
    try {
      final allSongs = await _audioQuery.querySongs(
        sortType: sortType,
        orderType: orderType,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      if (_prefs == null) await init();
      
      final searchAll = _prefs?.getBool('search_all_device') ?? true;
      final folders = _prefs?.getStringList('music_folders') ?? [];

      List<SongModel> filteredSongs;

      if (searchAll || folders.isEmpty) {
        filteredSongs = _filterSongs(allSongs);
      } else {
        // Combined filtering for efficiency
        filteredSongs = allSongs.where((song) {
          final path = song.data;
          // Check folder first
          bool inFolder = false;
          for (final folder in folders) {
            if (path.startsWith(folder)) {
              inFolder = true;
              break;
            }
          }
          if (!inFolder) return false;
          
          // Then check extension and other filters
          return _isValidSong(song);
        }).toList();
      }

      if (updateList) {
        _songs = filteredSongs;
      }

      return filteredSongs;
    } catch (e) {
      debugPrint("❌ Error querying songs: $e");
      return [];
    }
  }

  /// Filtrar archivos no MP3 y notas de voz de WhatsApp
  List<SongModel> _filterSongs(List<SongModel> songs) {
    return songs.where(_isValidSong).toList();
  }

  bool _isValidSong(SongModel song) {
    final path = song.data.toLowerCase();
    final displayName = song.displayName.toLowerCase();
    final title = song.title.toLowerCase();
    
    // Filter 1: Only MP3 files
    if (!path.endsWith('.mp3')) {
      return false;
    }

    // Filter 2: AUD Files - Filter out files starting with 'aud-' (case insensitive)
    if (displayName.startsWith('aud-')) {
      return false;
    }

    // Filter 3: Numeric Sequences - Filter out files with 6+ consecutive digits
    final numericPattern = RegExp(r'\d{6,}');
    if (numericPattern.hasMatch(displayName) || numericPattern.hasMatch(title)) {
      return false;
    }

    // Filter 4: Domain Names - Filter out files containing common domain extensions
    final domainExtensions = [
      '.io', '.app', '.com', '.net', '.org', '.co', 
      '.me', '.dev', '.xyz', '.tech', '.online', '.site'
    ];
    
    for (final extension in domainExtensions) {
      if (displayName.contains(extension) || title.contains(extension)) {
        return false;
      }
    }

    return true;
  }

  /// Forzar recarga de la biblioteca
  Future<void> reloadLibrary() async {
    await querySongs();
  }

  /// Alternar modo de repetición: Off -> All -> One -> Off
  Future<void> toggleRepeatMode() async {
    final current = _player.loopMode;
    if (current == LoopMode.off) {
      await _player.setLoopMode(LoopMode.all);
    } else if (current == LoopMode.all) {
      await _player.setLoopMode(LoopMode.one);
    } else {
      await _player.setLoopMode(LoopMode.off);
    }
  }

  /// Reproducir una canción específica por índice
  Future<void> playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    
    _currentIndex = index;
    final song = _songs[index];
    _songStreamController.add(song);
    
    try {
      // Primero actualizar la notificación ANTES de cambiar la fuente de audio
      if (_audioHandler != null) {
        // Fire and forget update to avoid blocking playback
        _audioHandler.updateSongQueue(_songs, _currentIndex, _playlistContext);
      }
      
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(song.uri!)),
      );
      _isSongLoaded = true;
      
      // Guardar última canción reproducida (non-blocking)
      _saveLastSong(index);
      
      await _player.play();
    } catch (e) {
      debugPrint('❌ Error en playSong: $e');
      _isSongLoaded = false;
    }
  }

  /// Reproducir o pausar
  Future<void> togglePlayPause() async {
    if (!_isSongLoaded) {
      if (_songs.isNotEmpty) {
        await playSong(_currentIndex);
      }
      return;
    }

    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// Reproducir
  Future<void> play() async {
    await _player.play();
  }

  /// Pausar
  Future<void> pause() async {
    await _player.pause();
  }

  /// Buscar a una posición específica
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Establecer lista de reproducción activa
  void setPlaylist(List<SongModel> playlist) {
    _activePlaylist = playlist;
  }

  /// Limpiar lista de reproducción activa
  void clearPlaylist() {
    _activePlaylist = null;
  }

  /// Reproducir siguiente canción
  Future<void> playNext() async {
    try {
      final playList = _activePlaylist ?? _songs;
      if (playList.isEmpty) return;
      
      if (_activePlaylist != null) {
        final currentSongId = currentSong?.id;
        final currentPlaylistIndex = playList.indexWhere((s) => s.id == currentSongId);
        
        if (currentPlaylistIndex != -1) {
          final nextPlaylistIndex = (currentPlaylistIndex + 1) % playList.length;
          final nextSong = playList[nextPlaylistIndex];
          final globalIndex = _songs.indexWhere((s) => s.id == nextSong.id);
          if (globalIndex != -1) {
            await playSong(globalIndex);
          }
        }
      } else {
        _currentIndex = (_currentIndex + 1) % _songs.length;
        await playSong(_currentIndex);
      }
    } catch (e) {
      debugPrint("❌ Error in playNext: $e");
    }
  }

  /// Reproducir canción anterior
  Future<void> playPrevious() async {
    try {
      final playList = _activePlaylist ?? _songs;
      if (playList.isEmpty) return;
      
      if (_activePlaylist != null) {
        final currentSongId = currentSong?.id;
        final currentPlaylistIndex = playList.indexWhere((s) => s.id == currentSongId);
        
        if (currentPlaylistIndex != -1) {
          final prevPlaylistIndex = (currentPlaylistIndex - 1 + playList.length) % playList.length;
          final prevSong = playList[prevPlaylistIndex];
          final globalIndex = _songs.indexWhere((s) => s.id == prevSong.id);
          if (globalIndex != -1) {
            await playSong(globalIndex);
          }
        }
      } else {
        _currentIndex = (_currentIndex - 1 + _songs.length) % _songs.length;
        await playSong(_currentIndex);
      }
    } catch (e) {
      debugPrint("❌ Error in playPrevious: $e");
    }
  }

  /// Detener y liberar recursos
  Future<void> dispose() async {
    await _player.dispose();
    await _songStreamController.close();
  }

  /// Obtener bytes de la carátula del álbum
  Future<List<int>?> getAlbumArt(int songId, {int? size}) async {
    try {
      return await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        size: size,
      );
    } catch (e) {
      return null;
    }
  }

  /// Guardar última canción reproducida
  Future<void> _saveLastSong(int index) async {
    try {
      if (_prefs == null) await init();
      await _prefs?.setInt('last_song_index', index);
      if (index >= 0 && index < _songs.length) {
        await _prefs?.setInt('last_song_id', _songs[index].id);
      }
    } catch (e) {
      debugPrint('❌ Error guardando última canción: $e');
    }
  }

  /// Restaurar última canción reproducida
  Future<void> restoreLastSong() async {
    try {
      if (_prefs == null) await init();
      final lastIndex = _prefs?.getInt('last_song_index');
      final lastSongId = _prefs?.getInt('last_song_id');
      
      if (lastIndex != null && lastSongId != null && _songs.isNotEmpty) {
        // Verificar que el índice sigue siendo válido
        if (lastIndex < _songs.length && _songs[lastIndex].id == lastSongId) {
          _currentIndex = lastIndex;
          _songStreamController.add(_songs[lastIndex]);
        } else {
          // Buscar la canción por ID si el índice cambió
          final foundIndex = _songs.indexWhere((s) => s.id == lastSongId);
          if (foundIndex != -1) {
            _currentIndex = foundIndex;
            _songStreamController.add(_songs[foundIndex]);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error restaurando última canción: $e');
    }
  }
}