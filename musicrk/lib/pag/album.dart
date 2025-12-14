import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart' as app_audio;
import '../services/database_helper.dart';
import 'play.dart';
import '../widgets/bottom_player.dart';
import '../widgets/song_options_sheet.dart';

class AlbumPage extends StatefulWidget {
  final Map<String, dynamic> album;

  const AlbumPage({super.key, required this.album});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final app_audio.AudioService _audioService = app_audio.AudioService();
  List<SongModel> _songs = [];
  bool _isLoading = true;
  String _totalDuration = "";
  bool _isPlaying = false;
  String _sortOrder = 'default'; // default, alphabetic, artist

  @override
  void initState() {
    super.initState();
    _loadSortOrder();
    _loadSongs();
    
    // Listen to playback state
    _audioService.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    
    // Listen to current song changes
    _audioService.currentSongStream.listen((_) {
      if (mounted) setState(() {});
    });
  }
  
  

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    List<SongModel> songs = [];

    try {
      if (widget.album['type'] == 'folder') {
        final folderPath = widget.album['folder_path'] as String;
        final allSongs = await _audioQuery.querySongs(
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );
        songs = allSongs.where((song) => song.data.startsWith(folderPath)).toList();
      } else {
        // Custom album logic
        final songPaths = await DatabaseHelper.instance.getAlbumSongs(widget.album['id']);
        if (songPaths.isNotEmpty) {
          // Query all songs to get details, then filter by path
          // Note: Querying all songs might be slow. Optimization: Query specific paths if possible or cache.
          // For now, we query all and filter, which is safe but maybe not most efficient.
          final allSongs = await _audioQuery.querySongs(
            sortType: SongSortType.TITLE,
            orderType: OrderType.ASC_OR_SMALLER,
            uriType: UriType.EXTERNAL,
            ignoreCase: true,
          );
          
          // Filter songs that match the paths in the album
          songs = allSongs.where((song) => songPaths.contains(song.data)).toList();
        } else {
          songs = [];
        }
      }
    } catch (e) {
      debugPrint("Error loading songs: $e");
    }

    // Apply sorting
    _applySorting(songs);

    // Calculate total duration
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
    final albumKey = 'sort_${widget.album['name']}';
    setState(() {
      _sortOrder = prefs.getString(albumKey) ?? 'default';
    });
  }

  Future<void> _saveSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final albumKey = 'sort_${widget.album['name']}';
    await prefs.setString(albumKey, _sortOrder);
  }

  void _applySorting(List<SongModel> songs) {
    switch (_sortOrder) {
      case 'alphabetic':
        songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'artist':
        songs.sort((a, b) {
          final artistA = a.artist?.toLowerCase() ?? '';
          final artistB = b.artist?.toLowerCase() ?? '';
          return artistA.compareTo(artistB);
        });
        break;
      case 'default':
      default:
        // Keep original order
        break;
    }
  }

  void _cycleSortOrder() {
    setState(() {
      if (_sortOrder == 'default') {
        _sortOrder = 'alphabetic';
      } else if (_sortOrder == 'alphabetic') {
        _sortOrder = 'artist';
      } else {
        _sortOrder = 'default';
      }
    });
    _saveSortOrder();
    _loadSongs();
  }

  void _showSortModeOverlay() {
    String modeText;
    switch (_sortOrder) {
      case 'alphabetic':
        modeText = 'Ordenado Alfabéticamente';
        break;
      case 'artist':
        modeText = 'Ordenado por Artista';
        break;
      default:
        modeText = 'Modo Aleatorio';
    }

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.4,
        left: 50,
        right: 50,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F3D).withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                modeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }


  void _playAlbum([int index = 0]) async {
    if (_songs.isEmpty) return;
    
    // Asegurar que el índice es válido
    if (index < 0 || index >= _songs.length) {
      index = 0;
    }
    
    // Establecer la lista activa del álbum (ya ordenada/shuffled)
    _audioService.setPlaylist(_songs);
    _audioService.setPlaylistContext('album_${widget.album['id']}');
    
    final song = _songs[index];
    
    // Buscar en la lista global
    int globalIndex = _audioService.songs.indexWhere((s) => s.id == song.id);
    
    // Si no está en la lista global, recargar la biblioteca
    if (globalIndex == -1) {
      debugPrint('Canción no encontrada en lista global, recargando biblioteca...');
      await _audioService.reloadLibrary();
      
      // Buscar de nuevo después de recargar
      globalIndex = _audioService.songs.indexWhere((s) => s.id == song.id);
    }
    
    if (globalIndex != -1) {
      await _audioService.playSong(globalIndex);
    } else {
      debugPrint("Canción no encontrada incluso después de recargar");
      // Mostrar mensaje al usuario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No se pudo encontrar la canción. Intenta reiniciar la app.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shuffleSongs() {
    setState(() {
      _songs.shuffle();
    });
    // Actualizar la playlist en AudioService con el nuevo orden
    _audioService.setPlaylist(_songs);
  }

  void _showSongOptions(SongModel song) {
    final isCustomAlbum = widget.album['type'] == 'custom';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SongOptionsSheet(
        song: song,
        onPlay: () {
          final index = _songs.indexOf(song);
          if (index != -1) _playAlbum(index);
        },
        deleteLabel: isCustomAlbum ? "Eliminar del álbum" : null,
        deleteSubtitle: isCustomAlbum ? "Quitar canción de este álbum" : null,
        onDelete: isCustomAlbum ? () async {
           await DatabaseHelper.instance.removeSongFromAlbum(widget.album['id'], song.data);
           _loadSongs(); // Refresh list
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Canción eliminada del álbum")),
             );
           }
        } : null,
      ),
    );
  }

  void _showAlbumOptions() {
    final isCustomAlbum = widget.album['type'] == 'custom';
    final isFolderAlbum = widget.album['type'] == 'folder';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3D),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white10),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              _buildOptionTile(
                icon: Icons.play_arrow_rounded,
                title: "Reproducir Todo",
                onTap: () {
                  Navigator.pop(context);
                  _playAlbum(0);
                },
              ),
              _buildOptionTile(
                icon: Icons.shuffle_rounded,
                title: "Aleatorio",
                onTap: () {
                  Navigator.pop(context);
                  _shuffleSongs();
                  _playAlbum(0);
                },
              ),
              _buildOptionTile(
                icon: Icons.info_outline_rounded,
                title: "Información",
                onTap: () {
                  Navigator.pop(context);
                  _showAlbumInfo();
                },
              ),

              if (isCustomAlbum) ...[
                const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
                _buildOptionTile(
                  icon: Icons.edit_rounded,
                  title: 'Modificar Álbum',
                  onTap: () {
                    Navigator.pop(context);
                    _showRenameAlbumDialog();
                  },
                ),
                _buildOptionTile(
                  icon: Icons.delete_forever_rounded,
                  title: 'Eliminar Álbum',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteAlbumConfirmation(isFolder: false);
                  },
                ),
              ],

              if (isFolderAlbum) ...[
                const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
                _buildOptionTile(
                  icon: Icons.folder_off_rounded,
                  title: 'Desvincular Carpeta',
                  subtitle: 'Solo se elimina de la app',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteAlbumConfirmation(isFolder: true);
                  },
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)) : null,
      onTap: onTap,
    );
  }

  void _showAlbumInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        title: const Text("Información del Álbum", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow("Nombre:", widget.album['name'] ?? "Desconocido"),
            _buildInfoRow("Tipo:", widget.album['type'] == 'folder' ? "Carpeta Local" : "Álbum Personalizado"),
            _buildInfoRow("Canciones:", "${_songs.length}"),
            if (widget.album['type'] == 'folder')
              _buildInfoRow("Ruta:", widget.album['folder_path'] ?? "Desconocida"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar", style: TextStyle(color: Color(0xFFE91E63))),
          ),
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

  void _showRenameAlbumDialog() {
    final controller = TextEditingController(text: widget.album['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        title: const Text("Renombrar Álbum", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Nuevo nombre",
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE91E63))),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await DatabaseHelper.instance.updateAlbum(
                  widget.album['id'],
                  {'name': controller.text},
                );
                
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    widget.album['name'] = controller.text;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Álbum renombrado")),
                  );
                }
              }
            },
            child: const Text("Guardar", style: TextStyle(color: Color(0xFFE91E63))),
          ),
        ],
      ),
    );
  }

  void _showDeleteAlbumConfirmation({required bool isFolder}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        title: Text(isFolder ? "Desvincular Carpeta" : "Eliminar Álbum", style: const TextStyle(color: Colors.white)),
        content: Text(
          isFolder 
            ? "¿Estás seguro de que deseas desvincular esta carpeta? Las canciones NO se borrarán de tu dispositivo."
            : "¿Estás seguro de que deseas eliminar este álbum? Las canciones no se borrarán del dispositivo.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteAlbum(widget.album['id']);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close page
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isFolder ? "Carpeta desvinculada" : "Álbum eliminado")),
                );
              }
            },
            child: Text(isFolder ? "Desvincular" : "Eliminar", style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = _audioService.currentSong;
    final bool isCurrentSongInAlbum = currentSong != null && _songs.any((s) => s.id == currentSong.id);
    final String contextId = 'album_${widget.album['id']}';
    final bool isSameContext = _audioService.playlistContext == contextId;
    final bool showPause = _isPlaying && isCurrentSongInAlbum && isSameContext;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // --- Header ---
              Container(
                height: 380,
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
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              onPressed: _showAlbumOptions,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Album Art
                      Hero(
                        tag: 'album_art_${widget.album['name']}',
                        child: Container(
                          width: 150,
                          height: 150,
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
                            child: _songs.isNotEmpty
                                ? QueryArtworkWidget(
                                    id: _songs.first.id,
                                    type: ArtworkType.AUDIO,
                                    artworkWidth: 150,
                                    artworkHeight: 150,
                                    artworkQuality: FilterQuality.medium,
                                    keepOldArtwork: true,
                                    artworkFit: BoxFit.cover,
                                    size: 300, // Optimized size
                                    nullArtworkWidget: Container(
                                      color: Colors.grey[900],
                                      child: const Icon(Icons.music_note, size: 80, color: Colors.white24),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[900],
                                    child: const Icon(Icons.album, size: 80, color: Colors.white24),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.album['name'] ?? "Álbum Desconocido",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Info Row (Songs | Duration)
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
              // --- List ---
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
                                  "No hay canciones en este álbum",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              )
                            : ReorderableListView.builder(
                              padding: const EdgeInsets.only(top: 30, bottom: 100),
                              itemCount: _songs.length,
                              proxyDecorator: (child, index, animation) {
                                return Material(
                                  elevation: 0,
                                  color: Colors.transparent,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.95),
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: child,
                                  ),
                                );
                              },
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (oldIndex < newIndex) {
                                    newIndex -= 1;
                                  }
                                  final SongModel item = _songs.removeAt(oldIndex);
                                  _songs.insert(newIndex, item);
                                });
                              },
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
          
          // Floating Controls (Play + Shuffle)
          Positioned(
            top: 350,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Dummy spacer to balance the Shuffle button and keep Play centered
                const SizedBox(width: 50), 
                
                // Play Button
                GestureDetector(
                  onTap: () {
                    // Si está reproduciendo Y es del mismo contexto (este álbum), toggle play/pause
                    if (isCurrentSongInAlbum && isSameContext && _isPlaying) {
                      _audioService.togglePlayPause();
                    } else {
                      // Siempre reproducir desde la primera canción
                      _playAlbum(0);
                    }
                  },
                  child: Container(
                    width: 60,
                    height: 60,
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
                      size: 32,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Sort Mode Button (replaces Shuffle)
                GestureDetector(
                  onTap: () {
                    _cycleSortOrder();
                    _showSortModeOverlay();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
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
                    child: const Icon(
                      Icons.shuffle_rounded,
                      color: Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Player (Global)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildBottomPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton() {
    String sortLabel;
    IconData sortIcon;
    
    switch (_sortOrder) {
      case 'alphabetic':
        sortLabel = 'A-Z';
        sortIcon = Icons.sort_by_alpha_rounded;
        break;
      case 'artist':
        sortLabel = 'Artista';
        sortIcon = Icons.person_outline_rounded;
        break;
      default:
        sortLabel = 'Original';
        sortIcon = Icons.list_rounded;
    }

    return GestureDetector(
      onTap: _cycleSortOrder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sortIcon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              sortLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playAlbum(index),
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Song Number
                SizedBox(
                  width: 30,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isCurrentSong ? const Color(0xFFE91E63) : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Album Art with Gradient
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey[200]!,
                        Colors.grey[100]!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        QueryArtworkWidget(
                          id: song.id,
                          type: ArtworkType.AUDIO,
                          artworkWidth: 50,
                          artworkHeight: 50,
                          artworkQuality: FilterQuality.low,
                          keepOldArtwork: true,
                          size: 100, // Optimized size
                          nullArtworkWidget: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey[300]!,
                                  Colors.grey[200]!,
                                ],
                              ),
                            ),
                            child: const Icon(Icons.music_note, color: Colors.grey),
                          ),
                        ),
                        if (isCurrentSong && _isPlaying)
                          Container(
                            color: Colors.black.withOpacity(0.4),
                            child: const Center(
                              child: Icon(Icons.equalizer_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Song Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.w600,
                          color: isCurrentSong ? const Color(0xFFE91E63) : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist ?? "Desconocido",
                        style: TextStyle(
                          fontSize: 13,
                          color: isCurrentSong ? const Color(0xFFE91E63).withOpacity(0.8) : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Duration
                Text(
                  "${(song.duration ?? 0) ~/ 60000}:${((song.duration ?? 0) ~/ 1000 % 60).toString().padLeft(2, '0')}",
                  style: TextStyle(
                    fontSize: 13,
                    color: isCurrentSong ? const Color(0xFFE91E63) : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                // Options Button
                IconButton(
                  icon: Icon(Icons.more_vert_rounded,
                      color: isCurrentSong ? const Color(0xFFE91E63) : Colors.grey[400],
                      size: 22),
                  onPressed: () => _showSongOptions(song),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPlayer() {
    return BottomPlayer(
      audioService: _audioService,
      isPlaying: _isPlaying,
      // No fallback - siempre mostrar la canción actual del AudioService
    );
  }
}
