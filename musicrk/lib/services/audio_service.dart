import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';
import 'permission_service.dart';

List<SongModel> _filterSongsTask(Map<String, dynamic> params) {
  final List<dynamic> songsList = params['songs'];
  final List<String> folders = List<String>.from(params['folders']);
  final bool searchAll = params['searchAll'];
  final List<SongModel> allSongs = songsList.map((s) => SongModel(s as Map<dynamic, dynamic>)).toList();

  bool isValidSong(SongModel song) {
    final path = song.data.toLowerCase();
    final displayName = song.displayName.toLowerCase();
    final title = song.title.toLowerCase();
    if (!path.endsWith('.mp3')) return false;
    if (displayName.startsWith('aud-')) return false;
    final numericPattern = RegExp(r'\d{6,}');
    if (numericPattern.hasMatch(displayName) || numericPattern.hasMatch(title)) return false;
    final domainExtensions = ['.io', '.app', '.com', '.net', '.org', '.co', '.me', '.dev', '.xyz', '.tech', '.online', '.site'];
    for (final extension in domainExtensions) {
      if (displayName.contains(extension) || title.contains(extension)) return false;
    }
    return true;
  }

  if (searchAll || folders.isEmpty) {
    return allSongs.where(isValidSong).toList();
  } else {
    return allSongs.where((song) {
      final path = song.data;
      bool inFolder = false;
      for (final folder in folders) {
        if (path.startsWith(folder)) { inFolder = true; break; }
      }
      return inFolder && isValidSong(song);
    }).toList();
  }
}

class _ScoredSong {
  final SongModel song;
  final int score;
  _ScoredSong(this.song, this.score);
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) playNext();
    });
    _initAudioSession();
  }

  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final _songStreamController = StreamController<SongModel?>.broadcast();
  dynamic _audioHandler;
  List<SongModel> _songs = [];
  List<SongModel>? _activePlaylist;
  String? _playlistContext;
  int _currentIndex = 0;
  bool _isSongLoaded = false;
  SharedPreferences? _prefs;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<SongModel?> get currentSongStream => _songStreamController.stream;
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;

  AudioPlayer get player => _player;
  List<SongModel> get songs => _songs;
  SongModel? get currentSong => _songs.isEmpty ? null : _songs[_currentIndex];
  int get currentIndex => _currentIndex;
  bool get isSongLoaded => _isSongLoaded;
  String? get playlistContext => _playlistContext;

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    
    // Handle interruptions (phone calls, etc)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            _player.pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            _player.play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });
  }

  void setAudioHandler(dynamic handler) {
    _audioHandler = handler;
    _audioHandler?.onSkipToNext = () async => await playNext();
    _audioHandler?.onSkipToPrevious = () async => await playPrevious();
    _audioHandler?.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        final songId = int.tryParse(mediaItem.id);
        if (songId != null && _songs.isNotEmpty) {
          final index = _songs.indexWhere((s) => s.id == songId);
          if (index != -1 && index != _currentIndex) {
            _currentIndex = index;
            _songStreamController.add(_songs[index]);
          }
        }
      }
    });
  }

  void setPlaylistContext(String? context) => _playlistContext = context;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<SongModel>> querySongs({
    SongSortType sortType = SongSortType.TITLE,
    OrderType orderType = OrderType.ASC_OR_SMALLER,
    bool updateList = true,
    bool forceRefresh = false,
  }) async {
    try {
      if (_prefs == null) await init();
      if (!forceRefresh) {
        final cachedData = await DatabaseHelper.instance.getCachedSongs();
        if (cachedData.isNotEmpty) {
          final cachedSongs = cachedData.map((s) => SongModel({
            '_id': s['id'],
            'title': s['title'],
            'artist': s['artist'],
            'album': s['album'],
            '_data': s['data'],
            'duration': s['duration'],
            '_uri': s['uri'],
            '_display_name': s['display_name'],
          })).toList();
          if (updateList) _songs = cachedSongs;
          return cachedSongs;
        }
      }
      final allSongsRaw = await _audioQuery.querySongs(sortType: sortType, orderType: orderType, uriType: UriType.EXTERNAL, ignoreCase: true);
      final searchAll = _prefs?.getBool('search_all_device') ?? true;
      final folders = _prefs?.getStringList('music_folders') ?? [];
      final filteredSongs = await compute(_filterSongsTask, {'songs': allSongsRaw.map((s) => s.getMap).toList(), 'folders': folders, 'searchAll': searchAll});
      if (filteredSongs.isNotEmpty) {
        final List<Map<String, dynamic>> songsToCache = filteredSongs.map((s) {
          final map = s.getMap;
          return {
            'id': map['_id'],
            'title': map['title'],
            'artist': map['artist'],
            'album': map['album'],
            'data': map['_data'],
            'duration': map['duration'],
            'uri': map['_uri'],
            'display_name': map['_display_name'],
          };
        }).toList();
        unawaited(DatabaseHelper.instance.replaceSongCache(songsToCache));
      }
      if (updateList) _songs = filteredSongs;
      return filteredSongs;
    } catch (e) {
      debugPrint("❌ Error querying songs: $e");
      return [];
    }
  }

  Future<void> reloadLibrary() async => await querySongs(forceRefresh: true);

  List<SongModel> searchLocalSongs(String query) {
    if (query.isEmpty) return [];
    final normalizedQuery = _normalize(query);
    final scoredSongs = _songs.map((song) {
      final title = _normalize(song.title);
      final artist = _normalize(song.artist ?? '');
      int score = 0;
      if (title == normalizedQuery) score += 100;
      else if (artist == normalizedQuery) score += 80;
      else if (title.startsWith(normalizedQuery)) score += 50;
      else if (title.contains(normalizedQuery)) score += 20;
      return _ScoredSong(song, score);
    }).where((s) => s.score > 0).toList();
    scoredSongs.sort((a, b) => b.score.compareTo(a.score));
    return scoredSongs.map((s) => s.song).toList();
  }

  String _normalize(String text) {
    return text.toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a').replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i').replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u').replaceAll(RegExp(r'[ñ]'), 'n').trim();
  }

  Future<void> toggleRepeatMode() async {
    final current = _player.loopMode;
    if (current == LoopMode.off) await _player.setLoopMode(LoopMode.all);
    else if (current == LoopMode.all) await _player.setLoopMode(LoopMode.one);
    else await _player.setLoopMode(LoopMode.off);
  }

  Future<void> playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    _currentIndex = index;
    final song = _songs[index];
    _songStreamController.add(song);
    try {
      if (_audioHandler != null) _audioHandler.updateSongQueue(_songs, _currentIndex, _playlistContext);
      await _player.setAudioSource(AudioSource.uri(Uri.parse(song.uri!)));
      _isSongLoaded = true;
      _saveLastSong(index);
      await play();
    } catch (e) {
      debugPrint('❌ Error en playSong: $e');
      _isSongLoaded = false;
    }
  }

  Future<void> togglePlayPause() async {
    if (!_isSongLoaded) { if (_songs.isNotEmpty) await playSong(_currentIndex); return; }
    if (_player.playing) await pause(); else await play();
  }

  Future<void> play() async {
    await WakelockPlus.enable();
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
    await WakelockPlus.disable();
  }

  Future<void> seek(Duration position) async => await _player.seek(position);

  void setPlaylist(List<SongModel> playlist) => _activePlaylist = playlist;
  void clearPlaylist() => _activePlaylist = null;

  Future<void> playNext() async {
    final playList = _activePlaylist ?? _songs;
    if (playList.isEmpty) return;
    if (_activePlaylist != null) {
      final currentPlaylistIndex = playList.indexWhere((s) => s.id == currentSong?.id);
      if (currentPlaylistIndex != -1) {
        final nextSong = playList[(currentPlaylistIndex + 1) % playList.length];
        final globalIndex = _songs.indexWhere((s) => s.id == nextSong.id);
        if (globalIndex != -1) await playSong(globalIndex);
      }
    } else {
      _currentIndex = (_currentIndex + 1) % _songs.length;
      await playSong(_currentIndex);
    }
  }

  Future<void> playPrevious() async {
    final playList = _activePlaylist ?? _songs;
    if (playList.isEmpty) return;
    if (_activePlaylist != null) {
      final currentPlaylistIndex = playList.indexWhere((s) => s.id == currentSong?.id);
      if (currentPlaylistIndex != -1) {
        final prevSong = playList[(currentPlaylistIndex - 1 + playList.length) % playList.length];
        final globalIndex = _songs.indexWhere((s) => s.id == prevSong.id);
        if (globalIndex != -1) await playSong(globalIndex);
      }
    } else {
      _currentIndex = (_currentIndex - 1 + _songs.length) % _songs.length;
      await playSong(_currentIndex);
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _songStreamController.close();
    await WakelockPlus.disable();
  }

  Future<List<int>?> getAlbumArt(int songId, {int? size}) async {
    try { return await _audioQuery.queryArtwork(songId, ArtworkType.AUDIO, size: size); } catch (e) { return null; }
  }

  Future<void> _saveLastSong(int index) async {
    try {
      if (_prefs == null) await init();
      await _prefs?.setInt('last_song_index', index);
      if (index >= 0 && index < _songs.length) await _prefs?.setInt('last_song_id', _songs[index].id);
    } catch (e) { debugPrint('❌ Error guardando última canción: $e'); }
  }

  Future<void> restoreLastSong() async {
    try {
      if (_prefs == null) await init();
      final lastIndex = _prefs?.getInt('last_song_index');
      final lastSongId = _prefs?.getInt('last_song_id');
      if (lastIndex != null && lastSongId != null && _songs.isNotEmpty) {
        if (lastIndex < _songs.length && _songs[lastIndex].id == lastSongId) {
          _currentIndex = lastIndex;
          _songStreamController.add(_songs[lastIndex]);
        } else {
          final foundIndex = _songs.indexWhere((s) => s.id == lastSongId);
          if (foundIndex != -1) { _currentIndex = foundIndex; _songStreamController.add(_songs[foundIndex]); }
        }
      }
    } catch (e) { debugPrint('❌ Error restaurando última canción: $e'); }
  }

  // --- NUEVAS FUNCIONES DE GESTIÓN DE ARCHIVOS ---

  Future<bool> deleteSong(SongModel song) async {
    try {
      // 0. Verificar permisos básicos (ya deberían estar otorgados desde el inicio)
      if (Platform.isAndroid && !await PermissionService().hasStoragePermission()) {
        debugPrint("❌ Sin permisos de almacenamiento para eliminar");
        return false;
      }

      // 1. Si es la canción actual, detener o saltar
      if (currentSong?.id == song.id) {
        if (_songs.length > 1) {
          await playNext();
        } else {
          await _player.stop();
          _isSongLoaded = false;
          _songStreamController.add(null);
        }
      }

      // 2. Eliminar archivo físico
      final file = File(song.data);
      if (await file.exists()) {
        await file.delete();
      }

      // 3. Eliminar de la base de datos (todas las tablas)
      await DatabaseHelper.instance.removeSongEverywhere(song.id, song.data);

      // 4. Recargar librería local
      await reloadLibrary();
      
      return true;
    } catch (e) {
      debugPrint("❌ Error al eliminar canción: $e");
      return false;
    }
  }

  Future<bool> renameSong(SongModel song, String newTitle) async {
    try {
      // 0. Verificar permisos básicos
      if (Platform.isAndroid && !await PermissionService().hasStoragePermission()) {
        debugPrint("❌ Sin permisos de almacenamiento para renombrar");
        return false;
      }

      final file = File(song.data);
      if (await file.exists()) {
        // Sanitizar título y obtener extensión
        final sanitizedTitle = _sanitizeFilename(newTitle);
        if (sanitizedTitle.isEmpty) return false;
        
        final ext = song.data.split('.').last;
        final newPath = '${file.parent.path}/$sanitizedTitle.$ext';
        
        if (await File(newPath).exists() && newPath.toLowerCase() != song.data.toLowerCase()) {
          debugPrint("❌ El archivo de destino ya existe: $newPath");
          return false;
        }
        
        // 1. Si es la canción actual, pausar un momento para liberar el archivo (a veces necesario en Windows/Android)
        bool wasPlaying = _player.playing;
        if (currentSong?.id == song.id) {
          await _player.stop();
        }

        // 2. Renombrar archivo
        await file.rename(newPath);

        // 3. Actualizar base de datos
        await DatabaseHelper.instance.updateSongPathAndTitle(song.id, song.data, newPath, newTitle);

        // 4. Recargar librería y actualizar estado interno
        await reloadLibrary();

        // 5. Crear una copia de la canción con los datos actualizados para notificar a la UI
        final updatedSong = SongModel({
          ...song.getMap,
          'title': newTitle,
          '_data': newPath,
          '_display_name': sanitizedTitle,
        });

        // 6. Si era la actual, intentar retomar y notificar cambio de metadatos
        if (currentSong?.id == song.id) {
          final newIndex = _songs.indexWhere((s) => s.id == song.id);
          if (newIndex != -1) {
            _currentIndex = newIndex;
            _songStreamController.add(_songs[newIndex]);
            await playSong(newIndex);
            if (!wasPlaying) await _player.pause();
          }
        } else {
          // Si no es la actual, igual notificamos si alguna pantalla está escuchando este objeto específico
          // Aunque usualmente las pantallas escuchan el stream global.
        }
        
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Error al renombrar canción de '${song.data}' a: $newTitle");
      debugPrint("❌ Detalle del error: $e");
      return false;
    }
  }

  String _sanitizeFilename(String name) {
    // Eliminar caracteres no permitidos en Windows/Android (?, :, *, <, >, |, \, /)
    // y otros caracteres que podrían dar problemas en algunos sistemas
    return name.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}