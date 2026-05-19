import 'package:flutter/material.dart';
import '../services/download_service.dart';
import '../widgets/custom_dialogs.dart';

class YoutubeAlbumDetailPage extends StatefulWidget {
  final AlbumResult album;

  const YoutubeAlbumDetailPage({super.key, required this.album});

  @override
  State<YoutubeAlbumDetailPage> createState() => _YoutubeAlbumDetailPageState();
}

class _YoutubeAlbumDetailPageState extends State<YoutubeAlbumDetailPage> {
  final DownloadService _downloadService = DownloadService();
  List<VideoResult> _tracks = [];
  bool _isLoading = true;
  final Set<String> _downloadingIds = {};
  bool _isDownloadingAlbum = false;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() => _isLoading = true);
    
    final tracks = await _downloadService.getAlbumTracks(widget.album.id);
    
    if (mounted) {
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadSong(VideoResult video) async {
    setState(() {
      _downloadingIds.add(video.id);
    });

    AppDialogs.showToast(context, 'Iniciando descarga de "${video.title}"...');

    _downloadService.downloadAndConvertToMp3Async(video);
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(video.id);
        });
      }
    });
  }

  Future<void> _downloadAlbum() async {
    setState(() => _isDownloadingAlbum = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Iniciando descarga del álbum "${widget.album.title}"...'),
        duration: const Duration(seconds: 3),
      ),
    );

    _downloadService.downloadAlbumAsync(widget.album);
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isDownloadingAlbum = false);
      }
    });
  }

  @override
  void dispose() {
    _downloadService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 340,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF1A1F3D),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Container(
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 30), // Space for upper status bar and leading button
                          // Album Art
                          Hero(
                            tag: 'album_art_${widget.album.id}',
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white10, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  widget.album.thumbnail,
                                  width: 130,
                                  height: 130,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[900],
                                    child: const Icon(Icons.album, size: 60, color: Colors.white24),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              widget.album.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.album.author,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoBadge("${_tracks.length} Canciones", Icons.music_note_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // --- Lista de canciones ---
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(bottom: 120, top: 16),
                  child: _isLoading
                      ? const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator(color: Color(0xFFE91E63))),
                        )
                      : _tracks.isEmpty
                          ? const SizedBox(
                              height: 200,
                              child: Center(
                                child: Text(
                                  "No se encontraron canciones",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _tracks.length,
                              itemBuilder: (context, index) {
                                final track = _tracks[index];
                                final isDownloading = _downloadingIds.contains(track.id);
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Track Number
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE91E63).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            "${index + 1}",
                                            style: const TextStyle(
                                              color: Color(0xFFE91E63),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // Track Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              track.author,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Download Button
                                      if (isDownloading)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.download_rounded, size: 20),
                                          color: const Color(0xFFE91E63),
                                          onPressed: () => _downloadSong(track),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
          
          // --- Botón flotante de descargar álbum (fijo) ---
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isDownloadingAlbum ? null : _downloadAlbum,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: _isDownloadingAlbum
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFE91E63), Color(0xFFD81B60)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      color: _isDownloadingAlbum ? Colors.grey[400] : null,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isDownloadingAlbum)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.download_rounded,
                              color: Color(0xFFE91E63),
                              size: 18,
                            ),
                          ),
                        const SizedBox(width: 15),
                        Text(
                          _isDownloadingAlbum ? "Descargando álbum..." : "Descargar álbum completo",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
}