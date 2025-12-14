import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/database_helper.dart';

class SongOptionsSheet extends StatelessWidget {
  final SongModel song;
  final VoidCallback? onPlay;
  final VoidCallback? onAddToFavorites; // Optional: if null, uses default logic
  final VoidCallback? onInfo; // Optional: if null, uses default logic
  final VoidCallback? onDelete; // Optional: Custom delete action (e.g., remove from playlist)
  final String? deleteLabel;
  final String? deleteSubtitle;
  final bool isFavorite;

  const SongOptionsSheet({
    super.key,
    required this.song,
    this.onPlay,
    this.onAddToFavorites,
    this.onInfo,
    this.onDelete,
    this.deleteLabel,
    this.deleteSubtitle,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.15,
                      height: MediaQuery.of(context).size.width * 0.15,
                      constraints: const BoxConstraints(
                        minWidth: 50,
                        maxWidth: 70,
                        minHeight: 50,
                        maxHeight: 70,
                      ),
                      child: QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        nullArtworkWidget: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[800],
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFE91E63).withOpacity(0.3),
                                const Color(0xFF1A1F3D),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.music_note, color: Colors.white54, size: 28),
                        ),
                        artworkFit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          song.artist ?? "Desconocido",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${(song.duration ?? 0) ~/ 1000}s",
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
            
            if (onPlay != null)
              _buildOptionTile(
                icon: Icons.play_arrow_rounded,
                title: "Reproducir",
                subtitle: "Reproducir esta canción",
                onTap: () {
                  Navigator.pop(context);
                  onPlay!();
                },
              ),

            _buildOptionTile(
              icon: Icons.playlist_add_rounded,
              title: "Agregar a Playlist",
              subtitle: "Guardar en una lista de reproducción",
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistDialog(context);
              },
            ),

            _buildOptionTile(
              icon: Icons.album_rounded,
              title: "Agregar a Álbum",
              subtitle: "Añadir a un álbum personalizado",
              onTap: () {
                Navigator.pop(context);
                _showAddToAlbumDialog(context);
              },
            ),

            _buildOptionTile(
              icon: Icons.edit_rounded,
              title: "Renombrar",
              subtitle: "Cambiar nombre de la canción",
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context);
              },
            ),

            _buildOptionTile(
              icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              title: isFavorite ? "Quitar de Favoritos" : "Agregar a Favoritos",
              subtitle: isFavorite ? "Eliminar de tu lista de favoritos" : "Guardar en tu lista de favoritos",
              color: isFavorite ? const Color(0xFFE91E63) : Colors.white,
              onTap: () async {
                Navigator.pop(context);
                if (onAddToFavorites != null) {
                  onAddToFavorites!();
                } else {
                  if (isFavorite) {
                     // Remove from favorites
                     await DatabaseHelper.instance.removeFavorite(song.id);
                     if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Eliminado de favoritos")),
                        );
                     }
                  } else {
                    // Add to favorites
                    await DatabaseHelper.instance.addFavorite({
                      'song_id': song.id,
                      'title': song.title,
                      'artist': song.artist,
                      'album': song.album,
                      'data': song.data,
                      'duration': song.duration,
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.favorite, color: Color(0xFFE91E63), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Agregado a favoritos',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF1A1F3D).withOpacity(0.95),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                          elevation: 6,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                }
              },
            ),
            _buildOptionTile(
              icon: Icons.info_outline_rounded,
              title: "Información",
              subtitle: "Ver detalles de la canción",
              onTap: () {
                Navigator.pop(context);
                if (onInfo != null) {
                  onInfo!();
                } else {
                  _showSongInfo(context, song);
                }
              },
            ),
            const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
            _buildOptionTile(
              icon: Icons.delete_outline_rounded,
              title: deleteLabel ?? "Eliminar del dispositivo",
              subtitle: deleteSubtitle ?? "Eliminar archivo permanentemente",
              color: const Color(0xFFE91E63),
              onTap: () {
                Navigator.pop(context);
                if (onDelete != null) {
                  onDelete!();
                } else {
                  _showDeleteConfirmation(context);
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String subtitle = "",
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: color.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showSongInfo(BuildContext context, SongModel song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        title: const Text("Información", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow("Archivo:", song.displayName),
            _buildInfoRow("Artista:", song.artist ?? "Desconocido"),
            _buildInfoRow("Álbum:", song.album ?? "Desconocido"),
            _buildInfoRow("Duración:", "${(song.duration ?? 0) ~/ 1000}s"),
            _buildInfoRow("Tamaño:", "${(song.size / (1024 * 1024)).toStringAsFixed(2)} MB"),
            _buildInfoRow("Ruta:", song.data),
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

  void _showAddToPlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        title: const Text("Agregar a Playlist", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.getAllPlaylists(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  heightFactor: 1,
                  child: CircularProgressIndicator(color: Color(0xFFE91E63)),
                );
              }
              
              final playlists = snapshot.data ?? [];
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                    title: const Text("Nueva Playlist", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreatePlaylistDialog(context);
                    },
                  ),
                  const Divider(color: Colors.white24),
                  if (playlists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No tienes playlists creadas", style: TextStyle(color: Colors.white54)),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlists[index];
                          return ListTile(
                            leading: const Icon(Icons.playlist_play_rounded, color: Colors.white70),
                            title: Text(playlist['name'], style: const TextStyle(color: Colors.white)),
                            subtitle: Text("${playlist['created_at'].toString().split('T')[0]}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                            onTap: () async {
                              Navigator.pop(context);
                              await DatabaseHelper.instance.addSongToPlaylist(playlist['id'], {
                                'song_id': song.id,
                                'title': song.title,
                                'artist': song.artist,
                                'album': song.album,
                                'data': song.data,
                                'duration': song.duration,
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Agregada a la playlist")),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showAddToAlbumDialog(BuildContext context) async {
    final albums = await DatabaseHelper.instance.getAllAlbums();
    // Filter only custom albums
    final customAlbums = albums.where((a) => a['type'] == 'custom').toList();
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        title: const Text("Agregar a Álbum", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customAlbums.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No tienes álbumes personalizados", style: TextStyle(color: Colors.white54)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: customAlbums.length,
                    itemBuilder: (context, index) {
                      final album = customAlbums[index];
                      return ListTile(
                        leading: const Icon(Icons.album_rounded, color: Colors.white70),
                        title: Text(album['name'], style: const TextStyle(color: Colors.white)),
                        onTap: () async {
                          Navigator.pop(context);
                          
                          // Check if song already exists
                          final exists = await DatabaseHelper.instance.isSongInAlbum(album['id'], song.data);
                          
                          if (context.mounted) {
                            if (exists) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text("Esta canción ya existe en el álbum"),
                                  backgroundColor: Colors.orange.withOpacity(0.9),
                                ),
                              );
                            } else {
                              await DatabaseHelper.instance.addSongToAlbum(album['id'], song.data);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Agregada al álbum")),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        title: const Text("Nueva Playlist", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Nombre de la playlist",
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
                final id = await DatabaseHelper.instance.createPlaylist({
                  'name': controller.text,
                  'description': '',
                  'image_path': '',
                });
                
                // Add song to the new playlist immediately
                await DatabaseHelper.instance.addSongToPlaylist(id, {
                  'song_id': song.id,
                  'title': song.title,
                  'artist': song.artist,
                  'album': song.album,
                  'data': song.data,
                  'duration': song.duration,
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Playlist creada y canción agregada")),
                  );
                }
              }
            },
            child: const Text("Crear", style: TextStyle(color: Color(0xFFE91E63))),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(text: song.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        title: const Text("Renombrar", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Nuevo nombre",
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE91E63))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Request permissions first
                bool hasPermission = false;
                if (Platform.isAndroid) {
                  if (await Permission.manageExternalStorage.status.isGranted) {
                    hasPermission = true;
                  } else if (await Permission.manageExternalStorage.request().isGranted) {
                    hasPermission = true;
                  }
                  
                  if (!hasPermission) {
                    if (await Permission.storage.status.isGranted) {
                      hasPermission = true;
                    } else if (await Permission.storage.request().isGranted) {
                      hasPermission = true;
                    }
                  }
                } else {
                  hasPermission = true;
                }

                if (hasPermission) {
                  final file = File(song.data);
                  if (await file.exists()) {
                    final dir = file.parent.path;
                    final extension = song.displayName.split('.').last;
                    final newPath = '$dir/${controller.text}.$extension';
                    await file.rename(newPath);
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Archivo renombrado (puede requerir re-escaneo)")),
                      );
                    }
                  } else {
                    throw Exception("Archivo no encontrado");
                  }
                } else {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Permiso denegado para renombrar archivos")),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error al renombrar: $e")),
                  );
                }
              }
            },
            child: const Text("Renombrar", style: TextStyle(color: Color(0xFFE91E63))),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        title: const Text("Eliminar Canción", style: TextStyle(color: Colors.white)),
        content: const Text(
          "¿Estás seguro de que deseas eliminar este archivo permanentemente de tu dispositivo?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Request permissions first
                bool hasPermission = false;
                if (Platform.isAndroid) {
                  // For Android 10+ (API 29+)
                  if (await Permission.manageExternalStorage.status.isGranted) {
                    hasPermission = true;
                  } else if (await Permission.manageExternalStorage.request().isGranted) {
                    hasPermission = true;
                  }
                  
                  // Fallback for older Android versions
                  if (!hasPermission) {
                    if (await Permission.storage.status.isGranted) {
                      hasPermission = true;
                    } else if (await Permission.storage.request().isGranted) {
                      hasPermission = true;
                    }
                  }
                } else {
                  hasPermission = true; // iOS/Desktop usually handled differently or sandboxed
                }

                if (hasPermission) {
                  final file = File(song.data);
                  if (await file.exists()) {
                    await file.delete();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Archivo eliminado")),
                      );
                      // Note: The app should ideally refresh the song list here.
                      // OnAudioQuery might need a scan to update.
                    }
                  } else {
                    throw Exception("Archivo no encontrado");
                  }
                } else {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Permiso denegado para eliminar archivos")),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error al eliminar: $e")),
                  );
                }
              }
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _shareSong(BuildContext context) {
    try {
      Share.shareXFiles([XFile(song.data)], text: "Escucha ${song.title} de ${song.artist}");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al compartir: $e")),
      );
    }
  }
}
