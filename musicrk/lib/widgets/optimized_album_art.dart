import 'dart:io';
import 'package:flutter/material.dart';

/// Widget optimizado para mostrar carátulas de álbumes/canciones
/// Reduce lag mediante caché de imágenes y tamaño optimizado
class OptimizedAlbumArt extends StatelessWidget {
  final String? artworkPath;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const OptimizedAlbumArt({
    super.key,
    this.artworkPath,
    this.size = 50,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final Widget fallbackIcon = Icon(
      Icons.music_note,
      size: size * 0.6,
      color: Colors.white70,
    );

    if (artworkPath == null || artworkPath!.isEmpty) {
      return _buildContainer(fallbackIcon);
    }

    final file = File(artworkPath!);
    if (!file.existsSync()) {
      return _buildContainer(fallbackIcon);
    }

    return _buildContainer(
      Image.file(
        file,
        // Optimización clave: limitar tamaño en memoria (2x para pantallas HD)
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        fit: fit,
        errorBuilder: (_, __, ___) => fallbackIcon,
        // Evitar reconstrucciones innecesarias
        gaplessPlayback: true,
      ),
    );
  }

  Widget _buildContainer(Widget child) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
