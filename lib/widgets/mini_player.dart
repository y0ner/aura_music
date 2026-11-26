import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../theme/app_theme.dart';
import 'explicit_badge.dart';

const double _miniPlayerThumbSize = 44;

class MiniPlayer extends StatelessWidget {
  final VoidCallback onExpand;

  const MiniPlayer({super.key, required this.onExpand});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, child) {
        final currentSong = player.currentSong;
        if (currentSong == null) {
          return const SizedBox.shrink();
        }

        final subtitle = player.playbackError ??
            (currentSong.hasKnownArtist
                ? currentSong.artist
                : currentSong.formattedDuration);

        return GestureDetector(
          onTap: onExpand,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: AppTheme.miniPlayerHeight,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: AppTheme.space8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 2,
                  child: LinearProgressIndicator(
                    value: player.progressRatio,
                    backgroundColor: AppTheme.outline,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.accent,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppTheme.space12,
                    right: AppTheme.space4,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                        child: Container(
                          width: _miniPlayerThumbSize,
                          height: _miniPlayerThumbSize,
                          color: AppTheme.chip,
                          child: currentSong.artworkBytes != null
                              ? Image.memory(
                                  currentSong.artworkBytes!,
                                  fit: BoxFit.cover,
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    color: AppTheme.textSecondary,
                                    size: 24,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.itemTitle,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (currentSong.isExplicit)
                                  const ExplicitBadge(size: 13),
                                Expanded(
                                  child: Text(
                                    subtitle,
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
                      // En escritorio el control anterior vive aquí porque no
                      // hay sombra de notificación móvil como en Android/iOS.
                      if (!(Platform.isAndroid || Platform.isIOS))
                        IconButton(
                          tooltip: 'Anterior',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: AppTheme.minTouch,
                            height: AppTheme.minTouch,
                          ),
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            color: AppTheme.textPrimary,
                            size: 28,
                          ),
                          onPressed: player.previous,
                        ),
                      IconButton(
                        tooltip: player.isPlaying ? 'Pausar' : 'Reproducir',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: AppTheme.minTouch,
                          height: AppTheme.minTouch,
                        ),
                        icon: Icon(
                          player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppTheme.textPrimary,
                          size: 28,
                        ),
                        onPressed: player.togglePlayPause,
                      ),
                      IconButton(
                        tooltip: 'Siguiente',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: AppTheme.minTouch,
                          height: AppTheme.minTouch,
                        ),
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: AppTheme.textPrimary,
                          size: 28,
                        ),
                        onPressed: player.next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
