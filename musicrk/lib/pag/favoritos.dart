import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_service.dart';
import '../services/database_helper.dart';
import 'play.dart';
import 'inicio.dart';
import '../widgets/bottom_player.dart';
import '../widgets/song_options_sheet.dart';
import '../widgets/song_tile.dart';
import '../widgets/custom_dialogs.dart';

class FavoritosPage extends StatefulWidget {
  const FavoritosPage({super.key});

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage> {
  final AudioService _audioService = AudioService();
  List<SongModel> _favoriteSongs = [];
  bool _isLoading = true;
  bool isPlaying = false;
  String currentTitle = "Sin reproducción";
  String currentArtist = "---";

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _setupListeners();
  }

  void _setupListeners() {
    _audioService.playingStream.listen((playing) {
      if (mounted) {
        setState(() {
          isPlaying = playing;
        });
      }
    });

    _audioService.currentSongStream.listen((song) {
      if (mounted && song != null) {
        setState(() {
          currentTitle = song.title;
          currentArtist = song.artist ?? 'Desconocido';
        });
      }
    });
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final favoritesData = await DatabaseHelper.instance.getFavorites();
      final favoriteIds = favoritesData.map((e) => e['song_id'] as int).toSet();
      final allSongs = await _audioService.querySongs(updateList: false);

      setState(() {
        _favoriteSongs = allSongs.where((s) => favoriteIds.contains(s.id)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading favorites: $e");
      setState(() => _isLoading = false);
    }
  }

  void _playAll() {
    if (_favoriteSongs.isEmpty) return;
    
    // Verificamos si ya estamos reproduciendo desde esta lista Y contexto
    final currentSong = _audioService.currentSong;
    final isPlaying = _audioService.player.playing;
    final bool isCurrentSongInList = currentSong != null && _favoriteSongs.any((s) => s.id == currentSong.id);
    final bool isSameContext = _audioService.playlistContext == 'favorites';

    if (isCurrentSongInList && isSameContext) {
      _audioService.togglePlayPause();
    } else {
      // Si la canción está en la lista pero el contexto es diferente, cambia el contexto
      if (isCurrentSongInList) {
         final index = _favoriteSongs.indexWhere((s) => s.id == currentSong!.id);
         if (index != -1) {
           _playSong(index);
           return;
         }
      }
      _playSong(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Encabezado con gradiente
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1F3D), Color(0xFF2A2948)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Barra de navegación personalizada
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 12),
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
                      const Expanded(
                        child: Text(
                          "Favoritos",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFE91E63),
                            size: 20,
                          ),
                          onPressed: () {}, // Decorativo o con acción futura
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                  // Insignia de cantidad de canciones
                if (!_isLoading && _favoriteSongs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "${_favoriteSongs.length} ${_favoriteSongs.length == 1 ? 'canción' : 'canciones'}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Botón Reproducir todo
                        GestureDetector(
                          onTap: _playAll,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E63),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE91E63).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isPlaying ? "Pausar" : "Reproducir",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Contenido
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                        : _favoriteSongs.isEmpty
                            ? RefreshIndicator(
                                color: const Color(0xFFE91E63),
                                onRefresh: _loadFavorites,
                                child: ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.favorite_border_rounded, size: 80, color: Colors.grey[300]),
                                          const SizedBox(height: 16),
                                          Text(
                                            "No tienes favoritos aún",
                                            style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Mantén presionada una canción para agregarla",
                                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                color: const Color(0xFFE91E63),
                                onRefresh: _loadFavorites,
                                child: ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(top: 20, bottom: 100),
                                  itemCount: _favoriteSongs.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 0),
                                  itemBuilder: (context, index) {
                                    final song = _favoriteSongs[index];
                                    final bool isCurrentSong = _audioService.currentSong?.id == song.id;
                                    
                                    return RepaintBoundary(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // Reducido para encajar con itemExtent
                                        decoration: BoxDecoration(
                                          color: Colors.transparent, // Fondo manejado por la hoja
                                          borderRadius: BorderRadius.circular(12),
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
                                                    song.artist ?? "Desconocido",
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
                                              if (isCurrentSong && isPlaying)
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
                                          onTap: () => _playSong(index),
                                          onLongPress: () => _showSongOptions(song),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ),
                ),
              ],
            ),
          ),

          // Reproductor inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPlayer(),
          ),
        ],
      ),
    );
  }

  void _playSong(int index) {
    // Establecer la lista de favoritos como playlist activa
    _audioService.setPlaylist(_favoriteSongs);
    _audioService.setPlaylistContext('favorites');
    
    final song = _favoriteSongs[index];
    final globalIndex = _audioService.songs.indexWhere((s) => s.id == song.id);
    if (globalIndex != -1) {
      _audioService.playSong(globalIndex);
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => PlayPage(songIndex: globalIndex),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutQuart;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
    }
  }

  void _showSongOptions(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SongOptionsSheet(
        song: song,
        onRefresh: () => _loadFavorites(),
        isFavorite: true,
        onPlay: () {
          final index = _favoriteSongs.indexOf(song);
          if (index != -1) _playSong(index);
        },
        onAddToFavorites: () async {
          // Lógica para eliminar de favoritos
          await DatabaseHelper.instance.removeFavorite(song.id);
          _loadFavorites();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Eliminado de favoritos',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFE91E63).withOpacity(0.95),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                elevation: 6,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        deleteLabel: "Eliminar de Favoritos",
        deleteSubtitle: "Quitar de tu lista de favoritos",
        onDelete: () async {
          await DatabaseHelper.instance.removeFavorite(song.id);
          _loadFavorites();
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Eliminado de favoritos")),
             );
          }
        },
      ),
    );
  }

  void _showSongInfo(SongModel song) {
    AppDialogs.showCustomDialog(
      context: context,
      title: "Información",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow("Archivo:", song.displayName),
          _buildInfoRow("Artista:", song.artist ?? "Desconocido"),
          _buildInfoRow("Álbum:", song.album ?? "Desconocido"),
          _buildInfoRow("Duración:", _formatDuration(song.duration ?? 0)),
          _buildInfoRow("Tamaño:", "${(song.size / (1024 * 1024)).toStringAsFixed(2)} MB"),
          _buildInfoRow("Ruta:", song.data),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          children: [
            TextSpan(text: "$label ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildBottomPlayer() {
    return StreamBuilder<bool>(
      stream: _audioService.playingStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;
        return BottomPlayer(
          audioService: _audioService,
          isPlaying: isPlaying,
          // No hay fallback - siempre mostrar la canción actual del AudioService
        );
      },
    );
  }
}

