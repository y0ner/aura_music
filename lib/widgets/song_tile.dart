import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'cover_image.dart';
import '../models/song_model.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import 'explicit_badge.dart';

/// Tres barritas rosas que marcan la canción que está sonando en ese momento.
class NowPlayingBars extends StatelessWidget {
  const NowPlayingBars({super.key});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusSmall / 2);
    return Semantics(
      label: 'Sonando ahora',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _bar(height: 10, radius: radius),
          const SizedBox(width: 3),
          _bar(height: 16, radius: radius),
          const SizedBox(width: 3),
          _bar(height: 7, radius: radius),
        ],
      ),
    );
  }

  Widget _bar({required double height, required BorderRadius radius}) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: radius,
      ),
    );
  }
}

/// Fila reutilizable de canción (64 px de alto, miniatura 48 px, acciones).
class SongTile extends StatelessWidget {
  static const double _rowHeight = 64;

  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final bool showDuration;
  final bool? isCurrent;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onMore,
    this.showDuration = true,
    this.isCurrent,
  });

  bool _isCurrentlyPlaying(BuildContext context) {
    if (isCurrent != null) return isCurrent!;
    try {
      return context.select<PlayerService, bool>(
        (player) => player.currentSong?.id == song.id,
      );
    } on ProviderNotFoundException catch (e) {
      debugPrint('SongTile sin PlayerService en el árbol: $e');
      return false;
    }
  }

  String _buildSubtitle() {
    if (!song.hasKnownArtist) {
      return song.formattedDuration;
    }
    return showDuration
        ? '${song.artist} · ${song.formattedDuration}'
        : song.artist;
  }

  @override
  Widget build(BuildContext context) {
    final active = _isCurrentlyPlaying(context);
    final hasArtwork = song.artworkBytes != null && song.artworkBytes!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _rowHeight,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.pagePadding,
            right: AppTheme.space4,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: SizedBox(
                  width: AppTheme.songThumb,
                  height: AppTheme.songThumb,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasArtwork)
                        CoverImage(
                          song.artworkBytes!,
                          width: AppTheme.songThumb,
                          height: AppTheme.songThumb,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      else
                        const ColoredBox(
                          color: AppTheme.surfaceHigh,
                          child: Center(
                            child: Icon(
                              Icons.music_note_rounded,
                              color: AppTheme.textSecondary,
                              size: 24,
                            ),
                          ),
                        ),
                      if (active)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: const Center(child: NowPlayingBars()),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.itemTitle,
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Row(
                      children: [
                        if (song.isExplicit) const ExplicitBadge(size: 16),
                        Expanded(
                          child: Text(
                            _buildSubtitle(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.itemSubtitle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMore,
                tooltip: 'Más opciones',
                icon: const Icon(
                  Icons.more_vert,
                  color: AppTheme.textPrimary,
                  size: 20,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: AppTheme.minTouch,
                  height: AppTheme.minTouch,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
