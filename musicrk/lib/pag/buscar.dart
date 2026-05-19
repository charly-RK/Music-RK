import 'dart:async';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/download_service.dart';
import '../services/audio_service.dart';
import '../widgets/song_tile.dart';
import 'youtube_album_detail.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/song_options_sheet.dart';

class BuscarPage extends StatefulWidget {
  final VoidCallback? onBackTap;

  const BuscarPage({
    super.key,
    this.onBackTap,
  });

  @override
  State<BuscarPage> createState() => _BuscarPageState();
}

class _BuscarPageState extends State<BuscarPage> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final DownloadService _downloadService = DownloadService();
  final AudioService _audioService = AudioService();
  
  List<SongModel> _localResults = [];
  List<VideoResult> _searchResults = [];
  List<AlbumResult> _albumResults = [];
  
  bool _isLoading = false;
  Timer? _debounce;
  final Set<String> _downloadingIds = {};
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _downloadService.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    
    // Búsqueda local instantánea
    if (query.isNotEmpty) {
      setState(() {
        _localResults = _audioService.searchLocalSongs(query);
      });
    } else {
      setState(() {
        _localResults = [];
      });
    }

    // Búsqueda en YouTube con debounce (esperar a que el usuario deje de escribir)
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.length > 2) {
        _performOnlineSearch(query);
      }
    });
  }

  List<VideoResult> _sortSearchVideos(List<VideoResult> videos) {
    final sortedVideos = List<VideoResult>.from(videos);
    sortedVideos.sort((a, b) {
      final titleA = a.title.toLowerCase();
      final titleB = b.title.toLowerCase();
      
      int scoreA = 0;
      int scoreB = 0;
      
      // Keywords that indicate clean audio/lyrics
      final cleanKeywords = ['letra', 'lyric', 'lyrics', 'audio', 'visualizer', 'audio oficial', 'official audio'];
      for (var kw in cleanKeywords) {
        if (titleA.contains(kw)) scoreA += 10;
        if (titleB.contains(kw)) scoreB += 10;
      }
      
      // Keywords that indicate official video (often with dialogues / filler)
      final officialKeywords = ['video oficial', 'official video', 'music video', 'videoclip', 'video clip', 'official music video'];
      for (var kw in officialKeywords) {
        if (titleA.contains(kw)) scoreA -= 10;
        if (titleB.contains(kw)) scoreB -= 10;
      }
      
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // higher score comes first
      }
      return 0;
    });
    return sortedVideos;
  }

  Future<void> _performOnlineSearch(String query) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Buscar canciones y álbumes en paralelo
      final results = await Future.wait([
        _downloadService.searchVideos(query),
        _downloadService.searchAlbums(query),
      ]);

      if (mounted) {
        setState(() {
          final rawVideos = results[0] as List<VideoResult>;
          _searchResults = _sortSearchVideos(rawVideos);
          _albumResults = results[1] as List<AlbumResult>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadSong(VideoResult video) async {
    setState(() {
      _downloadingIds.add(video.id);
    });

    AppDialogs.showToast(context, 'Iniciando descarga: ${video.title}');

    _downloadService.downloadAndConvertToMp3Async(video);
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(video.id);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // --- Custom Search Header ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1F3D), Color(0xFF2C3E50)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      onPressed: () {
                        if (widget.onBackTap != null) {
                          widget.onBackTap!();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: "Buscar música ...",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty 
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFE91E63),
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  unselectedLabelColor: Colors.white54,
                  tabs: const [
                    Tab(text: "Canciones"),
                    Tab(text: "Álbumes Online"),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSongsTab(),
                _buildAlbumsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsTab() {
    if (_searchController.text.isEmpty) {
      return _buildEmptyState("Escribe para buscar música");
    }

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFFE91E63)),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text("No se encontraron resultados", style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildOnlineSongTile(_searchResults[index]);
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE91E63)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineSongTile(VideoResult video) {
    final isDownloading = _downloadingIds.contains(video.id);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            video.thumbnail,
            width: 55,
            height: 55,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 55, height: 55, color: Colors.grey[200],
              child: const Icon(Icons.music_note, color: Colors.grey),
            ),
          ),
        ),
        title: Text(
          video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          video.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: isDownloading
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              icon: const Icon(Icons.download_for_offline_rounded, color: Color(0xFFE91E63)),
              onPressed: () => _downloadSong(video),
            ),
      ),
    );
  }

  Widget _buildAlbumsTab() {
    if (_searchController.text.isEmpty) {
      return _buildEmptyState("Busca álbumes oficiales");
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
    }

    if (_albumResults.isEmpty) {
      return const Center(child: Text("No se encontraron álbumes", style: TextStyle(color: Colors.grey)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _albumResults.length,
      itemBuilder: (context, index) {
        final album = _albumResults[index];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => YoutubeAlbumDetailPage(album: album)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      album.thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.album, size: 50)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                album.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
