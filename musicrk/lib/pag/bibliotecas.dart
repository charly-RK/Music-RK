import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_helper.dart';
import 'album.dart';
import '../widgets/custom_dialogs.dart';

class LibraryPage extends StatefulWidget {
  final VoidCallback? onBackTap;

  const LibraryPage({
    super.key,
    this.onBackTap,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _libraries = [];
  List<Map<String, dynamic>> _filteredLibraries = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLibraries();
    
    // Escuchar cambios en la base de datos para recargar automáticamente
    DatabaseHelper.instance.albumsStream.listen((_) {
      if (mounted) _refreshLibraries();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _filterLibraries(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isEmpty) {
        setState(() {
          _filteredLibraries = List.from(_libraries);
        });
        return;
      }

      final lowerQuery = query.toLowerCase();
      final filtered = _libraries.where((lib) {
        final name = (lib['name'] ?? '').toString().toLowerCase();
        return name.contains(lowerQuery);
      }).toList();

      setState(() {
        _filteredLibraries = filtered;
      });
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Recargar cuando la app vuelve al primer plano
    if (state == AppLifecycleState.resumed) {
      _refreshLibraries();
    }
  }

  Future<void> _refreshLibraries() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getAllAlbums();
      setState(() {
        _libraries = data;
        if (_isSearching && _searchController.text.isNotEmpty) {
          _filterLibraries(_searchController.text);
        } else {
          _filteredLibraries = data;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading libraries: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createAlbum(String name, String artist, String year, String genre, String description) async {
    try {
      await DatabaseHelper.instance.createAlbum({
        'name': name,
        'artist': artist,
        'year': year,
        'genre': genre,
        'description': description,
        'type': 'custom',
        'image_path': null,
      });
      await _refreshLibraries();
      if (mounted) {
        AppDialogs.showToast(context, 'Álbum "$name" creado exitosamente');
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showToast(context, 'Error al crear álbum', isError: true);
      }
    }
  }

  Future<void> _addFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        final folderName = selectedDirectory.split('/').last.split('\\').last;
        await DatabaseHelper.instance.createAlbum({
          'name': folderName,
          'type': 'folder',
          'folder_path': selectedDirectory,
          'image_path': null,
        });
        await _refreshLibraries();
        if (mounted) {
          AppDialogs.showToast(context, 'Carpeta "$folderName" agregada');
        }
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showToast(context, 'Error al agregar carpeta', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
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
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                        onPressed: widget.onBackTap ?? () => Navigator.pop(context),
                      ),
                    ),
                    Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isSearching
                              ? TextField(
                                  key: const ValueKey('search_field'),
                                  controller: _searchController,
                                  autofocus: true,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  decoration: const InputDecoration(
                                    hintText: "Buscar biblioteca...",
                                    hintStyle: TextStyle(color: Colors.white54),
                                    border: InputBorder.none,
                                  ),
                                  onChanged: _filterLibraries,
                                )
                              : const Text(
                                  'Tu Biblioteca',
                                  key: ValueKey('title_text'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20, // Reducido de 24 a 20
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
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
                        icon: Icon(
                          _isSearching ? Icons.close_rounded : Icons.search_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_isSearching) {
                              _isSearching = false;
                              _searchController.clear();
                              _filterLibraries("");
                            } else {
                              _isSearching = true;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                      : RefreshIndicator(
                          onRefresh: _refreshLibraries,
                          color: const Color(0xFFE91E63),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.3, // Reducido verticalmente 
                      ),
                      itemCount: _filteredLibraries.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildAddLibraryCard(context);
                        }
                        final lib = _filteredLibraries[index - 1];
                        // Por ahora, simula el recuento de canciones o búscala
                        int songCount = 0; // TODO: Buscar el recuento real
                        // String image = lib['image_path'] ?? 'assets/imagenes/carpeta_2.jpg';
                        if (lib['type'] == 'folder') {
                           // Utilice un icono de carpeta o una imagen específica para las carpetas si es necesario
                        }

                        return _buildLibraryCard(context, lib);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddLibraryCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: InkWell(
        onTap: () => _showOptionsSheet(context),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 32,
                color: Color(0xFFE91E63),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Añadir Nuevo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F3D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              const Text('Opciones de Biblioteca', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildOptionTile(context, icon: Icons.album_rounded, title: 'Crear nuevo álbum', subtitle: 'Organiza tus canciones manualmente', onTap: () { Navigator.pop(context); _showCreateAlbumForm(context); }),
              _buildOptionTile(context, icon: Icons.create_new_folder_rounded, title: 'Añadir nueva carpeta', subtitle: 'Importar desde el almacenamiento', onTap: () { Navigator.pop(context); _addFolder(); }),
              _buildOptionTile(context, icon: Icons.playlist_add_rounded, title: 'Importar lista', subtitle: 'Desde archivos .m3u o .pls', onTap: () { Navigator.pop(context); }),
              _buildOptionTile(context, icon: Icons.sync_rounded, title: 'Escanear biblioteca', subtitle: 'Buscar cambios recientes', onTap: () { Navigator.pop(context); }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateAlbumForm(BuildContext context) {
    final nameController = TextEditingController();
    final artistController = TextEditingController();
    final yearController = TextEditingController();
    final genreController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1F3D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              const Text('Nuevo Álbum', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildTextField('Nombre del Álbum *', Icons.title_rounded, controller: nameController),
                      const SizedBox(height: 16),
                      _buildTextField('Artista / Banda', Icons.person_rounded, controller: artistController),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Año', Icons.calendar_today_rounded, controller: yearController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField('Género', Icons.music_note_rounded, controller: genreController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField('Descripción', Icons.description_rounded, maxLines: 3, controller: descController),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.white10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Cancelar', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (nameController.text.isNotEmpty) {
                                  _createAlbum(nameController.text, artistController.text, yearController.text, genreController.text, descController.text);
                                  Navigator.of(context).pop();
                                } else {
                                  AppDialogs.showToast(context, 'El nombre es obligatorio', isError: true);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE91E63),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 8,
                                shadowColor: const Color(0xFFE91E63).withOpacity(0.5),
                              ),
                              child: const Text('Crear', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, {int maxLines = 1, TextEditingController? controller}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFFE91E63)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFFE91E63)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _buildLibraryCard(BuildContext context, Map<String, dynamic> album) {
    String name = album['name'];
    String? dbImagePath = album['image_path']; 
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (_, __, ___) => AlbumPage(album: album),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeOutQuart;

                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
              ),
            );
          },
          child: Stack(
            children: [
            // Imagen de fondo
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                child: dbImagePath != null && dbImagePath.startsWith('http')
                    ? Image.network(
                        dbImagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
                      )
                    : Image.asset(
                        'assets/imagenes/carpeta_1.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
                      ),
              ),
            ),
            // Overlay degradado
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Contenido de texto
            Positioned(
              bottom: 16,
              left: 14,
              right: 48, // Padding derecho grande para no chocar con el botón de play
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Para que la columna no ocupe más de lo necesario
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Ligeramente más pequeño para acomodar 2 líneas
                      height: 1.2, // Interlineado ajustado
                    ),
                    maxLines: 2, // Permitir 2 líneas para nombres largos
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Mostramos "Carpeta" o "Álbum" si el recuento de canciones es desconocido
                  Text(
                    album['type'] == 'folder' ? 'Carpeta' : 'Álbum',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Botón de reproducción
            Positioned(
              bottom: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE91E63).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: Colors.grey[900],
      child: const Icon(Icons.folder_shared_rounded, color: Colors.white24, size: 50),
    );
  }
}

