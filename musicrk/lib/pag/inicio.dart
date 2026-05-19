import 'dart:typed_data';
import 'dart:ui';
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
import 'all_songs.dart';
import '../widgets/song_options_sheet.dart';
import '../widgets/song_tile.dart';
import 'notificaciones.dart';
import 'artist.dart';
import '../widgets/custom_dialogs.dart';
import 'playlists.dart';

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
  bool _showAllArtists = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    final granted = await _permissionService.hasStoragePermission();
    if (mounted) setState(() => _permissionGranted = granted);

    await _loadFeaturedAlbums();

    try {
      final initialArtists = await _audioQuery.queryArtists(
        sortType: ArtistSortType.NUM_OF_TRACKS,
        orderType: OrderType.DESC_OR_GREATER,
      );

      Map<String, ArtistModel> groupedArtists = {};
      for (var artist in initialArtists) {
        String rawName = artist.artist;
        String mainName = rawName.split(RegExp(r'\s*(feat\.?|ft\.?|,|&|\+)\s*', caseSensitive: false)).first.trim();
        if (mainName.isEmpty || mainName == '<unknown>') mainName = 'Desconocido';
        String key = mainName.toLowerCase();

        if (groupedArtists.containsKey(key)) {
            ArtistModel existing = groupedArtists[key]!;
            Map<String, dynamic> mergedData = Map<String, dynamic>.from(existing.getMap);
            mergedData['_id'] = existing.id; 
            mergedData['artist'] = existing.artist; 
            mergedData['number_of_tracks'] = (existing.numberOfTracks ?? 0) + (artist.numberOfTracks ?? 0);
            mergedData['number_of_albums'] = (existing.numberOfAlbums ?? 0) + (artist.numberOfAlbums ?? 0);
            groupedArtists[key] = ArtistModel(mergedData);
        } else {
            Map<String, dynamic> newData = Map<String, dynamic>.from(artist.getMap);
            newData['artist'] = mainName;
            groupedArtists[key] = ArtistModel(newData);
        }
      }

      final List<ArtistModel> artists = groupedArtists.values.toList();
      artists.sort((a, b) => (b.numberOfTracks ?? 0).compareTo(a.numberOfTracks ?? 0));

      if (mounted) setState(() => _artists = artists);
    } catch (e) {
      debugPrint("Error loading artists: $e");
    }

    if (granted) {
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

      _audioService.playingStream.listen((playing) {
        if (mounted) setState(() => isPlaying = playing);
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
      if (mounted) setState(() => _isLoading = false);
    }

    DatabaseHelper.instance.albumsStream.listen((_) => _loadFeaturedAlbums());
    DatabaseHelper.instance.playlistsStream.listen((_) => _loadFeaturedAlbums());
  }

  Future<void> _loadFeaturedAlbums() async {
    try {
      final albums = await DatabaseHelper.instance.getAllAlbums();
      if (albums.isEmpty || !mounted) return;
      
      final albumsWithCount = <Map<String, dynamic>>[];
      for (var album in albums.take(2)) {
        final albumCopy = Map<String, dynamic>.from(album);
        int songCount = 0;
        if (album['type'] == 'folder') {
          final folderPath = album['folder_path'] as String;
          songCount = _audioService.songs.where((song) => song.data.startsWith(folderPath)).length;
        } else {
          final songPaths = await DatabaseHelper.instance.getAlbumSongs(album['id']);
          songCount = songPaths.length;
        }
        albumCopy['song_count'] = songCount;
        albumsWithCount.add(albumCopy);
      }
      setState(() => _featuredAlbums = albumsWithCount);
    } catch (e) {
      debugPrint("Error cargando álbumes: $e");
    }
  }

  void _playRecentSong(SongModel song) {
    if (_audioService.playlistContext != 'recent_songs') {
      _audioService.setPlaylist(_recentSongs);
      _audioService.setPlaylistContext('recent_songs');
    }
    final index = _audioService.songs.indexWhere((s) => s.id == song.id);
    if (index != -1) {
      _audioService.playSong(index);
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayPage(songIndex: index)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFE91E63))));
    }

    if (!_permissionGranted) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1F3D),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.library_music_rounded, size: 80, color: Color(0xFFE91E63)),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Acceso a tu Música',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'MusicRK necesita permiso para acceder a tus archivos de audio y mostrarte tu biblioteca musical local.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _permissionService.requestInitialPermissions();
                        final granted = await _permissionService.hasStoragePermission();
                        if (mounted) {
                          setState(() => _permissionGranted = granted);
                          if (granted) _initializeApp();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Conceder Permiso', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => _permissionService.openSettings(),
                    child: Text(
                      'Configuración del sistema',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
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
            height: isTablet ? 300 : 220,
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
                      IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
                      const Text("MusicRK", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      _buildNotificationBadge(),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      child: RefreshIndicator(
                        onRefresh: _initializeApp,
                        color: const Color(0xFFE91E63),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(top: 20, bottom: _audioService.currentSong != null ? 120 : 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildQuickAccess(isTablet),
                              const SizedBox(height: 35),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("Álbumes Destacados", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                              const SizedBox(height: 16),
                              _buildFeaturedAlbumsSection(isTablet),
                              const SizedBox(height: 35),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("Artistas", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                              const SizedBox(height: 16),
                              _buildArtistsSection(isTablet),
                              const SizedBox(height: 35),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("Recientes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                              const SizedBox(height: 16),
                              _buildRecentSongsList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomPlayer()),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge() {
    return StreamBuilder<void>(
      stream: DatabaseHelper.instance.notificationsStream,
      builder: (context, snapshot) {
        return FutureBuilder<int>(
          future: DatabaseHelper.instance.getUnreadNotificationsCount(),
          builder: (context, countSnapshot) {
            final unreadCount = countSnapshot.data ?? 0;
            return Stack(
              children: [
                IconButton(icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesPage()))),
                if (unreadCount > 0)
                  Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFE91E63), shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 18, minHeight: 18), child: Text(unreadCount > 9 ? '9+' : '$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickAccess(bool isTablet) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _buildQuickAccessItem(Icons.favorite_rounded, "Favoritos", const Color(0xFFE91E63), isTablet, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritosPage()))),
          _buildQuickAccessItem(Icons.library_music_rounded, "Bibliotecas", const Color(0xFF2196F3), isTablet, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryPage()))),
          _buildQuickAccessItem(Icons.folder_copy_rounded, "Todos", const Color(0xFF4CAF50), isTablet, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllSongsPage()))),
          _buildQuickAccessItem(Icons.queue_music_rounded, "Playlists", const Color(0xFFFF9800), isTablet, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaylistsPage()))),
        ],
      ),
    );
  }

  Widget _buildQuickAccessItem(IconData icon, String label, Color color, bool isTablet, VoidCallback onTap) {
    final double itemWidth = isTablet ? 140 : MediaQuery.of(context).size.width / 4 - 5;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: itemWidth,
        child: Column(
          children: [
            Container(padding: EdgeInsets.all(isTablet ? 20 : 16), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: isTablet ? 32 : 28)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedAlbumsSection(bool isTablet) {
    final double cardHeight = isTablet ? 220 : 160;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _featuredAlbums.isNotEmpty ? _buildAlbumCard(_featuredAlbums[0], cardHeight) : _buildPlaceholderCard("MúsicaRK", cardHeight)),
          const SizedBox(width: 16),
          Expanded(child: _featuredAlbums.length > 1 ? _buildAlbumCard(_featuredAlbums[1], cardHeight) : _buildPlaceholderCard("Explorar", cardHeight)),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard(String title, double height) {
    return _buildAlbumCard({'name': title, 'song_count': 0}, height);
  }

  Widget _buildAlbumCard(Map<String, dynamic> album, double height) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlbumPage(album: album))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/imagenes/carpeta_2.jpg', fit: BoxFit.cover),
              Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)], stops: const [0.5, 1.0]))),
              Positioned(bottom: 12, left: 12, right: 40, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(album['name'] ?? 'Album', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), Text("${album['song_count'] ?? 0} canciones", style: TextStyle(color: Colors.white70, fontSize: 12))])),
              Positioned(bottom: 12, right: 12, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFFE91E63), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtistsSection(bool isTablet) {
    if (_artists.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: isTablet ? 150 : 130,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _artists.length > 10 ? 11 : _artists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          if (index == 10) return _buildSeeMoreArtists();
          final artist = _artists[index];
          return RepaintBoundary(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistPage(artist: artist))),
              child: Column(
                children: [
                  Container(
                    width: isTablet ? 90 : 75,
                    height: isTablet ? 90 : 75,
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))]),
                    child: ClipOval(child: QueryArtworkWidget(id: artist.id, type: ArtworkType.ARTIST, nullArtworkWidget: Container(color: Colors.grey[200], child: Icon(Icons.person_rounded, size: isTablet ? 45 : 35, color: Colors.grey[400])))),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(width: isTablet ? 100 : 80, child: Text(artist.artist, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeeMoreArtists() {
    return Column(
      children: [
        Container(width: 75, height: 75, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: const Color(0xFFE91E63).withOpacity(0.3))), child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFE91E63), size: 20)),
        const SizedBox(height: 8),
        const Text("Ver todos", style: TextStyle(fontSize: 12, color: Color(0xFFE91E63))),
      ],
    );
  }

  Widget _buildRecentSongsList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _recentSongs.length > 8 ? 8 : _recentSongs.length,
      itemBuilder: (context, index) {
        final song = _recentSongs[index];
        return RepaintBoundary(
          child: SongTile(
            song: song,
            audioService: _audioService,
            isCurrentSong: _audioService.currentSong?.id == song.id,
            onTap: () => _playRecentSong(song),
            onPlayTap: () => _playRecentSong(song),
            onLongPress: () => _showSongOptions(song),
            onOptionTap: () => _showSongOptions(song),
          ),
        );
      },
    );
  }

  Widget _buildBottomPlayer() {
    if (_audioService.currentSong == null && _songs.isEmpty) return const SizedBox.shrink();
    return BottomPlayer(audioService: _audioService, isPlaying: isPlaying, fallbackSong: _songs.isNotEmpty ? _songs.first : null);
  }

  void _showSongOptions(SongModel song) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      isScrollControlled: true, 
      builder: (context) => SongOptionsSheet(
        song: song,
        onRefresh: () => _initializeApp(),
      )
    );
  }
}
