import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/database_helper.dart';
import '../services/audio_service.dart';
import 'playlist_detail.dart';
import '../widgets/custom_dialogs.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  List<Map<String, dynamic>> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
    
    // Escuchar cambios en la base de datos para recargar automáticamente
    DatabaseHelper.instance.playlistsStream.listen((_) {
      if (mounted) _loadPlaylists();
    });
  }

  Future<void> _loadPlaylists() async {
    setState(() => _isLoading = true);
    final playlists = await DatabaseHelper.instance.getAllPlaylists();
    setState(() {
      _playlists = playlists;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Gradient Header
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
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                          'Mis Playlists',
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
                            Icons.playlist_add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _showCreatePlaylistDialog, // Reutilizamos el botón inferior
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),

                // Main Content Sheet
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                        : _playlists.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.playlist_add_rounded,
                                      size: 80,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No tienes playlists',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Crea tu primera playlist',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(20),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: _playlists.length,
                                itemBuilder: (context, index) {
                                  final playlist = _playlists[index];
                                  return _buildPlaylistCard(playlist);
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePlaylistDialog,
        backgroundColor: const Color(0xFF1A1F3D),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nueva Playlist', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildPlaylistCard(Map<String, dynamic> playlist) {
    final name = playlist['name'] ?? 'Sin nombre';
    final description = playlist['description'] ?? '';
    final imagePath = playlist['image_path'];

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistDetailPage(playlist: playlist),
          ),
        );
        _loadPlaylists();
      },
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background
              if (imagePath != null)
                Image.network(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildDefaultBackground(),
                )
              else
                _buildDefaultBackground(),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: DatabaseHelper.instance.getPlaylistSongs(playlist['id']),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Row(
                          children: [
                            const Icon(
                              Icons.music_note_rounded,
                              color: Color(0xFFE91E63),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$count ${count == 1 ? 'canción' : 'canciones'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1F3D),
            const Color(0xFFE91E63).withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.queue_music_rounded,
          size: 60,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    AppDialogs.showCustomDialog(
      context: context,
      title: 'Nueva Playlist',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nombre',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE91E63)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Descripción (opcional)',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE91E63)),
              ),
            ),
          ),
        ],
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) {
              AppDialogs.showToast(context, 'Ingresa un nombre', isError: true);
              return;
            }

            await DatabaseHelper.instance.createPlaylist({
              'name': nameController.text.trim(),
              'description': descriptionController.text.trim(),
            });

            if (mounted) {
              Navigator.of(dialogContext).pop();
              _loadPlaylists();
              AppDialogs.showToast(context, 'Playlist creada');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E63),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Crear', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
