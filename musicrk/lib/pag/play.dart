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
    if (widget.songIndex >= 0 && widget.songIndex < _audioService.songs.length) {
      _currentSong = _audioService.songs[widget.songIndex];
    }
    _initializePlayer();
    _checkFavorite();
  }

  Future<void> _initializePlayer() async {
    if (_audioService.currentIndex != widget.songIndex || !_audioService.isSongLoaded) {
      await _audioService.playSong(widget.songIndex);
    }
    
    if (mounted && !_isDismissed) {
      setState(() {
        _currentSong = _audioService.currentSong ?? _audioService.songs[widget.songIndex];
      });
    }

    _songSubscription = _audioService.currentSongStream.listen((song) {
      if (mounted && !_isDismissed && song != null) {
        setState(() => _currentSong = song);
        _checkFavorite();
      }
    });
  }

  @override
  void dispose() {
    _songSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkFavorite() async {
    if (_currentSong == null) return;
    final isFav = await DatabaseHelper.instance.isFavorite(_currentSong!.id);
    if (mounted) setState(() => _isFavorite = isFav);
  }

  Future<void> _toggleFavorite() async {
    if (_currentSong == null) return;
    if (_isFavorite) {
      await DatabaseHelper.instance.removeFavorite(_currentSong!.id);
    } else {
      await DatabaseHelper.instance.addFavorite({
        'song_id': _currentSong!.id,
        'title': _currentSong!.title,
        'artist': _currentSong!.artist,
        'album': _currentSong!.album,
        'data': _currentSong!.data,
        'duration': _currentSong!.duration,
      });
    }
    _checkFavorite();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();
    
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            // Swipe right -> Previous
            _audioService.playPrevious();
          } else if (details.primaryVelocity! < 0) {
            // Swipe left -> Next
            _audioService.playNext();
          }
        },
        child: Dismissible(
          key: const Key('play_page_dismiss'),
          direction: DismissDirection.down,
          onDismissed: (_) {
            _isDismissed = true;
            Navigator.pop(context);
          },
          child: Stack(
            children: [
              BackgroundArt(songId: _currentSong?.id, audioService: _audioService),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black26,
                        Colors.transparent,
                        Colors.black54,
                        Colors.black87,
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: isLandscape ? _buildLandscapeLayout(size) : _buildPortraitLayout(size, isTablet),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(Size size, bool isTablet) {
    return Column(
      children: [
        _buildTopBar(),
        const Spacer(),
        // Album Art
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? size.width * 0.2 : 40),
          child: AspectRatio(
            aspectRatio: 1,
            child: _currentSong != null 
              ? BigPlayerArt(songId: _currentSong!.id, audioService: _audioService)
              : const Icon(Icons.music_note, size: 100, color: Colors.white24),
          ),
        ),
        const Spacer(),
        _buildSongInfo(),
        _buildControlsSection(isTablet),
      ],
    );
  }

  Widget _buildLandscapeLayout(Size size) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: AspectRatio(
              aspectRatio: 1,
              child: _currentSong != null 
                ? BigPlayerArt(songId: _currentSong!.id, audioService: _audioService)
                : const Icon(Icons.music_note, size: 100, color: Colors.white24),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTopBar(),
              const Spacer(),
              _buildSongInfo(),
              _buildControlsSection(true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32), onPressed: () => Navigator.pop(context)),
          
          // Album Name in the middle
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "REPRODUCIENDO",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentSong?.album ?? "Álbum Desconocido",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white), 
            onPressed: () {
              if (_currentSong != null) {
                showModalBottomSheet(
                  context: context, 
                  backgroundColor: Colors.transparent, 
                  isScrollControlled: true,
                  builder: (context) => SongOptionsSheet(
                    song: _currentSong!,
                    isFavorite: _isFavorite,
                    onAddToFavorites: _toggleFavorite,
                    onRefresh: () {
                      if (mounted) {
                        setState(() {});
                        _checkFavorite();
                      }
                    },
                    onPlay: () => _audioService.play(),
                  )
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSongInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          Text(
            _currentSong?.title ?? 'Desconocido',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            _currentSong?.artist ?? 'Desconocido',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.7)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection(bool isTablet) {
    return Container(
      padding: EdgeInsets.fromLTRB(30, 20, 30, isTablet ? 40 : 20),
      child: Column(
        children: [
          _ProgressBar(audioService: _audioService),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              StreamBuilder<LoopMode>(
                stream: _audioService.loopModeStream,
                builder: (context, snapshot) {
                  final loopMode = snapshot.data ?? LoopMode.off;
                  return IconButton(
                    icon: Icon(loopMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, 
                    color: loopMode == LoopMode.off ? Colors.white38 : const Color(0xFFE91E63)),
                    onPressed: () => _audioService.toggleRepeatMode(),
                  );
                },
              ),
              IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 45, color: Colors.white), onPressed: () => _audioService.playPrevious()),
              _PlayPauseButton(audioService: _audioService),
              IconButton(icon: const Icon(Icons.skip_next_rounded, size: 45, color: Colors.white), onPressed: () => _audioService.playNext()),
              IconButton(
                icon: Icon(_isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                color: _isFavorite ? const Color(0xFFE91E63) : Colors.white38),
                onPressed: _toggleFavorite,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BigPlayerArt extends StatelessWidget {
  final int songId;
  final AudioService audioService;
  const BigPlayerArt({super.key, required this.songId, required this.audioService});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 40, offset: const Offset(0, 20))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: QueryArtworkWidget(
          id: songId,
          type: ArtworkType.AUDIO,
          artworkWidth: 500,
          artworkHeight: 500,
          nullArtworkWidget: Container(color: Colors.grey[900], child: const Icon(Icons.music_note, size: 100, color: Colors.white10)),
        ),
      ),
    );
  }
}

class BackgroundArt extends StatelessWidget {
  final int? songId;
  final AudioService audioService;
  const BackgroundArt({super.key, this.songId, required this.audioService});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (songId != null)
          Positioned.fill(
            child: QueryArtworkWidget(
              id: songId!,
              type: ArtworkType.AUDIO,
              artworkWidth: 100,
              artworkHeight: 100,
              artworkFit: BoxFit.cover,
              nullArtworkWidget: Container(color: const Color(0xFF1A1F3D)),
            ),
          ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
        ),
      ],
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
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  late StreamSubscription _pSub, _dSub;

  @override
  void initState() {
    super.initState();
    _pSub = widget.audioService.positionStream.listen((p) => setState(() => _pos = p));
    _dSub = widget.audioService.durationStream.listen((d) => setState(() => _dur = d ?? Duration.zero));
  }

  @override
  void dispose() { _pSub.cancel(); _dSub.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final total = _dur.inMilliseconds.toDouble();
    final current = _pos.inMilliseconds.toDouble().clamp(0.0, total > 0 ? total : 1.0);
    
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: current,
            max: total > 0 ? total : 1.0,
            onChanged: (v) => widget.audioService.seek(Duration(milliseconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(const Duration(milliseconds: 0) + _pos), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(_format(_dur), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  String _format(Duration d) => "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
}

class _PlayPauseButton extends StatelessWidget {
  final AudioService audioService;
  const _PlayPauseButton({required this.audioService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: audioService.playingStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;
        return GestureDetector(
          onTap: () => audioService.togglePlayPause(),
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.white24, blurRadius: 20)]),
            child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: const Color(0xFF1A1F3D), size: 45),
          ),
        );
      },
    );
  }
}
