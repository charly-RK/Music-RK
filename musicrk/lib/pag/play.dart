import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_service.dart';

import '../services/database_helper.dart';
import '../widgets/song_options_sheet.dart';

class PlayPage extends StatefulWidget {
  final int songIndex;
  
  const PlayPage({super.key, required this.songIndex});

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  final AudioService _audioService = AudioService();
  SongModel? _currentSong;
  bool _isDismissed = false;
  bool _isFavorite = false;
  StreamSubscription? _songSubscription;

  @override
  void initState() {
    super.initState();
    // Inicializar datos inmediatamente para la interfaz de usuario
    if (widget.songIndex >= 0 && widget.songIndex < _audioService.songs.length) {
      _currentSong = _audioService.songs[widget.songIndex];
    }
    _initializePlayer();
    _checkFavorite();
  }

  Future<void> _initializePlayer() async {
    // Inicializar el reproductor y actualizar la interfaz de usuario en un solo paso si es posible
    if (_audioService.currentIndex != widget.songIndex || !_audioService.isSongLoaded) {
      await _audioService.playSong(widget.songIndex);
    }
    
    if (mounted && !_isDismissed) {
      setState(() {
        _currentSong = _audioService.currentSong ?? _audioService.songs[widget.songIndex];
      });
    }

    _songSubscription = _audioService.currentSongStream.listen((_) {
      if (mounted && !_isDismissed) {
        setState(() {
          _currentSong = _audioService.currentSong;
        });
        _checkFavorite();
      }
    });
  }

  @override
  void dispose() {
    _songSubscription?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _getDisplayAlbum() {
    if (_currentSong == null) return 'Desconocido';
    
    String? album = _currentSong!.album;
    if (album != null && 
        album != '<unknown>' && 
        album != 'Desconocido' && 
        album.isNotEmpty) {
      return album;
    }

    // Intentar obtener el nombre de la carpeta
    try {
      final path = _currentSong!.data;
      final parts = path.split('/');
      if (parts.length > 1) {
        return parts[parts.length - 2]; // Carpeta principal
      }
    } catch (e) {
      // ignorar
    }
    
    return 'Carpeta Desconocida';
  }

  Future<void> _checkFavorite() async {
    if (_currentSong == null) return;
    final isFav = await DatabaseHelper.instance.isFavorite(_currentSong!.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentSong == null) return;
    
    if (_isFavorite) {
      await DatabaseHelper.instance.removeFavorite(_currentSong!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Eliminado de favoritos")),
        );
      }
    } else {
      await DatabaseHelper.instance.addFavorite({
        'song_id': _currentSong!.id,
        'title': _currentSong!.title,
        'artist': _currentSong!.artist,
        'album': _currentSong!.album,
        'data': _currentSong!.data,
        'duration': _currentSong!.duration,
      });
      if (mounted) {
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
    _checkFavorite();
  }

  void _showOptions() {
    if (_currentSong == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SongOptionsSheet(
        song: _currentSong!,
        isFavorite: _isFavorite,
        onAddToFavorites: _toggleFavorite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prevenir reconstrucción si ya se ha descartado
    if (_isDismissed) {
      return const SizedBox.shrink();
    }
    
    final String title = _currentSong?.title ?? 'Desconocido';
    final String artist = _currentSong?.artist ?? 'Desconocido';
    final String displayAlbum = _getDisplayAlbum();
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Dismissible(
        key: const Key('play_page_dismiss'),
        direction: DismissDirection.down,
        onDismissed: (_) {
          _isDismissed = true;
          // Retrasar la eliminación para evitar bloquear los eventos táctiles
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        },
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            // Detección de deslizamiento
            if (details.primaryVelocity! > 500) {
              // Deslizamiento derecho -> Canción anterior
              _audioService.playPrevious();
            } else if (details.primaryVelocity! < -500) {
              // Deslizamiento izquierdo -> Siguiente canción
              _audioService.playNext();
            }
          },
          child: Stack(
            children: [
              // --- Fondo Desenfocado ---
              BackgroundArt(
                songId: _currentSong?.id,
                audioService: _audioService,
              ),
              
              // --- Gradiente de Legibilidad ---
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.4, 0.8, 1.0],
                    ),
                  ),
                ),
              ),

              // --- Contenido Principal ---
              SafeArea(
                child: Column(
                  children: [
                    // Barra Superior
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 24),
                              onPressed: () => Navigator.pop(context),
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
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                              onPressed: _showOptions,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Arte del Álbum
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(30.0),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _currentSong != null
                                ? BigPlayerArt(
                                    songId: _currentSong!.id,
                                    audioService: _audioService,
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      color: Colors.grey[900],
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 30,
                                          offset: const Offset(0, 20),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.music_note, size: 80, color: Colors.white24),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Sección de Letras
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                      child: Text(
                        _currentSong?.album ?? 'Desconocido',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Letras / Espacio
                    const Spacer(),
                  
                  // Información de Canción y Controles
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Canción
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 2)),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                              StreamBuilder<LoopMode>(
                                stream: _audioService.loopModeStream,
                                builder: (context, snapshot) {
                                  final loopMode = snapshot.data ?? LoopMode.off;
                                  final icon = loopMode == LoopMode.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded;
                                  final color = loopMode == LoopMode.off
                                      ? Colors.white.withOpacity(0.4)
                                      : const Color(0xFFE91E63);
                                  
                                  return IconButton(
                                    icon: Icon(icon, color: color, size: 28),
                                    onPressed: () => _audioService.toggleRepeatMode(),
                                  );
                                },
                              ),
                            IconButton(
                              icon: Icon(
                                _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _isFavorite ? const Color(0xFFE91E63) : Colors.white.withOpacity(0.4),
                                size: 28,
                              ),
                              onPressed: _toggleFavorite,
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        
                        // Barra de Progreso Autónoma
                        _ProgressBar(audioService: _audioService),
                        
                        const SizedBox(height: 20),
                        
                        // Controles de Reproducción
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded, size: 42),
                              color: Colors.white,
                              onPressed: () => _audioService.playPrevious(),
                            ),
                            _PlayPauseButton(audioService: _audioService),
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, size: 42),
                              color: Colors.white,
                              onPressed: () => _audioService.playNext(),
                            ),
                          ],
                        ),
                      ],
                    ),
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
}

class BigPlayerArt extends StatefulWidget {
  final int songId;
  final AudioService audioService;

  const BigPlayerArt({
    super.key,
    required this.songId,
    required this.audioService,
  });

  @override
  State<BigPlayerArt> createState() => _BigPlayerArtState();
}

class _BigPlayerArtState extends State<BigPlayerArt> {
  ImageProvider? _artImage;

  @override
  void initState() {
    super.initState();
    _loadArt();
  }

  @override
  void didUpdateWidget(BigPlayerArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) {
      _loadArt();
    }
  }

  Future<void> _loadArt() async {
    // Optimizado: Cargar a 300x300 para mejor rendimiento
    final art = await widget.audioService.getAlbumArt(widget.songId, size: 300);
    if (mounted) {
      setState(() {
        if (art != null) {
          _artImage = ResizeImage(
            MemoryImage(Uint8List.fromList(art)),
            width: 300,
            height: 300,
          );
        } else {
          _artImage = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Eliminado ancho/alto fijo para permitir la capacidad de respuesta
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        image: _artImage != null
            ? DecorationImage(
                image: _artImage!,
                fit: BoxFit.cover,
              )
            : const DecorationImage(
                image: AssetImage('assets/images/carpeta_2.jpg'),
                fit: BoxFit.cover,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
    );
  }
}

class BackgroundArt extends StatefulWidget {
  final int? songId;
  final AudioService audioService;

  const BackgroundArt({
    super.key,
    required this.songId,
    required this.audioService,
  });

  @override
  State<BackgroundArt> createState() => _BackgroundArtState();
}

class _BackgroundArtState extends State<BackgroundArt> {
  ImageProvider? _artImage;

  @override
  void initState() {
    super.initState();
    _loadArt();
  }

  @override
  void didUpdateWidget(BackgroundArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) {
      _loadArt();
    }
  }

  Future<void> _loadArt() async {
    if (widget.songId == null) {
      if (mounted) setState(() => _artImage = null);
      return;
    }
    
    // Optimizado: Cargar imagen más pequeña para el fondo ya que está difuminada
    final art = await widget.audioService.getAlbumArt(widget.songId!, size: 200);
    if (mounted) {
      setState(() {
        if (art != null) {
          _artImage = MemoryImage(Uint8List.fromList(art));
        } else {
          _artImage = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: _artImage ?? const AssetImage('assets/images/carpeta_2.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.1),
                Colors.white.withOpacity(0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatefulWidget {
  final AudioService audioService;
  const _ProgressBar({required this.audioService});
  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  late StreamSubscription _posSub;
  late StreamSubscription _durSub;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.audioService.player.position;
    _totalDuration = widget.audioService.player.duration ?? Duration.zero;
    _posSub = widget.audioService.positionStream.listen((p) {
      if (mounted) setState(() => _currentPosition = p);
    });
    _durSub = widget.audioService.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _totalDuration = d);
    });
  }

  @override
  void dispose() { 
    _posSub.cancel(); 
    _durSub.cancel(); 
    super.dispose(); 
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            trackHeight: 4,
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: _totalDuration.inMilliseconds > 0
                ? _currentPosition.inMilliseconds.toDouble().clamp(0, _totalDuration.inMilliseconds.toDouble())
                : 0,
            max: _totalDuration.inMilliseconds.toDouble() > 0
                ? _totalDuration.inMilliseconds.toDouble()
                : 1,
            onChanged: (value) {
              widget.audioService.seek(Duration(milliseconds: value.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500),
              ),
              Text(
                _formatDuration(_totalDuration),
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final AudioService audioService;
  const _PlayPauseButton({required this.audioService});
  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _isPlaying = false;
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.audioService.player.playing;
    _sub = widget.audioService.playingStream.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
  }

  @override
  void dispose() { 
    _sub.cancel(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await widget.audioService.togglePlayPause();
      },
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: const Color(0xFF1A1F3D),
          size: 38,
        ),
      ),
    );
  }
}
