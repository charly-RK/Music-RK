import 'dart:async';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_service.dart';
import '../pag/play.dart';

class BottomPlayer extends StatefulWidget {
  final AudioService audioService;
  final bool isPlaying;
  final SongModel? fallbackSong; // Show this when nothing is playing

  const BottomPlayer({
    super.key,
    required this.audioService,
    required this.isPlaying,
    this.fallbackSong,
  });

  @override
  State<BottomPlayer> createState() => _BottomPlayerState();
}

class _BottomPlayerState extends State<BottomPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  StreamSubscription? _playingSubscription;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _playingSubscription = widget.audioService.playingStream.listen((isPlaying) {
      if (mounted) {
        if (isPlaying) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      }
    });

    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(BottomPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _playingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use current song or fallback to first song
    final song = widget.audioService.currentSong ?? widget.fallbackSong;
    
    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => PlayPage(songIndex: widget.audioService.currentIndex),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeOutQuart;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
          ),
        );
      },
      child: Dismissible(
        key: Key(song.id.toString()),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await widget.audioService.playPrevious();
            return false;
          } else {
            await widget.audioService.playNext();
            return false;
          }
        },
        background: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Icon(Icons.skip_previous_rounded, color: Color(0xFFE91E63), size: 32),
        ),
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.skip_next_rounded, color: Color(0xFFE91E63), size: 32),
        ),
        child: Container(
          height: 80,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F3D),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background artwork with blur
                QueryArtworkWidget(
                  id: song.id,
                  type: ArtworkType.AUDIO,
                  artworkWidth: 100,
                  artworkHeight: 100,
                  artworkQuality: FilterQuality.low,
                  keepOldArtwork: true,
                  size: 200, // Optimized size for background
                  nullArtworkWidget: Container(color: const Color(0xFF1A1F3D)),
                  artworkFit: BoxFit.cover,
                  artworkBorder: BorderRadius.zero,
                ),
                // Dark overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.75),
                      ],
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Album Art
                      RotationTransition(
                        turns: _rotationController,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25), // Circular for rotation effect
                          child: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            artworkWidth: 50,
                            artworkHeight: 50,
                            artworkQuality: FilterQuality.low,
                            keepOldArtwork: true,
                            size: 100, // Optimized size for thumbnail
                            nullArtworkWidget: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.music_note, color: Colors.white54),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Song Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist ?? "Desconocido",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Play/Pause Button with Progress
                      StreamBuilder<Duration>(
                        stream: widget.audioService.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = widget.audioService.player.duration ?? Duration.zero;
                          double progress = 0.0;
                          if (duration.inMilliseconds > 0) {
                            progress = position.inMilliseconds / duration.inMilliseconds;
                            if (progress > 1.0) progress = 1.0;
                          }
                          return GestureDetector(
                            onTap: () => widget.audioService.togglePlayPause(),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 3,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)),
                                  ),
                                ),
                                Icon(
                                  widget.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                  color: const Color(0xFFE91E63),
                                  size: 40,
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
