import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_helper.dart';
import '../services/audio_service.dart';
import '../widgets/song_options_sheet.dart';
import '../widgets/bottom_player.dart';
import 'play.dart';

class PlaylistDetailPage extends StatefulWidget {
  final Map<String, dynamic> playlist;

  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final AudioService _audioService = AudioService();
  List<Map<String, dynamic>> _songs = [];
  bool _isLoading = true;
  String _sortBy = 'position'; // position, title, artist, duration, date
  bool _isPlaying = false;
  int? _currentSongId;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _audioService.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _audioService.currentSongStream.listen((song) {
      if (mounted) setState(() => _currentSongId = song?.id);
    });
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    var songsData = await DatabaseHelper.instance.getPlaylistSongs(widget.playlist['id']);
    // Create a mutable copy of the list
    var songs = List<Map<String, dynamic>>.from(songsData);
    
    // Apply sorting
    _applySorting(songs);
    
    setState(() {
      _songs = songs;
      _isLoading = false;
    });
  }

  void _applySorting(List<Map<String, dynamic>> songs) {
    switch (_sortBy) {
      case 'title':
        songs.sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));
        break;
      case 'artist':
        songs.sort((a, b) {
          final artistA = a['artist'] as String? ?? '';
          final artistB = b['artist'] as String? ?? '';
          return artistA.compareTo(artistB);
        });
        break;
      case 'duration':
        songs.sort((a, b) => (a['duration'] as int).compareTo(b['duration'] as int));
        break;
      case 'date':
        songs.sort((a, b) => (b['added_at'] as String).compareTo(a['added_at'] as String));
        break;
      case 'position':
      default:
        songs.sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.playlist['name'] ?? 'Sin nombre';
    final description = widget.playlist['description'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: 300,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF1A1F3D),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: _showPlaylistOptions,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    widget.playlist['name'] ?? 'Sin nombre',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background
                      widget.playlist['image_path'] != null
                          ? Image.network(
                              widget.playlist['image_path'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildDefaultBackground(),
                            )
                          : _buildDefaultBackground(),
                      
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                      
                      // Info
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 60,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (description.isNotEmpty) ...[
                              Text(
                                description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                const Icon(Icons.music_note_rounded, color: Color(0xFFE91E63), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${_songs.length} ${_songs.length == 1 ? 'canción' : 'canciones'}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Controls
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Play button
                      ElevatedButton.icon(
                        onPressed: _songs.isEmpty ? null : () => _playPlaylist(),
                        icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(_isPlaying ? 'Pausar' : 'Reproducir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                      ),
                      
                      // Add songs button
                      OutlinedButton.icon(
                        onPressed: _showAddSongsDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Agregar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE91E63),
                          side: const BorderSide(color: Color(0xFFE91E63)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                      ),
                      
                      // Sort button
                      IconButton(
                        onPressed: _showSortOptions,
                        icon: const Icon(Icons.sort_rounded),
                        color: const Color(0xFF1A1F3D),
                      ),
                    ],
                  ),
                ),
              ),

              // Songs list
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_songs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.music_off_rounded, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay canciones',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showAddSongsDialog,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Agregar canciones'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = _songs[index];
                      return _buildSongTile(song, index);
                    },
                    childCount: _songs.length,
                  ),
                ),
                
              // Padding for bottom player
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
          
          // Bottom Player
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: StreamBuilder<bool>(
              stream: _audioService.playingStream,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;
                return BottomPlayer(
                  audioService: _audioService,
                  isPlaying: isPlaying,
                );
              },
            ),
          ),
        ],
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
    );
  }

  Widget _buildSongTile(Map<String, dynamic> song, int index) {
    final isPlaying = _currentSongId == song['song_id'];

    return Dismissible(
      key: Key('song_${song['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar canción'),
            content: const Text('¿Quieres eliminar esta canción de la playlist?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await DatabaseHelper.instance.removeSongFromPlaylist(
          widget.playlist['id'],
          song['song_id'],
        );
        _loadSongs();
      },
      child: Container(
        color: isPlaying ? const Color(0xFFE91E63).withOpacity(0.1) : null,
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: QueryArtworkWidget(
              id: song['song_id'],
              type: ArtworkType.AUDIO,
              artworkWidth: 50,
              artworkHeight: 50,
              artworkQuality: FilterQuality.low,
              keepOldArtwork: true,
              nullArtworkWidget: Container(
                width: 50,
                height: 50,
                color: Colors.grey[300],
                child: const Icon(Icons.music_note, color: Colors.grey),
              ),
            ),
          ),
          title: Text(
            song['title'],
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isPlaying ? const Color(0xFFE91E63) : Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            song['artist'] ?? 'Desconocido',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isPlaying ? const Color(0xFFE91E63).withOpacity(0.7) : null,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPlaying)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.equalizer_rounded, color: Color(0xFFE91E63), size: 20),
                ),
              Text(
                _formatDuration(song['duration'] ?? 0),
                style: TextStyle(
                  color: isPlaying ? const Color(0xFFE91E63).withOpacity(0.7) : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert_rounded, color: isPlaying ? const Color(0xFFE91E63) : Colors.grey),
                onPressed: () {
                  final songModel = SongModel({
                    '_id': song['song_id'],
                    'title': song['title'],
                    'artist': song['artist'],
                    'album': song['album'],
                    '_data': song['data'],
                    'duration': song['duration'],
                    '_size': 0, // Placeholder as size might not be in playlist DB
                    '_display_name': song['title'], // Placeholder
                  });
                  _showSongOptions(songModel);
                },
              ),
            ],
          ),
          onTap: () => _playSong(index),
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _playPlaylist() {
    if (_songs.isEmpty) return;
    
    // Check if we are already playing from this playlist AND context
    final currentSong = _audioService.currentSong;
    final isPlaying = _audioService.player.playing;
    final bool isCurrentSongInList = currentSong != null && _songs.any((s) => s['song_id'] == currentSong.id);
    final String contextId = 'playlist_${widget.playlist['id']}';
    final bool isSameContext = _audioService.playlistContext == contextId;

    if (isCurrentSongInList && isSameContext) {
      _audioService.togglePlayPause();
    } else {
      // If song is in list but context is different, switch context
      if (isCurrentSongInList) {
         final index = _songs.indexWhere((s) => s['song_id'] == currentSong!.id);
         if (index != -1) {
           _playSong(index);
           return;
         }
      }
      _playSong(0);
    }
  }

  void _playSong(int index) {
    // Convert map songs to SongModel list for AudioService
    final playlistSongs = _songs.map((s) {
      return SongModel({
        '_id': s['song_id'],
        'title': s['title'],
        'artist': s['artist'],
        'album': s['album'],
        'duration': s['duration'],
        '_data': s['data'],
        '_size': s['size'] ?? 0,
        '_display_name': s['display_name'] ?? s['title'],
      });
    }).toList();

    _audioService.setPlaylist(playlistSongs);
    _audioService.setPlaylistContext('playlist_${widget.playlist['id']}');

    final songToPlay = _songs[index];
    final globalIndex = _audioService.songs.indexWhere((s) => s.id == songToPlay['song_id']);
    
    if (globalIndex != -1) {
      _audioService.playSong(globalIndex);
      
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => PlayPage(songIndex: globalIndex),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutQuart;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
    }
  }

  void _showAddSongsDialog() async {
    final allSongs = _audioService.songs;
    final selectedSongs = <SongModel>[];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Agregar canciones'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: allSongs.length,
              itemBuilder: (context, index) {
                final song = allSongs[index];
                final isSelected = selectedSongs.contains(song);
                
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedSongs.add(song);
                      } else {
                        selectedSongs.remove(song);
                      }
                    });
                  },
                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(song.artist ?? 'Desconocido', maxLines: 1),
                  secondary: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: QueryArtworkWidget(
                      id: song.id,
                      type: ArtworkType.AUDIO,
                      artworkWidth: 40,
                      artworkHeight: 40,
                      nullArtworkWidget: Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey[300],
                        child: const Icon(Icons.music_note, size: 20),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selectedSongs.isEmpty
                  ? null
                  : () async {
                      for (var song in selectedSongs) {
                        await DatabaseHelper.instance.addSongToPlaylist(
                          widget.playlist['id'],
                          {
                            'song_id': song.id,
                            'title': song.title,
                            'artist': song.artist,
                            'album': song.album,
                            'data': song.data,
                            'duration': song.duration,
                          },
                        );
                      }
                      if (mounted) {
                        Navigator.pop(context);
                        _loadSongs();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ ${selectedSongs.length} ${selectedSongs.length == 1 ? 'canción agregada' : 'canciones agregadas'}'),
                            backgroundColor: const Color(0xFFE91E63),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
              child: Text('Agregar (${selectedSongs.length})'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ordenar por', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSortOption('Posición', 'position', Icons.reorder_rounded),
            _buildSortOption('Título', 'title', Icons.sort_by_alpha_rounded),
            _buildSortOption('Artista', 'artist', Icons.person_rounded),
            _buildSortOption('Duración', 'duration', Icons.timer_rounded),
            _buildSortOption('Fecha agregada', 'date', Icons.calendar_today_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFFE91E63) : null),
      title: Text(label, style: TextStyle(color: isSelected ? const Color(0xFFE91E63) : null)),
      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFE91E63)) : null,
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
        _loadSongs();
      },
    );
  }

  void _playAll() {
    _playPlaylist();
  }

  void _shufflePlay() async {
    await DatabaseHelper.instance.shufflePlaylist(widget.playlist['id']);
    await _loadSongs();
    if (_songs.isNotEmpty) {
      _playPlaylist();
    }
  }

  void _showPlaylistOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3D),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white10),
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
              _buildOptionTile(
                icon: Icons.play_arrow_rounded,
                title: "Reproducir Todo",
                onTap: () {
                  Navigator.pop(context);
                  _playAll();
                },
              ),
              _buildOptionTile(
                icon: Icons.shuffle_rounded,
                title: "Aleatorio",
                onTap: () {
                  Navigator.pop(context);
                  _shufflePlay();
                },
              ),
              _buildOptionTile(
                icon: Icons.edit_rounded,
                title: "Renombrar Playlist",
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog();
                },
              ),
              const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
              _buildOptionTile(
                icon: Icons.delete_outline_rounded,
                title: "Eliminar Playlist",
                color: const Color(0xFFE91E63),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: widget.playlist['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        title: const Text("Renombrar Playlist", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Nuevo nombre",
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
                await DatabaseHelper.instance.updatePlaylist(
                  widget.playlist['id'],
                  {'name': controller.text},
                );
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    widget.playlist['name'] = controller.text;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Playlist renombrada")),
                  );
                }
              }
            },
            child: const Text("Guardar", style: TextStyle(color: Color(0xFFE91E63))),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3D),
        title: const Text("Eliminar Playlist", style: TextStyle(color: Colors.white)),
        content: const Text(
          "¿Estás seguro de que deseas eliminar esta playlist?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deletePlaylist(widget.playlist['id']);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close detail page
              }
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  void _showSongOptions(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SongOptionsSheet(
        song: song,
        onPlay: () {
          // Find index in current list
          final index = _songs.indexWhere((s) => s['song_id'] == song.id);
          if (index != -1) _playSong(index);
        },
        deleteLabel: "Eliminar de playlist",
        deleteSubtitle: "Quitar canción de esta playlist",
        onDelete: () async {
           await DatabaseHelper.instance.removeSongFromPlaylist(
             widget.playlist['id'],
             song.id,
           );
           _loadSongs(); // Refresh list
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Canción eliminada de la playlist")),
             );
           }
        },
      ),
    );
  }
}
