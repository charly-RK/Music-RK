import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../services/audio_service.dart';
import '../widgets/custom_dialogs.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  List<String> _folders = [];
  bool _isLoading = true;

  bool _searchAllDevice = true;
  String _downloadPath = '/storage/emulated/0/Music';

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _folders = prefs.getStringList('music_folders') ?? [];
      _searchAllDevice = prefs.getBool('search_all_device') ?? true;
      _downloadPath = prefs.getString('download_path') ?? '/storage/emulated/0/Music';
      _isLoading = false;
    });
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('music_folders', _folders);
    await prefs.setBool('search_all_device', _searchAllDevice);
    await prefs.setString('download_path', _downloadPath);
  }



  Future<void> _selectDownloadPath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _downloadPath = selectedDirectory;
      });
      await _saveFolders();
    }
  }

  Future<void> _addFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      if (!_folders.contains(selectedDirectory)) {
        setState(() {
          _folders.add(selectedDirectory);
          // If user adds a folder, they likely want to restrict search, but let's keep it explicit
        });
        await _saveFolders();
        await AudioService().reloadLibrary();
      } else {
        if (mounted) {
          AppDialogs.showToast(context, 'Esta carpeta ya está en la lista');
        }
      }
    }
  }

  Future<void> _removeFolder(int index) async {
    setState(() {
      _folders.removeAt(index);
    });
    await _saveFolders();
    await AudioService().reloadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
            : SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildSectionHeader('General'),
                    _buildConfigTile(
                      title: 'Ruta de Descargas',
                      subtitle: _downloadPath,
                      icon: Icons.download_rounded,
                      onTap: _selectDownloadPath,
                    ),
                    _buildSwitchTile(
                      title: 'Buscar en todo el dispositivo',
                      subtitle: 'Ignorar carpetas personalizadas',
                      value: _searchAllDevice,
                      onChanged: (value) async {
                        setState(() {
                          _searchAllDevice = value;
                        });
                        await _saveFolders();
                        // Reload library to reflect changes
                        await AudioService().reloadLibrary();
                      },
                    ),
                    
                    const SizedBox(height: 30),
                    _buildSectionHeader('Carpetas de Música'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        'Gestiona las carpetas donde la app buscará tu música local.',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                      ),
                    ),
                    
                    Expanded(
                      child: _folders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_off_rounded, size: 60, color: Colors.white.withOpacity(0.2)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No hay carpetas configuradas',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _folders.length,
                              itemBuilder: (context, index) {
                                final folder = _folders[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE91E63).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.folder_rounded, color: Color(0xFFE91E63)),
                                    ),
                                    title: Text(
                                      folder.split('/').last,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      folder,
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                      onPressed: () => _removeFolder(index),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: !_searchAllDevice ? FloatingActionButton.extended(
        onPressed: _addFolder,
        backgroundColor: const Color(0xFFE91E63),
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('Añadir Carpeta'),
      ) : null,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFE91E63),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildConfigTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFE91E63),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            value ? Icons.travel_explore_rounded : Icons.folder_special_rounded,
            color: value ? const Color(0xFFE91E63) : Colors.grey,
          ),
        ),
      ),
    );
  }
}
