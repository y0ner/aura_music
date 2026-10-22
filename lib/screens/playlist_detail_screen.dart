import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/player_service.dart';
import '../widgets/collage_cover.dart';
import '../widgets/explicit_badge.dart';
import '../widgets/mini_player.dart';
import '../widgets/fullscreen_player.dart';
import '../widgets/delete_dialogs.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  /// Menú por canción: reproducir ahora o eliminar del disco.
  void _showSongMenu(BuildContext context, Song song) {
    final player = Provider.of<PlayerService>(context, listen: false);
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 40,
                        height: 40,
                        color: const Color(0xFF222222),
                        child: song.artworkBytes != null
                            ? Image.memory(song.artworkBytes!, fit: BoxFit.cover)
                            : const Icon(Icons.music_note, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF333333)),
              ListTile(
                leading: const Icon(Icons.play_circle_fill, color: Colors.white),
                title: const Text('Reproducir', style: TextStyle(color: Colors.white)),
                onTap: () {
                  player.playSong(song, playlist: playlist.songs);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4040)),
                title: const Text(
                  'Eliminar canción',
                  style: TextStyle(color: Color(0xFFFF4040)),
                ),
                subtitle: const Text(
                  'Borra el archivo del disco',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  DeleteDialogs.confirmDeleteSong(context, song);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF030303),
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    backgroundColor: const Color(0xFF030303),
                    pinned: true,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        tooltip: 'Opciones de la playlist',
                        onPressed: () =>
                            DeleteDialogs.confirmDeletePlaylist(context, playlist),
                      ),
                    ],
                  ),

                  // Header with Cover Art, Title and Details
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: CollageCover(
                              playlist: playlist,
                              size: 210,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            playlist.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            playlist.subtitle,
                            style: const TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Play / Shuffle Actions Row
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                                label: const Text(
                                  'Reproducir',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  if (playlist.songs.isNotEmpty) {
                                    player.playSong(
                                      playlist.songs.first,
                                      playlist: playlist.songs,
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(
                                  Icons.shuffle_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                onPressed: () {
                                  if (playlist.songs.isNotEmpty) {
                                    if (!player.isShuffle) player.toggleShuffle();
                                    player.playSong(
                                      playlist.songs.first,
                                      playlist: playlist.songs,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: Color(0xFF222222)),
                        ],
                      ),
                    ),
                  ),

                  // Songs inside this playlist
                  if (playlist.songs.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No hay pistas en esta carpeta.\nCopia canciones (.mp3) dentro para verlas aquí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, height: 1.5),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = playlist.songs[index];
                          final isCurrent = player.currentSong?.id == song.id;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: 44,
                                height: 44,
                                color: const Color(0xFF222222),
                                child: song.artworkBytes != null
                                    ? Image.memory(
                                        song.artworkBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.music_note,
                                          color: Colors.white54,
                                        ),
                                      ),
                              ),
                            ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent ? const Color(0xFFFF4040) : Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                if (song.isExplicit) const ExplicitBadge(size: 12),
                                Expanded(
                                  child: Text(
                                    '${song.artist} • ${song.formattedDuration}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFAAAAAA),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: Color(0xFFAAAAAA),
                                size: 20,
                              ),
                              tooltip: 'Opciones de la canción',
                              onPressed: () =>
                                  _showSongMenu(context, song),
                            ),
                            onTap: () {
                              player.playSong(song, playlist: playlist.songs);
                            },
                          );
                        },
                        childCount: playlist.songs.length,
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 90),
                  ),
                ],
              ),

              // Mini Player
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: MiniPlayer(
                  onExpand: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: false,
                        pageBuilder: (context, animation, secondaryAnimation) => FullscreenPlayer(
                          onCollapse: () => Navigator.pop(context),
                        ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          const begin = Offset(0.0, 1.0);
                          const end = Offset.zero;
                          const curve = Curves.easeOutCubic;
                          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
