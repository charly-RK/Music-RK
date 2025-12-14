import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'side/drawer_menu.dart'; 
import 'album.dart'; 
import 'play.dart';
import '../services/audio_service.dart';
import '../services/permission_service.dart';
import 'config_page.dart';
import '../services/database_helper.dart';
import '../widgets/bottom_player.dart';
import 'favoritos.dart';
import 'bibliotecas.dart';
import 'bibliotecas.dart';
import 'all_songs.dart';
import '../widgets/song_options_sheet.dart';
import '../widgets/song_tile.dart';
import 'notificaciones.dart';

class Inicio extends StatefulWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onLibraryTap;

  const Inicio({
    super.key,
    this.onSearchTap,
    this.onLibraryTap,
  });

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> with AutomaticKeepAliveClientMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AudioService _audioService = AudioService();
  final PermissionService _permissionService = PermissionService();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  
  bool isPlaying = false;
  String currentTitle = "Desconocido";
  String currentArtist = "Desconocido";

  List<SongModel> _songs = [];
  List<SongModel> _filteredSongs = [];
  List<SongModel> _recentSongs = [];
  List<ArtistModel> _artists = [];
  List<Map<String, dynamic>> _featuredAlbums = [];
  bool _permissionGranted = false;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Request permissions
    final granted = await _permissionService.requestStoragePermission();
    
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
      });
    }

    // Load featured albums
    await _loadFeaturedAlbums();

    // Load artists
    try {
      final artists = await _audioQuery.queryArtists(
        sortType: ArtistSortType.NUM_OF_TRACKS,
        orderType: OrderType.DESC_OR_GREATER,
      );
      if (mounted) {
        setState(() {
          _artists = artists;
        });
      }
    } catch (e) {
      debugPrint("Error loading artists: $e");
    }

    if (granted) {
      // Load songs sorted by date added (newest first)
      final songs = await _audioService.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
      );
      if (mounted) {
        setState(() {
          _songs = songs;
          _filteredSongs = songs;
          _recentSongs = songs.take(10).toList();
          _isLoading = false;
        });
      }

      // Listen to audio service state
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
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    // Listen for album changes
    DatabaseHelper.instance.albumsStream.listen((_) {
      _loadFeaturedAlbums();
    });
  }

  Future<void> _loadFeaturedAlbums() async {
    try {
      final albums = await DatabaseHelper.instance.getAllAlbums();
      
      if (albums.isEmpty || !mounted) return;
      
      // Create mutable copies and get song count for each album
      final albumsWithCount = <Map<String, dynamic>>[];
      
      for (var album in albums.take(2)) {
        // Create a mutable copy of the album map
        final albumCopy = Map<String, dynamic>.from(album);
        
        int songCount = 0;
        
        if (album['type'] == 'folder') {
          // For folder albums, query songs from filesystem
          final folderPath = album['folder_path'] as String;
          final allSongs = await _audioQuery.querySongs(
            sortType: SongSortType.TITLE,
            orderType: OrderType.ASC_OR_SMALLER,
            uriType: UriType.EXTERNAL,
          );
          songCount = allSongs.where((song) => song.data.startsWith(folderPath)).length;
        } else {
          // For custom albums, get songs from database
          final songPaths = await DatabaseHelper.instance.getAlbumSongs(album['id']);
          songCount = songPaths.length;
        }
        
        albumCopy['song_count'] = songCount;
        albumsWithCount.add(albumCopy);
      }
      
      setState(() {
        _featuredAlbums = albumsWithCount;
      });
    } catch (e) {
      debugPrint("Error cargando álbumes: $e");
    }
  }

  void _playRecentSong(SongModel song) {
    // Set playlist to recent songs if not already
    if (_audioService.playlistContext != 'recent_songs') {
      _audioService.setPlaylist(_recentSongs);
      _audioService.setPlaylistContext('recent_songs');
    }
    
    final index = _audioService.songs.indexWhere((s) => s.id == song.id);
    if (index != -1) {
      _audioService.playSong(index);
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => PlayPage(songIndex: index),
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

  void selectSong(int index) {
    // Get the actual song from the filtered list
    final selectedSong = _filteredSongs[index];
    
    // Find the index in the main list (which AudioService uses)
    final realIndex = _audioService.songs.indexWhere((s) => s.id == selectedSong.id);
    
    if (realIndex == -1) return;

    // Limpiar playlist para reproducir todas las canciones
    _audioService.clearPlaylist();

    // Si es la misma canción Y ya está cargada (aunque esté pausada), solo navegar
    if (_audioService.currentIndex == realIndex && _audioService.isSongLoaded) {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => PlayPage(songIndex: realIndex),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutQuart;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
      return;
    }
    
    // Si es diferente o no está cargada, reproducir
    _audioService.playSong(realIndex);
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => PlayPage(songIndex: realIndex),
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

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSongs = List.from(_songs);
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredSongs = _songs.where((song) {
          return song.title.toLowerCase().contains(lowerQuery) ||
                 (song.artist?.toLowerCase().contains(lowerQuery) ?? false) ||
                 (song.album?.toLowerCase().contains(lowerQuery) ?? false);
        }).toList();
      }
    });
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (!_permissionGranted) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Se requieren permisos de almacenamiento',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Para reproducir música desde tu dispositivo'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await _permissionService.openSettings();
                },
                child: const Text('Abrir Configuración'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: const CustomDrawer(),
      body: Stack(
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1F3D), Color(0xFF2A2948)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                      const Text(
                        "MusicRK",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      StreamBuilder<void>(
                        stream: DatabaseHelper.instance.notificationsStream,
                        builder: (context, snapshot) {
                          return FutureBuilder<int>(
                            future: DatabaseHelper.instance.getUnreadNotificationsCount(),
                            builder: (context, countSnapshot) {
                              final unreadCount = countSnapshot.data ?? 0;
                              
                              return Stack(
                                children: [
                                  IconButton(
                                    key: const ValueKey('notification_icon_button'),
                                    icon: const Icon(Icons.notifications_none, color: Colors.white),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const NotificacionesPage()),
                                      );
                                    },
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE91E63),
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Text(
                                          unreadCount > 9 ? '9+' : '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: RefreshIndicator(
                      onRefresh: _initializeApp,
                      color: const Color(0xFFE91E63),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 20, bottom: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildQuickAccess(context),
                            const SizedBox(height: 30),
                            
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                "Álbumes Destacados",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildFeaturedAlbums(context),
                            ),
                            
                            const SizedBox(height: 30),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                "Artistas",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildArtistsSection(),
                            
                            const SizedBox(height: 30),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                "Recientemente Agregados",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Horizontal Song List
                            SizedBox(
                              height: 180,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                scrollDirection: Axis.horizontal,
                                itemCount: _recentSongs.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  return RepaintBoundary(
                                    child: _buildHorizontalSongCard(_recentSongs[index], index),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Player positioned at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPlayer(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedAlbums(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _featuredAlbums.isNotEmpty
              ? _buildAlbumCard(context, _featuredAlbums[0])
              : _buildPlaceholderCard(context, "Ejemplo 1", "Artista 1", 1),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _featuredAlbums.length > 1
              ? _buildAlbumCard(context, _featuredAlbums[1])
              : _buildPlaceholderCard(context, "Ejemplo 2", "Artista 2", 2),
        ),
      ],
    );
  }

  Widget _buildPlaceholderCard(BuildContext context, String title, String artist, int id) {
    return _buildAlbumCard(context, {
      'name': title,
      'artist': artist,
      'image_path': "https://picsum.photos/seed/$id/400",
      'type': 'custom',
      'songs': [],
      'song_count': 0,
    });
  }

  Widget _buildAlbumCard(BuildContext context, Map<String, dynamic> album) {
    String name = album['name'];
    int songCount = album['song_count'] ?? 0;
    String imageUrl = album['image_path'] ?? "https://picsum.photos/seed/${album['id'] ?? name.hashCode}/400";

    return GestureDetector(
      onTap: () {
         Navigator.push(context, MaterialPageRoute(builder: (_) => AlbumPage(album: album)));
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.album, color: Colors.white24, size: 40),
                  );
                },
              ),
            ),
          ),
          // Gradient overlay for text visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),
          // Album name and song count
          Positioned(
            bottom: 8,
            left: 8,
            right: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "$songCount ${songCount == 1 ? 'canción' : 'canciones'}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Play button
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFE91E63).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3))
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccess(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildQuickAccessItem(
          context,
          icon: Icons.favorite_rounded,
          label: "Favoritos",
          color: const Color(0xFFE91E63),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritosPage())),
        ),
        _buildQuickAccessItem(
          context,
          icon: Icons.library_music_rounded,
          label: "Bibliotecas",
          color: const Color(0xFF2196F3),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryPage())),
        ),
        _buildQuickAccessItem(
          context,
          icon: Icons.folder_copy_rounded,
          label: "Todos",
          color: const Color(0xFF4CAF50),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllSongsPage())),
        ),
        _buildQuickAccessItem(
          context,
          icon: Icons.history_rounded,
          label: "Historial",
          color: const Color(0xFFFF9800),
          onTap: () {
             // TODO: Implement History Page
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Próximamente")));
          },
        ),
      ],
    );
  }

  Widget _buildQuickAccessItem(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistsSection() {
    if (_artists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text("No se encontraron artistas", style: TextStyle(color: Colors.grey)),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _artists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final artist = _artists[index];
          return RepaintBoundary(
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: QueryArtworkWidget(
                      id: artist.id,
                      type: ArtworkType.ARTIST,
                      artworkFit: BoxFit.cover,
                      size: 200,
                      quality: 80,
                      nullArtworkWidget: Icon(Icons.person, size: 35, color: Colors.grey[400]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 80,
                  child: Text(
                    artist.artist,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalSongCard(SongModel song, int index) {
    return GestureDetector(
      onTap: () => _playRecentSong(song),
      onLongPress: () => _showSongOptions(song),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: QueryArtworkWidget(
                  id: song.id,
                  type: ArtworkType.AUDIO,
                  artworkWidth: double.infinity,
                  artworkHeight: double.infinity,
                  artworkFit: BoxFit.cover,
                  size: 300, // Optimized size
                  quality: 80,
                  nullArtworkWidget: Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.music_note, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist ?? "Desconocido",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPlayer(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _audioService.playingStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;
        return BottomPlayer(
          audioService: _audioService,
          isPlaying: isPlaying,
        );
      },
    );
  }

  void _showSongOptions(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SongOptionsSheet(
        song: song,
        onPlay: () {
          // Find index in filtered list
          final index = _filteredSongs.indexOf(song);
          if (index != -1) selectSong(index);
        },
      ),
    );
  }
}

class BottomPlayerArt extends StatefulWidget {
  final int songId;
  final AudioService audioService;

  const BottomPlayerArt({
    super.key,
    required this.songId,
    required this.audioService,
  });

  @override
  State<BottomPlayerArt> createState() => _BottomPlayerArtState();
}

class _BottomPlayerArtState extends State<BottomPlayerArt> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: QueryArtworkWidget(
        id: widget.songId,
        type: ArtworkType.AUDIO,
        artworkWidth: 52,
        artworkHeight: 52,
        artworkQuality: FilterQuality.low,
        keepOldArtwork: true,
        artworkFit: BoxFit.cover,
        size: 100, // Optimized size
        nullArtworkWidget: Container(
          width: 52,
          height: 52,
          color: Colors.grey.shade800,
          child: const Icon(Icons.music_note, color: Colors.white),
        ),
      ),
    );
  }
}
