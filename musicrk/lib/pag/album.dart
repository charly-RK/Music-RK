import 'dart:ui';
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
  String _sortOrder = 'title'; 
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _loadSortOrder();
    _loadSongs();
    
    // Escuchar el estado de reproducción
    _audioService.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    
    // Escuchar los cambios de la canción actual
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
        // Lógica de álbum personalizada
        final songPaths = await DatabaseHelper.instance.getAlbumSongs(widget.album['id']);
        if (songPaths.isNotEmpty) {
          // Consultar todas las canciones para obtener detalles, luego filtrar por ruta
          // Nota: Consultar todas las canciones puede ser lento. Optimización: Consultar rutas específicas si es posible o cachear.
          // Por ahora, consultamos todas y filtramos, lo cual es seguro pero quizás no sea la más eficiente.
          final allSongs = await _audioQuery.querySongs(
            sortType: SongSortType.TITLE,
            orderType: OrderType.ASC_OR_SMALLER,
            uriType: UriType.EXTERNAL,
            ignoreCase: true,
          );
          
          // Filtrar canciones que coincidan con los paths en el álbum
          songs = allSongs.where((song) => songPaths.contains(song.data)).toList();
        } else {
          songs = [];
        }
      }
    } catch (e) {
      debugPrint("Error loading songs: $e");
    }

    // Aplicar ordenamiento
    _applySorting(songs);

    // Calcular la duración total
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
    if (_sortOrder == 'artist') {
      songs.sort((a, b) => (a.artist ?? "").toLowerCase().compareTo((b.artist ?? "").toLowerCase()));
    } else if (_sortOrder == 'album') {
      songs.sort((a, b) => (a.album ?? "").toLowerCase().compareTo((b.album ?? "").toLowerCase()));
    } else {
      // title order
      songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
  }

  void _cycleSortOrder() {
    setState(() {
      if (_sortOrder == 'title') {
        _sortOrder = 'artist';
      } else if (_sortOrder == 'artist') {
        _sortOrder = 'album';
      } else {
        _sortOrder = 'title';
      }
    });
    _saveSortOrder();
    _loadSongs();

    String message = _sortOrder == 'title' 
        ? 'Título' 
        : _sortOrder == 'album' 
            ? 'Álbum' 
            : 'Artista';
            
    _showCustomToast(message, _sortOrder);
  }

  void _showCustomToast(String message, String iconType) {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }

    IconData sortIcon = Icons.sort_by_alpha_rounded;
    if (iconType == 'album') sortIcon = Icons.album_rounded;
    if (iconType == 'artist') sortIcon = Icons.person_rounded;

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
                    color: Colors.black.withOpacity(0.25), // Más transparente
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(sortIcon, color: const Color(0xFFE91E63), size: 18), // Icono más pequeño
                      const SizedBox(width: 8),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5, // Texto más pequeño
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
           _loadSongs(); // Refrescar lista
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
                Navigator.pop(context); // Cerrar diálogo
                Navigator.pop(context); // Cerrar página
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

    // Dimensionamiento responsivo
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final headerHeight = screenHeight * 0.39; 
    final albumArtSize = screenWidth * 0.35; 
    final playButtonSize = screenWidth * 0.16; 

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // --- Encabezado ---
              Container(
                height: headerHeight.clamp(250.0, 350.0), 
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
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 0.0, bottom: 0.0),
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
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                                onPressed: _showAlbumOptions,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // album de arte
                      Hero(
                        tag: 'album_art_${widget.album['name']}',
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
                            child: _songs.isNotEmpty
                                ? QueryArtworkWidget(
                                    id: _songs.first.id,
                                    type: ArtworkType.AUDIO,
                                    artworkWidth: albumArtSize.clamp(100.0, 150.0).toDouble(),
                                    artworkHeight: albumArtSize.clamp(100.0, 150.0).toDouble(),
                                    artworkQuality: FilterQuality.low,
                                    keepOldArtwork: true,
                                    artworkFit: BoxFit.cover,
                                    size: 200, // Tamaño optimizado para memoria
                                    nullArtworkWidget: Container(
                                      color: Colors.grey[900],
                                      child: Icon(Icons.music_note, size: albumArtSize.clamp(100.0, 150.0) * 0.5, color: Colors.white24),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[900],
                                    child: Icon(Icons.album, size: albumArtSize.clamp(100.0, 150.0) * 0.5, color: Colors.white24),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.album['name'] ?? "Álbum Desconocido",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Fila de información (Canciones | Duración)
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
              // --- Lista ---
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
          
          // Controles flotantes (Reproducir + Mezclar)
          Positioned(
            top: headerHeight.clamp(250.0, 350.0) - 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Dummy spacer para balancear el botón de Mezclar y mantener el botón de Reproducir centrado
                const SizedBox(width: 50), 
                
                // Botón de Reproducir
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

                // Botón de Modo de Orden (reemplaza Mezclar)
                GestureDetector(
                  onTap: _cycleSortOrder,
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

          // Bottom Player (Global)
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

  Widget _buildInfoBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          Icon(icon, size: 12, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
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
      case 'title':
        sortLabel = 'A-Z';
        sortIcon = Icons.sort_by_alpha_rounded;
        break;
      case 'artist':
        sortLabel = 'Artista';
        sortIcon = Icons.person_outline_rounded;
        break;
      case 'album':
        sortLabel = 'Álbum';
        sortIcon = Icons.album_rounded;
        break;
      default:
        sortLabel = 'A-Z';
        sortIcon = Icons.sort_by_alpha_rounded;
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
        onTap: () => _playAlbum(index),
        onLongPress: () => _showSongOptions(song),
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
