import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'cover_image.dart';
import '../models/playlist_model.dart';
import '../theme/app_theme.dart';

/// Carátula de playlist: degradado de marca para «Música que te gustó»,
/// collage 2 × 2 con 4 carátulas, imagen única con 1–3, o nota sobre
/// [AppTheme.surfaceHigh] si no hay ninguna.
class PlaylistArtwork extends StatelessWidget {
  final Playlist playlist;
  final double size;
  final double radius;

  const PlaylistArtwork({
    super.key,
    required this.playlist,
    required this.size,
    this.radius = AppTheme.radiusMedium,
  });

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: content,
    );

    if (size.isFinite) {
      return SizedBox(width: size, height: size, child: clipped);
    }
    return SizedBox.expand(child: clipped);
  }

  Widget _buildContent() {
    if (playlist.id == 'liked_songs_auto') {
      final iconSize = size.isFinite ? size * 0.48 : 64.0;
      return Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: Center(
          child: Icon(
            Icons.thumb_up,
            color: AppTheme.textPrimary,
            size: iconSize,
          ),
        ),
      );
    }

    final artworks = playlist.collageArtworks;
    if (artworks.length >= 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _artworkImage(artworks[0])),
                Expanded(child: _artworkImage(artworks[1])),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _artworkImage(artworks[2])),
                Expanded(child: _artworkImage(artworks[3])),
              ],
            ),
          ),
        ],
      );
    }

    if (artworks.isNotEmpty) {
      return _artworkImage(artworks.first);
    }

    final noteSize = size.isFinite ? size * 0.42 : 48.0;
    return ColoredBox(
      color: AppTheme.surfaceHigh,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppTheme.textSecondary,
          size: noteSize,
        ),
      ),
    );
  }

  Widget _artworkImage(Uint8List bytes) {
    return CoverImage(
      bytes,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
    );
  }
}

/// Tarjeta cuadrada de playlist usada en la cuadrícula de Biblioteca.
class CollageCover extends StatelessWidget {
  final Playlist playlist;
  final double size;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onMenuPressed;

  const CollageCover({
    super.key,
    required this.playlist,
    this.size = 170,
    this.onPlayPressed,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlaylistArtwork(
            playlist: playlist,
            size: size,
            radius: AppTheme.radiusMedium,
          ),
          if (onMenuPressed != null)
            Positioned(
              top: AppTheme.space4,
              right: AppTheme.space4,
              child: IconButton(
                onPressed: onMenuPressed,
                tooltip: 'Más opciones',
                icon: const Icon(
                  Icons.more_vert,
                  color: AppTheme.textPrimary,
                  size: 20,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                    ),
                  ],
                ),
                constraints: const BoxConstraints.tightFor(
                  width: AppTheme.minTouch,
                  height: AppTheme.minTouch,
                ),
              ),
            ),
          if (onPlayPressed != null)
            Positioned(
              bottom: AppTheme.space8,
              right: AppTheme.space8,
              child: Material(
                color: AppTheme.textPrimary,
                shape: const CircleBorder(),
                elevation: 4,
                child: IconButton(
                  onPressed: onPlayPressed,
                  tooltip: 'Reproducir',
                  color: AppTheme.bg,
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  constraints: const BoxConstraints.tightFor(
                    width: AppTheme.chipHeight,
                    height: AppTheme.chipHeight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
