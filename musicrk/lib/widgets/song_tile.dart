import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_service.dart';

class SongTile extends StatefulWidget {
  final SongModel song;
  final AudioService audioService;
  final bool isCurrentSong;
  final VoidCallback onTap;
  final VoidCallback onPlayTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOptionTap;

  const SongTile({
    super.key,
    required this.song,
    required this.audioService,
    required this.isCurrentSong,
    required this.onTap,
    required this.onPlayTap,
    this.onLongPress,
    this.onOptionTap,
  });

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.isCurrentSong;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // Reduced vertical margin
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: QueryArtworkWidget(
            id: widget.song.id,
            type: ArtworkType.AUDIO,
            artworkWidth: 45,
            artworkHeight: 45,
            artworkQuality: FilterQuality.low,
            keepOldArtwork: true,
            size: 100, // Optimized size
            nullArtworkWidget: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.music_note, color: Colors.grey[400]),
            ),
          ),
        ),
        title: Text(
          widget.song.title,
          style: TextStyle(
            fontSize: 15, 
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? theme.colorScheme.primary : const Color(0xFF2C3E50),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.song.artist ?? "Desconocido",
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? theme.colorScheme.primary.withOpacity(0.7) : Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(widget.song.duration ?? 0),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(Icons.graphic_eq, color: theme.colorScheme.primary, size: 20),
              ),
            if (widget.onOptionTap != null)
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                onPressed: widget.onOptionTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
          ],
        ),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
      ),
    );
  }
}
