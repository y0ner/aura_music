import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import 'explicit_badge.dart';

class FullscreenPlayer extends StatefulWidget {
  final VoidCallback onCollapse;

  const FullscreenPlayer({super.key, required this.onCollapse});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  int _selectedBottomTab = 0; // 0: A continuación, 1: Letra, 2: Comentarios, 3: Similares
  double? _dragValue;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, child) {
        final song = player.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }

        final position = Duration(
          milliseconds: (_dragValue ?? player.position.inMilliseconds.toDouble()).toInt(),
        );
        final totalDuration = player.duration.inMilliseconds > 0
            ? player.duration
            : song.duration;

        return Scaffold(
          backgroundColor: const Color(0xFF030303),
          body: SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: widget.onCollapse,
                      ),
                      // Pill toggle: Canción | Video
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF212121),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (player.isVideoMode) player.toggleVideoSongMode();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: !player.isVideoMode
                                      ? const Color(0xFF383838)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Canción',
                                  style: TextStyle(
                                    color: !player.isVideoMode
                                        ? Colors.white
                                        : const Color(0xFFAAAAAA),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (!player.isVideoMode) player.toggleVideoSongMode();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: player.isVideoMode
                                      ? const Color(0xFF383838)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Video',
                                  style: TextStyle(
                                    color: player.isVideoMode
                                        ? Colors.white
                                        : const Color(0xFFAAAAAA),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => _showTrackOptionsMenu(context, song),
                      ),
                    ],
                  ),
                ),

                // Giant Album Artwork (Responsive)
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: song.artworkBytes != null
                                ? Image.memory(
                                    song.artworkBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: const Color(0xFF1F1F1F),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        const Icon(
                                          Icons.album_rounded,
                                          size: 110,
                                          color: Colors.white12,
                                        ),
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.graphic_eq_rounded,
                                              size: 48,
                                              color: Colors.white70,
                                            ),
                                            const SizedBox(height: 12),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
                                              child: Text(
                                                song.title,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Song Title and Artist Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (song.isExplicit) const ExplicitBadge(size: 14),
                          Expanded(
                            child: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFAAAAAA),
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Scrubber / Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: totalDuration.inMilliseconds.toDouble() > 0
                          ? totalDuration.inMilliseconds.toDouble()
                          : 1.0,
                      value: position.inMilliseconds
                          .toDouble()
                          .clamp(0.0, totalDuration.inMilliseconds.toDouble() > 0
                              ? totalDuration.inMilliseconds.toDouble()
                              : 1.0),
                      onChanged: (val) {
                        setState(() {
                          _dragValue = val;
                        });
                      },
                      onChangeEnd: (val) {
                        player.seek(Duration(milliseconds: val.toInt()));
                        setState(() {
                          _dragValue = null;
                        });
                      },
                    ),
                  ),
                ),

                // Timestamp labels
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDuration(totalDuration),
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Main Playback Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shuffle button
                      IconButton(
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: player.isShuffle ? Colors.white : Colors.white54,
                          size: 26,
                        ),
                        onPressed: () => player.toggleShuffle(),
                      ),

                      // Previous button
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                        onPressed: () => player.previous(),
                      ),

                      // Big White Circle Play/Pause Button (Matching screenshot 3 & 4)
                      GestureDetector(
                        onTap: () => player.togglePlayPause(),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 40,
                            ),
                          ),
                        ),
                      ),

                      // Next button
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                        onPressed: () => player.next(),
                      ),

                      // Repeat button
                      IconButton(
                        icon: Icon(
                          player.repeatMode == AudioRepeatMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: player.repeatMode != AudioRepeatMode.off
                              ? Colors.white
                              : Colors.white54,
                          size: 26,
                        ),
                        onPressed: () => player.toggleRepeat(),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Bottom Tabs: A continuación, Letra, Comentarios, Similares
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFF1E1E1E), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBottomTab(0, 'A continuación', isBold: true),
                      _buildBottomTab(1, 'Letra'),
                      _buildBottomTab(2, 'Comentarios'),
                      _buildBottomTab(3, 'Similares'),
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

  Widget _buildBottomTab(int index, String title, {bool isBold = false}) {
    final isSelected = _selectedBottomTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBottomTab = index;
        });
        _showBottomTabSheet(index, title);
      },
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFFAAAAAA),
          fontSize: 13.5,
          fontWeight: isSelected || isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  void _showBottomTabSheet(int index, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final player = Provider.of<PlayerService>(context, listen: false);
        return Container(
          padding: const EdgeInsets.all(16),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: index == 0
                    ? ListView.builder(
                        itemCount: player.queue.length,
                        itemBuilder: (context, i) {
                          final song = player.queue[i];
                          final isCurrent = i == player.currentIndex;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: 40,
                                height: 40,
                                color: const Color(0xFF2A2A2A),
                                child: song.artworkBytes != null
                                    ? Image.memory(song.artworkBytes!, fit: BoxFit.cover)
                                    : const Icon(Icons.music_note, color: Colors.white54),
                              ),
                            ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent ? AppTheme.redAccent : Colors.white,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              song.artist,
                              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                            ),
                            trailing: isCurrent
                                ? const Icon(Icons.volume_up_rounded, color: AppTheme.redAccent)
                                : null,
                            onTap: () {
                              player.playSong(song, playlist: player.queue);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          index == 1
                              ? 'Letra no disponible para esta canción local.'
                              : index == 2
                                  ? 'Comentarios no disponibles sin conexión.'
                                  : 'Reproduciendo desde tu carpeta local.',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTrackOptionsMenu(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.favorite_border, color: Colors.white),
                title: Text(
                  song.isFavorite ? 'Quitar de favoritos' : 'Añadir a "Música que te gustó"',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  song.isFavorite = !song.isFavorite;
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white),
                title: const Text('Añadir a playlist', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text('Detalles de la pista', style: TextStyle(color: Colors.white)),
                subtitle: Text(song.filePath, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}
