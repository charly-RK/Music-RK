import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart' as app_audio;
import 'play.dart';
import '../widgets/bottom_player.dart';
import '../widgets/song_options_sheet.dart';

class ArtistPage extends StatefulWidget {
  final ArtistModel artist;

  const ArtistPage({super.key, required this.artist});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final app_audio.AudioService _audioService = app_audio.AudioService();
  List<SongModel> _songs = [];
  bool _isLoading = true;
  String _totalDuration = "";
  bool _isPlaying = false;
  String _sortOrder = 'title';
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _loadSortOrder();
    _loadSongs();
    
    _audioService.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    
    _audioService.currentSongStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    List<SongModel> songs = [];

    try {
      // Como el modelo puede ser un artista agrupado que en realidad abarca canciones de múltiples IDs
      // de colaboraciones (ej. 'Natanael Cano ft X'), en lugar de buscar por ARTIST_ID estricto,
      // buscamos en toda la lista de canciones aquellas cuyo nombre de artista principal coincida.
      
      final String targetArtistName = widget.artist.artist.toLowerCase();
      
      // Optimizamos obteniendo de AudioService si ya tiene cache, o haciendo query universal
      List<SongModel> allSongs = _audioService.songs.isNotEmpty 
          ? _audioService.songs 
          : await _audioQuery.querySongs(
              sortType: SongSortType.TITLE,
              orderType: OrderType.ASC_OR_SMALLER,
              ignoreCase: true,
            );
            
      songs = allSongs.where((song) {
        if (song.artist == null) return false;
        
        // limpiar artista de la cancion
        String songArtistRaw = song.artist!;
        String mainSongArtist = songArtistRaw.split(RegExp(r'\s*(feat\.?|ft\.?|,|&|\+)\s*', caseSensitive: false)).first.trim().toLowerCase();
        
        // También comprobar si el target está contenido, por si acaso (e.j "Natanael Cano" in "Natanael Cano & Peso Pluma")
        return mainSongArtist == targetArtistName || songArtistRaw.toLowerCase().contains(targetArtistName);
      }).toList();

    } catch (e) {
      debugPrint("Error loading artist songs: $e");
    }

    _applySorting(songs);

    int totalMs = songs.fold(0, (sum, song) => sum + (song.duration ?? 0));
    int totalMinutes = (totalMs / 1000 / 60).floor();
    String formattedDuration;
    
    if (totalMinutes >= 60) {
      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;
      formattedDuration = minutes > 0 ? "$hours h $minutes min" : "$hours h";
    } else {
      formattedDuration = "$totalMinutes min";
    }

    setState(() {
      _songs = songs;
      _totalDuration = formattedDuration;
      _isLoading = false;
    });
  }

  Future<void> _loadSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final artistKey = 'sort_artist_${widget.artist.id}';
    setState(() {
      _sortOrder = prefs.getString(artistKey) ?? 'default';
    });
  }

  Future<void> _saveSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final artistKey = 'sort_artist_${widget.artist.id}';
    await prefs.setString(artistKey, _sortOrder);
  }

  void _applySorting(List<SongModel> songs) {
    if (_sortOrder == 'album') {
      songs.sort((a, b) => (a.album ?? "").toLowerCase().compareTo((b.album ?? "").toLowerCase()));
    } else {
      // title order
      songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
  }

  void _cycleSortOrder() {
    setState(() {
      if (_sortOrder == 'title') {
        _sortOrder = 'album';
      } else {
        _sortOrder = 'title';
      }
    });
    _saveSortOrder();
    _loadSongs();

    String message = _sortOrder == 'title' ? 'Título' : 'Álbum';
    _showCustomToast(message, _sortOrder);
  }

  void _showCustomToast(String message, String iconType) {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }

    IconData sortIcon = Icons.sort_by_alpha_rounded;
    if (iconType == 'album') sortIcon = Icons.album_rounded;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 2 - 25,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(sortIcon, color: const Color(0xFFE91E63), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_overlayEntry != null && mounted) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  void _playArtist([int index = 0]) async {
    if (_songs.isEmpty) return;
    
    if (index < 0 || index >= _songs.length) {
      index = 0;
    }
    
    _audioService.setPlaylist(_songs);
    _audioService.setPlaylistContext('artist_${widget.artist.id}');
    
    final song = _songs[index];
    int globalIndex = _audioService.songs.indexWhere((s) => s.id == song.id);
    
    if (globalIndex == -1) {
      await _audioService.reloadLibrary();
      globalIndex = _audioService.songs.indexWhere((s) => s.id == song.id);
    }
    
    if (globalIndex != -1) {
      await _audioService.playSong(globalIndex);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se pudo encontrar la canción.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _shuffleSongs() {
    setState(() {
      _songs.shuffle();
    });
    _audioService.setPlaylist(_songs);
  }

  void _showSongOptions(SongModel song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SongOptionsSheet(
        song: song,
        onPlay: () {
          final index = _songs.indexOf(song);
          if (index != -1) _playArtist(index);
        },
      ),
    );
  }

  Widget _buildInfoBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = _audioService.currentSong;
    final bool isCurrentSongInArtist = currentSong != null && _songs.any((s) => s.id == currentSong.id);
    final String contextId = 'artist_${widget.artist.id}';
    final bool isSameContext = _audioService.playlistContext == contextId;
    final bool showPause = _isPlaying && isCurrentSongInArtist && isSameContext;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final headerHeight = screenHeight * 0.42; 
    final albumArtSize = screenWidth * 0.35; 
    final playButtonSize = screenWidth * 0.16; 

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                height: headerHeight.clamp(300.0, 400.0), 
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1A1F3D),
                      Color(0xFF121212),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(width: 48), // Espacio para centrar el titulo sin el botón de más opciones
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      
                      // Artist Art
                      Hero(
                        tag: 'artist_art_${widget.artist.id}',
                        child: Container(
                          width: albumArtSize.clamp(100.0, 150.0),
                          height: albumArtSize.clamp(100.0, 150.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white10, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: QueryArtworkWidget(
                              id: widget.artist.id,
                              type: ArtworkType.ARTIST,
                              artworkWidth: albumArtSize.clamp(100.0, 150.0).toDouble(),
                              artworkHeight: albumArtSize.clamp(100.0, 150.0).toDouble(),
                              artworkQuality: FilterQuality.medium,
                              keepOldArtwork: true,
                              artworkFit: BoxFit.cover,
                              size: 300, 
                              nullArtworkWidget: Container(
                                color: Colors.grey[900],
                                child: Icon(Icons.person, size: albumArtSize.clamp(100.0, 150.0) * 0.5, color: Colors.white24),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Artist Name
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          widget.artist.artist,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildInfoBadge("${_songs.length} Canciones", Icons.music_note_rounded),
                          const SizedBox(width: 12),
                          _buildInfoBadge(_totalDuration, Icons.timer_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Lista de canciones
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadSongs,
                  color: const Color(0xFFE91E63),
                  child: Container(
                    color: Colors.white,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                        : _songs.isEmpty
                            ? Center(
                                child: Text(
                                  "No hay canciones de este artista",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 25, bottom: 100),
                                itemCount: _songs.length,
                                itemExtent: 68, // Altura fija para scroll ultra suave
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                itemBuilder: (context, index) {
                                  final song = _songs[index];
                                  return RepaintBoundary(
                                    key: ValueKey(song.id),
                                    child: _buildSongItem(song, index, key: ValueKey(song.id)),
                                  );
                                },
                              ),
                  ),
                ),
              ),
            ],
          ),
          
          // Controles Flotantes
          Positioned(
            top: headerHeight.clamp(300.0, 400.0) - 30, 
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 50), 
                
                // Play Button
                GestureDetector(
                  onTap: () {
                    if (isCurrentSongInArtist && isSameContext && _isPlaying) {
                      _audioService.togglePlayPause();
                    } else {
                      _playArtist(0);
                    }
                  },
                  child: Container(
                    width: playButtonSize.clamp(50.0, 60.0),
                    height: playButtonSize.clamp(50.0, 60.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE91E63).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: playButtonSize.clamp(50.0, 60.0) * 0.5,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Sort Mode
                GestureDetector(
                  onTap: () {
                    _cycleSortOrder();
                  },
                  child: Container(
                    width: playButtonSize.clamp(50.0, 60.0) * 0.7,
                    height: playButtonSize.clamp(50.0, 60.0) * 0.7,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE91E63),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.shuffle_rounded,
                      color: Colors.black87,
                      size: playButtonSize.clamp(50.0, 60.0) * 0.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Player
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BottomPlayer(
              audioService: _audioService,
              isPlaying: _isPlaying,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongItem(SongModel song, int index, {Key? key}) {
    bool isCurrentSong = _audioService.currentSong?.id == song.id;
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentSong ? const Color(0xFFE91E63).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 25,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isCurrentSong ? const Color(0xFFE91E63) : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(width: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                artworkWidth: 45,
                artworkHeight: 45,
                artworkQuality: FilterQuality.low,
                keepOldArtwork: true,
                size: 100, // Tamaño optimizado
                nullArtworkWidget: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.music_note, color: Colors.grey[400]),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          song.title,
          style: TextStyle(
            fontSize: 15, 
            fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.w600,
            color: isCurrentSong ? const Color(0xFFE91E63) : const Color(0xFF2C3E50),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  song.album ?? "Desconocido",
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrentSong ? const Color(0xFFE91E63).withOpacity(0.7) : Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${(song.duration ?? 0) ~/ 60000}:${((song.duration ?? 0) ~/ 1000 % 60).toString().padLeft(2, '0')}",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentSong && _isPlaying)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.graphic_eq, color: Color(0xFFE91E63), size: 20),
              ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
              onPressed: () => _showSongOptions(song),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 20,
            ),
          ],
        ),
        onTap: () => _playArtist(index),
        onLongPress: () => _showSongOptions(song),
      ),
    );
  }
}
