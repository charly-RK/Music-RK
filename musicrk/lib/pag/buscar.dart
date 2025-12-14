import 'package:flutter/material.dart';
import '../services/download_service.dart';
import 'youtube_album_detail.dart';

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
  List<VideoResult> _searchResults = [];
  List<AlbumResult> _albumResults = [];
  bool _isLoading = false;
  final Set<String> _downloadingIds = {};
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _downloadService.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _searchResults = [];
      _albumResults = [];
    });

    // Buscar canciones y álbumes en paralelo
    final results = await Future.wait([
      _downloadService.searchVideos(query),
      _downloadService.searchAlbums(query),
    ]);

    if (mounted) {
      setState(() {
        _searchResults = results[0] as List<VideoResult>;
        _albumResults = results[1] as List<AlbumResult>;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadSong(VideoResult video) async {
    setState(() {
      _downloadingIds.add(video.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Iniciando descarga de "${video.title}"...')),
    );

    // Execute download in background without blocking UI
    _downloadService.downloadAndConvertToMp3Async(video);
    
    // Remove from downloading list after a short delay (notification will handle the rest)
    Future.delayed(const Duration(seconds: 2), () {
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // --- Encabezado Estilo Inicio ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1F3D), // Azul Oscuro
                  Color(0xFF2D3450), // Un poco más claro
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior con Botón Atrás y Título
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () {
                        if (widget.onBackTap != null) {
                          widget.onBackTap!();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Buscar",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Buscar canción o álbum en YouTube...",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: Colors.white54),
                    ),
                    onSubmitted: _search,
                  ),
                ),

                const SizedBox(height: 20),

                // Tabs
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFE91E63),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: const [
                    Tab(text: "Canciones"),
                    Tab(text: "Álbumes"),
                  ],
                ),
              ],
            ),
          ),
          
          // --- TabBarView con Resultados ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab de Canciones
                      _buildSongsTab(),
                      // Tab de Álbumes
                      _buildAlbumsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsTab() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          "Busca canciones en YouTube",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final video = _searchResults[index];
        final isDownloading = _downloadingIds.contains(video.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  video.thumbnail,
                  width: 80,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.author,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Download Button
              if (isDownloading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  color: const Color(0xFFE91E63),
                  onPressed: () => _downloadSong(video),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlbumsTab() {
    if (_albumResults.isEmpty) {
      return const Center(
        child: Text(
          "Busca álbumes en YouTube",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _albumResults.length,
      itemBuilder: (context, index) {
        final album = _albumResults[index];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => YoutubeAlbumDetailPage(album: album),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    album.thumbnail,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.album, size: 40),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        album.author,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${album.trackCount} canciones",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow Icon
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFE91E63),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
