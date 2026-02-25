import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:musicrk/pag/buscar.dart';
import '../config_page.dart';
import '../bibliotecas.dart';
import '../favoritos.dart';
import '../playlists.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  // Removed heavy queries - stats will load asynchronously
  int _songCount = 0;
  int _albumCount = 0;
  int _artistCount = 0;

  @override
  void initState() {
    super.initState();
    // Load stats asynchronously after drawer is shown
    Future.delayed(const Duration(milliseconds: 100), _loadStats);
  }

  Future<void> _loadStats() async {
    try {
      // Optimized: Use cached query with minimal data
      final OnAudioQuery audioQuery = OnAudioQuery();
      final songs = await audioQuery.querySongs();
      final albums = await audioQuery.queryAlbums();
      final artists = await audioQuery.queryArtists();

      if (mounted) {
        setState(() {
          _songCount = songs.length;
          _albumCount = albums.length;
          _artistCount = artists.length;
        });
      }
    } catch (e) {
      debugPrint("Error loading stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Aumentar el ancho del Drawer
    final double drawerWidth = MediaQuery.of(context).size.width * 0.8; 

    return Drawer(
      width: drawerWidth > 350 ? 350 : drawerWidth, 
      child: Container(
        // Solid color instead of gradient - MUCH faster
        color: const Color(0xFF1A1F3D),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              
              // 1. Perfil con Efecto Glow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1F3D),
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE91E63).withOpacity(0.2),
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.music_note_rounded,
                          color: Color(0xFFE91E63),
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /* Text(
                          "Buenos Días,",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ), */
                        const SizedBox(height: 4),
                        const Text(
                          "MusicRK Player",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // 3. Fila de estadísticas con Glassmorphism
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem("Canciones", "$_songCount"),
                      _buildVerticalDivider(),
                      _buildStatItem("Álbumes", "$_albumCount"),
                      _buildVerticalDivider(),
                      _buildStatItem("Artistas", "$_artistCount"),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // 4. Opciones de menú
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  children: [
                    _buildMenuItem(context, icon: Icons.home_rounded, title: "Inicio", isSelected: true),
                    _buildMenuItem(
                      context, 
                      icon: Icons.search_rounded, 
                      title: "Buscar",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BuscarPage()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context, 
                      icon: Icons.library_music_rounded, 
                      title: "Biblioteca",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LibraryPage()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context, 
                      icon: Icons.favorite_rounded, 
                      title: "Favoritos",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FavoritosPage()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context, 
                      icon: Icons.playlist_play_rounded, 
                      title: "Listas",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PlaylistsPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Divider(color: Colors.white.withOpacity(0.1), thickness: 1),
                    const SizedBox(height: 10),
                    _buildMenuItem(
                      context, 
                      icon: Icons.settings_rounded, 
                      title: "Ajustes",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ConfigPage()),
                        );
                      },
                    ),
                    // _buildMenuItem(context, icon: Icons.logout_rounded, title: "Cerrar Sesión", isDestructive: true),
                  ],
                ),
              ),
              
              // Información de versión
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Text(
                  "v1.0.0 • MusicRK",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets auxiliares -----

  Widget _buildStatItem(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, bool isSelected = false, bool isDestructive = false, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE91E63).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: const Color(0xFFE91E63).withOpacity(0.5)) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.redAccent : (isSelected ? const Color(0xFFE91E63) : Colors.white70),
                size: 22,
              ),
              const SizedBox(width: 15),
              Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.redAccent : (isSelected ? Colors.white : Colors.white70),
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              if (isSelected) ...[ 
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE91E63),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
