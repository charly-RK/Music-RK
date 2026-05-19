import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/database_helper.dart';
import '../services/audio_service.dart';
import 'custom_dialogs.dart';

class SongOptionsSheet extends StatelessWidget {
  final SongModel song;
  final VoidCallback? onPlay;
  final VoidCallback? onAddToFavorites;
  final VoidCallback? onInfo;
  final VoidCallback? onDelete;
  final String? deleteLabel;
  final String? deleteSubtitle;
  final bool isFavorite;
  final VoidCallback? onRefresh;

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
    this.onRefresh,
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
                      width: 60,
                      height: 60,
                      child: QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        nullArtworkWidget: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[800],
                            gradient: LinearGradient(
                              colors: [const Color(0xFFE91E63).withOpacity(0.3), const Color(0xFF1A1F3D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
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
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist ?? "Desconocido",
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
            
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
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
                        Navigator.pop(context); // Cerrar hoja primero
                        // Pequeño delay para asegurar que el teclado/foco no tengan conflictos
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (context.mounted) _showRenameDialog(context);
                        });
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
                          if (context.mounted) {
                            AppDialogs.showToast(context, isFavorite ? "Quitado de Favoritos" : "Agregado a Favoritos");
                          }
                        } else {
                          if (isFavorite) {
                             await DatabaseHelper.instance.removeFavorite(song.id);
                             if (context.mounted) AppDialogs.showToast(context, "Quitado de Favoritos");
                          } else {
                            await DatabaseHelper.instance.addFavorite({
                              'song_id': song.id,
                              'title': song.title,
                              'artist': song.artist,
                              'album': song.album,
                              'data': song.data,
                              'duration': song.duration,
                            });
                            if (context.mounted) AppDialogs.showToast(context, "Agregado a Favoritos");
                          }
                          if (onRefresh != null) onRefresh!();
                        }
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.info_outline_rounded,
                      title: "Información",
                      subtitle: "Ver detalles de la canción",
                      onTap: () {
                        if (onInfo != null) {
                          Navigator.pop(context);
                          onInfo!();
                        } else {
                          // Mostrar el diálogo de información sin cerrar la hoja primero
                          // para evitar que el contexto sea invalidado.
                          _showSongInfo(context);
                        }
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.share_rounded,
                      title: "Compartir",
                      subtitle: "Enviar archivo de audio",
                      onTap: () {
                        Navigator.pop(context);
                        _shareSong(context);
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
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      leading: const Icon(Icons.close_rounded, color: Colors.white54),
                      title: const Text("Cerrar", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: color.withOpacity(0.5), fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSongInfo(BuildContext context) {
    // Cerramos el BottomSheet antes de mostrar el diálogo para limpiar el contexto
    Navigator.of(context).pop();
    
    AppDialogs.showCustomDialog(
      context: context,
      title: "Detalles",
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow("Archivo", song.displayName),
          _buildInfoRow("Artista", song.artist ?? "Desconocido"),
          _buildInfoRow("Álbum", song.album ?? "Desconocido"),
          _buildInfoRow("Duración", "${(song.duration ?? 0) ~/ 1000}s"),
          _buildInfoRow("Tamaño", "${(song.size / (1024 * 1024)).toStringAsFixed(2)} MB"),
          _buildInfoRow("Ruta", song.data),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context) {
    AppDialogs.showCustomDialog(
      context: context,
      title: "Agregar a Playlist",
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseHelper.instance.getAllPlaylists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
            final playlists = snapshot.data ?? [];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: Color(0xFFE91E63)),
                  title: const Text("Nueva Playlist", style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(context); _showCreatePlaylistDialog(context); },
                ),
                const Divider(color: Colors.white10),
                if (playlists.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Text("No tienes playlists", style: TextStyle(color: Colors.white38)))
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
                          onTap: () async {
                            final isDuplicate = await DatabaseHelper.instance.isSongInPlaylist(playlist['id'], song.id);
                            
                            // Siempre cerramos el diálogo de selección de playlist
                            if (context.mounted) Navigator.pop(context);
                            
                            if (isDuplicate) {
                              if (context.mounted) AppDialogs.showToast(context, "Ya existe en la playlist: ${playlist['name']}", isError: true);
                            } else {
                              await DatabaseHelper.instance.addSongToPlaylist(playlist['id'], {
                                'song_id': song.id, 'title': song.title, 'artist': song.artist, 'album': song.album, 'data': song.data, 'duration': song.duration,
                              });
                              if (context.mounted) {
                                AppDialogs.showToast(context, "Agregado a ${playlist['name']}");
                                if (onRefresh != null) onRefresh!();
                              }
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
    );
  }

  void _showAddToAlbumDialog(BuildContext context) async {
    final albums = await DatabaseHelper.instance.getAllAlbums();
    final customAlbums = albums.where((a) => a['type'] == 'custom').toList();
    if (!context.mounted) return;
    AppDialogs.showCustomDialog(
      context: context,
      title: "Agregar a Álbum",
      content: SizedBox(
        width: double.maxFinite,
        child: customAlbums.isEmpty
          ? const Padding(padding: EdgeInsets.all(20), child: Text("No tienes álbumes", style: TextStyle(color: Colors.white38)))
          : ListView.builder(
              shrinkWrap: true,
              itemCount: customAlbums.length,
              itemBuilder: (context, index) {
                final album = customAlbums[index];
                return ListTile(
                  leading: const Icon(Icons.album_rounded, color: Colors.white70),
                  title: Text(album['name'], style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    final isDuplicate = await DatabaseHelper.instance.isSongInAlbum(album['id'], song.data);
                    
                    // Siempre cerramos el diálogo de selección de álbum
                    if (context.mounted) Navigator.pop(context);
                    
                    if (isDuplicate) {
                      if (context.mounted) AppDialogs.showToast(context, "Ya existe en el álbum", isError: true);
                    } else {
                      await DatabaseHelper.instance.addSongToAlbum(album['id'], song.data);
                      if (context.mounted) {
                        AppDialogs.showToast(context, "Agregado al álbum: ${album['name']}");
                        if (onRefresh != null) onRefresh!();
                      }
                    }
                  },
                );
              },
            ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    AppDialogs.showTextInputDialog(
      context: context, title: "Nueva Playlist", hintText: "Nombre",
      onConfirm: (name) async {
        final id = await DatabaseHelper.instance.createPlaylist({'name': name, 'description': '', 'image_path': ''});
        await DatabaseHelper.instance.addSongToPlaylist(id, {'song_id': song.id, 'title': song.title, 'artist': song.artist, 'album': song.album, 'data': song.data, 'duration': song.duration});
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    AppDialogs.showTextInputDialog(
      context: context, title: "Renombrar", hintText: "Nuevo nombre", initialValue: song.title,
      onConfirm: (newName) async {
        if (newName.trim().isEmpty) return;
        final success = await AudioService().renameSong(song, newName.trim());
        if (success) {
          if (context.mounted) AppDialogs.showToast(context, "Canción renombrada");
          if (onRefresh != null) onRefresh!();
        } else {
          if (context.mounted) AppDialogs.showToast(context, "Error al renombrar", isError: true);
        }
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    AppDialogs.showConfirmDialog(
      context: context, title: "Eliminar", message: "¿Estás seguro de eliminar este archivo permanentemente?", confirmLabel: "Eliminar",
      onConfirm: () async {
        final success = await AudioService().deleteSong(song);
        if (success) {
          if (context.mounted) AppDialogs.showToast(context, "Archivo eliminado");
          if (onRefresh != null) onRefresh!();
        } else {
          if (context.mounted) AppDialogs.showToast(context, "Error al eliminar archivo", isError: true);
        }
      },
    );
  }

  void _shareSong(BuildContext context) {
    try { Share.shareXFiles([XFile(song.data)], text: "Escucha ${song.title} de ${song.artist}"); } catch (e) { debugPrint("Error: $e"); }
  }
}
