import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import 'explicit_badge.dart';

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

        return GestureDetector(
          onTap: onExpand,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 62,
            decoration: const BoxDecoration(
              color: Color(0xFF212121),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Top Progress Indicator Line
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 2,
                  child: LinearProgressIndicator(
                    value: player.progressRatio,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),

                // Main Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // Song Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 44,
                          height: 44,
                          color: const Color(0xFF2A2A2A),
                          child: currentSong.artworkBytes != null
                              ? Image.memory(
                                  currentSong.artworkBytes!,
                                  fit: BoxFit.cover,
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.music_note,
                                    color: Colors.white54,
                                    size: 24,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title and Artist Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (currentSong.isExplicit) ...[
                                  const ExplicitBadge(size: 13),
                                ],
                                Expanded(
                                  child: Text(
                                    player.playbackError ?? currentSong.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFAAAAAA),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Previous button (escritorio: en Android/iOS va en la
                      // notificación, así que aquí solo se muestra en PC).
                      if (!(Platform.isAndroid || Platform.isIOS))
                        IconButton(
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: () => player.previous(),
                          splashRadius: 22,
                        ),

                      // Play/Pause Button
                      IconButton(
                        icon: Icon(
                          player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () => player.togglePlayPause(),
                        splashRadius: 22,
                      ),

                      // Skip Next Button
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () => player.next(),
                        splashRadius: 22,
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
