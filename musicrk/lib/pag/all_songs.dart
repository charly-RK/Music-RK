import 'dart:async';
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
  String _sortOrder = 'title'; // title, date, artist
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
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    
    // Use cached songs if available, otherwise query
    if (_audioService.songs.isEmpty) {
      await _audioService.querySongs(updateList: true);
    }
    
    if (mounted) {
      setState(() {
        // Create a copy to avoid modifying the global list by reference
        _allSongs = List.from(_audioService.songs);
        _filteredSongs = List.from(_allSongs);
        _applySorting(); // Apply saved sort order
        _displayedCount = 100; // Reset pagination
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
    } else if (_sortOrder == 'date') {
      _filteredSongs.sort((a, b) {
        return (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0);
      });
    } else {
      // Title order
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
          _applySorting(); // Re-apply sort order
          _displayedCount = 100; // Reset pagination
        });
        return;
      }

      final lowerQuery = query.toLowerCase();
      // Optimize: Use a local list for filtering to avoid multiple state updates if we were doing intermediate steps
      final filtered = _allSongs.where((song) {
        return song.title.toLowerCase().contains(lowerQuery) ||
               (song.artist?.toLowerCase().contains(lowerQuery) ?? false) ||
               (song.album?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();

      setState(() {
        _filteredSongs = filtered;
        _applySorting(); // Re-apply sort order to search results
        _displayedCount = 100; // Reset pagination
      });
    });
  }

  void _cycleSortOrder() {
    setState(() {
      if (_sortOrder == 'title') {
        _sortOrder = 'date';
      } else if (_sortOrder == 'date') {
        _sortOrder = 'artist';
      } else {
        _sortOrder = 'title';
      }
      _applySorting();
    });
    _saveSortOrder();
    
    // Update the active playlist in AudioService to match the new sort order
    if (_audioService.currentSong != null && _audioService.playlistContext == 'all_songs') {
      _audioService.setPlaylist(_filteredSongs);
    }
    
    String message = _sortOrder == 'title' 
        ? 'Ordenado por Título' 
        : _sortOrder == 'date' 
            ? 'Ordenado por Fecha' 
            : 'Ordenado por Artista';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF1A1F3D),
      ),
    );
  }

  void _playSong(int index, {bool shuffle = false}) {
    // Set the current filtered/sorted list as the active playlist
    _audioService.setPlaylist(_filteredSongs);
    _audioService.setPlaylistContext('all_songs');

    // Find the global index of the song to play it correctly via AudioService
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
        // onAddToFavorites: uses default logic
        // onInfo: uses default logic
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Custom App Bar Background
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
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
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
                                "Todas las canciones",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isSearching ? Icons.close : Icons.search,
                          color: Colors.white,
                          size: 26,
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
                      IconButton(
                        icon: const Icon(
                          Icons.sort_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: _cycleSortOrder,
                      ),
                    ],
                  ),
                ),



                // Song List
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
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
          
          // Bottom Player
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentSong ? const Color(0xFFE91E63).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playSong(index),
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
                // Artwork
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
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
                          artworkFit: BoxFit.cover,
                          artworkWidth: 50,
                          artworkHeight: 50,
                          artworkQuality: FilterQuality.low,
                          keepOldArtwork: true,
                          size: 100, // Optimized size
                          nullArtworkWidget: const Icon(Icons.music_note_rounded, color: Colors.grey),
                        ),
                        if (isCurrentSong && isPlaying)
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
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                          color: isCurrentSong ? const Color(0xFFE91E63) : const Color(0xFF1A1F3D),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist ?? "Desconocido",
                        style: TextStyle(
                          color: isCurrentSong ? const Color(0xFFE91E63).withOpacity(0.8) : Colors.grey[600],
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
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

                // Menu Button
                IconButton(
                  icon: Icon(Icons.more_vert_rounded, 
                    color: isCurrentSong ? const Color(0xFFE91E63) : Colors.grey[400],
                    size: 22
                  ),
                  onPressed: () => _showSongOptions(song),
                ),
              ],
            ),
          ),
        ),
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
