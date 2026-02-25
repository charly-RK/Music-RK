import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart';
import '../services/database_helper.dart';
import '../widgets/bottom_player.dart';
import 'play.dart';
import '../widgets/bottom_player.dart';
import '../widgets/song_options_sheet.dart';

class AllSongsPage extends StatefulWidget {
  const AllSongsPage({super.key});

  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends State<AllSongsPage> {
  final AudioService _audioService = AudioService();
  final TextEditingController _searchController = TextEditingController();
  
  List<SongModel> _allSongs = [];
  List<SongModel> _filteredSongs = [];
  bool _isLoading = true;
  bool _isSearching = false;
  StreamSubscription? _currentSongSubscription;
  StreamSubscription? _playingSubscription;
  Timer? _debounce;
  String _sortOrder = 'album'; // 'titulo', 'album', 'artista'
  OverlayEntry? _overlayEntry;
  int _displayedCount = 100;
  final int _incrementCount = 100;

  @override
  void initState() {
    super.initState();
    _initData();
    _currentSongSubscription = _audioService.currentSongStream.listen((_) {
      if (mounted) setState(() {});
    });
    _playingSubscription = _audioService.playingStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initData() async {
    await _loadSortOrder();
    await _loadSongs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _currentSongSubscription?.cancel();
    _playingSubscription?.cancel();
    _debounce?.cancel();
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    
    // usar canciones cacheadas si están disponibles, si no, consultar
    if (_audioService.songs.isEmpty) {
      await _audioService.querySongs(updateList: true);
    }
    
    if (mounted) {
      setState(() {
        // Crear una copia para evitar modificar la lista global por referencia
        _allSongs = List.from(_audioService.songs);
        _filteredSongs = List.from(_allSongs);
        _applySorting(); // Aplicar orden de clasificación guardado
        _displayedCount = 100; // Resetear paginación
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _sortOrder = prefs.getString('all_songs_sort') ?? 'default';
      });
    }
  }

  Future<void> _saveSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('all_songs_sort', _sortOrder);
  }

  void _applySorting() {
    if (_sortOrder == 'artist') {
      _filteredSongs.sort((a, b) {
        return (a.artist ?? "").toLowerCase().compareTo((b.artist ?? "").toLowerCase());
      });
    } else if (_sortOrder == 'album') {
      _filteredSongs.sort((a, b) {
        return (a.album ?? "").toLowerCase().compareTo((b.album ?? "").toLowerCase());
      });
    } else {
      // orden por título
      _filteredSongs.sort((a, b) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }
  }

  void _filterSongs(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty) {
        setState(() {
          _filteredSongs = List.from(_allSongs);
          _applySorting(); // reaplicar orden de clasificación
          _displayedCount = 100; // Resetear paginación
        });
        return;
      }

      String normalize(String input) {
        return input
            .toLowerCase()
            .replaceAll(RegExp(r'[áàâä]'), 'a')
            .replaceAll(RegExp(r'[éèêë]'), 'e')
            .replaceAll(RegExp(r'[íìîï]'), 'i')
            .replaceAll(RegExp(r'[óòôö]'), 'o')
            .replaceAll(RegExp(r'[úùûü]'), 'u')
            .replaceAll(RegExp(r'[ñ]'), 'n');
      }

      final normalizedQuery = normalize(query);
      
      // Optimizar: usar una lista local para filtrar y evitar múltiples actualizaciones de estado si estuviéramos realizando pasos intermedios
      final filtered = _allSongs.where((song) {
        return normalize(song.title).contains(normalizedQuery) ||
               normalize(song.artist ?? "").contains(normalizedQuery) ||
               normalize(song.album ?? "").contains(normalizedQuery);
      }).toList();

      // Deduplicar canciones por título para evitar mostrar la misma canción varias veces
      final Set<String> seenTitles = {};
      final List<SongModel> uniqueFiltered = [];
      
      for (var song in filtered) {
        // Normalizamos el título (minúsculas y sin espacios extra) para la comparación
        final normalizedTitle = song.title.toLowerCase().trim();
        if (!seenTitles.contains(normalizedTitle)) {
          seenTitles.add(normalizedTitle);
          uniqueFiltered.add(song);
        }
      }

      setState(() {
        _filteredSongs = uniqueFiltered;
        _applySorting(); // reaplicar orden de clasificación a los resultados de la búsqueda
        _displayedCount = 100; // Resetear paginación
      });
    });
  }

  void _cycleSortOrder() {
    setState(() {
      if (_sortOrder == 'title') {
        _sortOrder = 'album';
      } else if (_sortOrder == 'album') {
        _sortOrder = 'artist';
      } else {
        _sortOrder = 'title';
      }
      _applySorting();
    });
    _saveSortOrder();
    
    // Actualizar la lista de reproducción activa en AudioService para que coincida con el nuevo orden de clasificación
    if (_audioService.currentSong != null && _audioService.playlistContext == 'all_songs') {
      _audioService.setPlaylist(_filteredSongs);
    }
    
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

  void _playSong(int index, {bool shuffle = false}) {
    // Establecer la lista filtrada/ordenada actual como la lista de reproducción activa
    _audioService.setPlaylist(_filteredSongs);
    _audioService.setPlaylistContext('all_songs');

    // Encontrar el índice global de la canción para reproducirla correctamente a través de AudioService
    final selectedSong = _filteredSongs[index];
    final globalIndex = _audioService.songs.indexWhere((s) => s.id == selectedSong.id);
    
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
        onPlay: () {
          final index = _filteredSongs.indexOf(song);
          if (index != -1) _playSong(index);
        },
        // onAddToFavorites: usa la lógica predeterminada
        // onInfo: usa la lógica predeterminada
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Fondo personalizado de la barra de aplicaciones
          Container(
            height: 160,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1F3D), Color(0xFF2A2948)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Encabezado
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                      Expanded(
                        child: _isSearching
                            ? TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                decoration: const InputDecoration(
                                  hintText: "Buscar canción...",
                                  hintStyle: TextStyle(color: Colors.white54),
                                  border: InputBorder.none,
                                ),
                                onChanged: _filterSongs,
                              )
                            : const Text(
                                "Canciones",
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
                          icon: Icon(
                            _isSearching ? Icons.close_rounded : Icons.search_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_isSearching) {
                                _isSearching = false;
                                _searchController.clear();
                                _filterSongs("");
                              } else {
                                _isSearching = true;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
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
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _cycleSortOrder,
                        ),
                      ),
                    ],
                  ),
                ),



                // Lista de canciones
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                              : _filteredSongs.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.music_off_rounded, size: 64, color: Colors.grey[300]),
                                          const SizedBox(height: 16),
                                          Text(
                                            "No se encontraron canciones",
                                            style: TextStyle(color: Colors.grey[500], fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    )
                                  : RefreshIndicator(
                                      onRefresh: _loadSongs,
                                      color: const Color(0xFFE91E63),
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                                        child: ListView.builder(
                                          padding: const EdgeInsets.only(top: 10, bottom: 100),
                                          itemCount: (_filteredSongs.length > _displayedCount) 
                                              ? _displayedCount + 1 
                                              : _filteredSongs.length,
                                          itemBuilder: (context, index) {
                                            if (index == _displayedCount) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 20),
                                                child: Center(
                                                  child: TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _displayedCount += _incrementCount;
                                                      });
                                                    },
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: const Color(0xFFE91E63),
                                                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                                      backgroundColor: const Color(0xFFE91E63).withOpacity(0.1),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "Mostrar más (${_filteredSongs.length - _displayedCount} restantes)",
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                            final song = _filteredSongs[index];
                                            return _buildSongItem(song, index);
                                          },
                                        ),
                                      ),
                                    ),
                        ),
                      ],
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
            child: StreamBuilder<bool>(
              stream: _audioService.playingStream,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;
                return BottomPlayer(
                  audioService: _audioService,
                  isPlaying: isPlaying,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongItem(SongModel song, int index) {
    bool isCurrentSong = _audioService.currentSong?.id == song.id;
    bool isPlaying = _audioService.player.playing;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // Margen reducido como en inicio
      decoration: BoxDecoration(
        color: isCurrentSong ? const Color(0xFFE91E63).withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: ClipRRect(
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
            if (isCurrentSong)
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
    );
  }
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isPrimary ? 16 : 12),
            decoration: BoxDecoration(
              color: isPrimary ? const Color(0xFFE91E63) : Colors.grey[200],
              shape: BoxShape.circle,
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE91E63).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ]
                  : [],
              border: isPrimary ? null : Border.all(color: Colors.grey[300]!),
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : const Color(0xFF1A1F3D),
              size: isPrimary ? 32 : 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isPrimary ? const Color(0xFFE91E63) : const Color(0xFF1A1F3D),
              fontSize: 12,
              fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
