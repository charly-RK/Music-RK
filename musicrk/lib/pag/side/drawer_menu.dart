import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:musicrk/pag/buscar.dart';
import '../config_page.dart';
import '../bibliotecas.dart';
import '../favoritos.dart';
import '../playlists.dart';
import '../../services/audio_service.dart';
import '../../services/database_helper.dart';
import 'dart:async';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> with SingleTickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  StreamSubscription? _playingSubscription;
  late AnimationController _rotationController;
  // Removed heavy queries - stats will load asynchronously
  int _songCount = 0;
  int _albumCount = 0;
  int _artistCount = 0;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _playingSubscription = _audioService.playingStream.listen((isPlaying) {
      if (mounted) {
        if (isPlaying) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      }
    });

    // Iniciar animación si ya está reproduciendo
    if (_audioService.player.playing) {
      _rotationController.repeat();
    }

    // Load stats asynchronously after drawer is shown
    Future.delayed(const Duration(milliseconds: 100), _loadStats);
  }

  @override
  void dispose() {
    _playingSubscription?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      // Optimized: Use database counts instead of full queries
      final songsCount = await DatabaseHelper.instance.getSongsCount();
      final albumsCount = await DatabaseHelper.instance.getAlbumsCount();
      final artistsCount = await DatabaseHelper.instance.getArtistsCount();

      if (mounted) {
        setState(() {
          _songCount = songsCount;
          _albumCount = albumsCount;
          _artistCount = artistsCount;
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
              
              // 1. Perfil con Efecto Premium
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFE91E63),
                            const Color(0xFFE91E63).withOpacity(0.5),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE91E63).withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A1F3D),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: RepaintBoundary(
                              child: RotationTransition(
                                turns: _rotationController,
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "MusicRK",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            "",
                            style: TextStyle(
                              color: Color(0xFFE91E63),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 3. Fila de estadísticas con Glassmorphism Mejorado
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
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
              
              const SizedBox(height: 32),
              
              // 4. Opciones de menú
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildMenuItem(context, icon: Icons.home_rounded, title: "Inicio", isSelected: true),
                    _buildMenuItem(
                      context, 
                      icon: Icons.search_rounded, 
                      title: "Buscar",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const BuscarPage()));
                      },
                    ),
                    _buildMenuItem(
                      context, 
                      icon: Icons.library_music_rounded, 
                      title: "Biblioteca",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const LibraryPage()));
                      },
                    ),
                    _buildMenuItem(
                      context, 
                      icon: Icons.favorite_rounded, 
                      title: "Favoritos",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritosPage()));
                      },
                    ),
                    _buildMenuItem(
                      context, 
                      icon: Icons.playlist_play_rounded, 
                      title: "Listas",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const PlaylistsPage()));
                      },
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withOpacity(0.05), thickness: 1),
                    const SizedBox(height: 16),
                    _buildMenuItem(
                      context, 
                      icon: Icons.settings_rounded, 
                      title: "Ajustes",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ConfigPage()));
                      },
                    ),
                  ],
                ),
              ),
              
              // Información de versión
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  "MusicRK • v1.0.0",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.1),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
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
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, bool isSelected = false, bool isDestructive = false, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE91E63).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFFE91E63).withOpacity(0.3) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.redAccent : (isSelected ? const Color(0xFFE91E63) : Colors.white60),
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.redAccent : (isSelected ? Colors.white : Colors.white70),
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              if (isSelected) ...[ 
                const Spacer(),
                Container(
                  width: 5,
                  height: 5,
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
