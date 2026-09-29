import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/player_service.dart';
import '../models/song_model.dart';
import '../widgets/explicit_badge.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  String _selectedCategory = 'Todos';
  String _sortBy = 'title'; // 'title', 'artist', 'duration'

  final List<String> _categories = [
    'Todos',
    'Fiesta',
    'Romance',
    'Entrenamiento',
    'Danza',
    'Trap',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer2<MusicStorageService, PlayerService>(
      builder: (context, storage, player, child) {
        if (storage.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        List<Song> songs = List.from(storage.allSongs);

        // Filter by category
        if (_selectedCategory != 'Todos') {
          songs = songs.where((s) {
            return s.category.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
                   s.album.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
                   s.title.toLowerCase().contains(_selectedCategory.toLowerCase());
          }).toList();
        }

        // Sort songs
        if (_sortBy == 'title') {
          songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        } else if (_sortBy == 'artist') {
          songs.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        } else if (_sortBy == 'duration') {
          songs.sort((a, b) => b.duration.compareTo(a.duration));
        }

        return RefreshIndicator(
          color: Colors.white,
          backgroundColor: const Color(0xFF212121),
          onRefresh: () => storage.scanLibrary(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Filter Chips (Fiesta, Romance, Entrenamiento, etc.)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF212121),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF333333),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Sort Section Header ("≡ Ordenar")
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showSortModal(context),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: const [
                            Icon(Icons.sort_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Ordenar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${songs.length} pistas',
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Songs List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = songs[index];
                    final isCurrent = player.currentSong?.id == song.id;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 48,
                          height: 48,
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
                                    size: 26,
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
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            if (song.isExplicit) const ExplicitBadge(size: 13),
                            Expanded(
                              child: Text(
                                '${song.artist} • ${song.formattedDuration}',
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
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Color(0xFFAAAAAA),
                          size: 20,
                        ),
                        onPressed: () => _showSongMenu(context, song, storage),
                        splashRadius: 18,
                      ),
                      onTap: () {
                        player.playSong(song, playlist: songs);
                      },
                    );
                  },
                  childCount: songs.length,
                ),
              ),

              // Bottom spacing for mini player
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSortModal(BuildContext context) {
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Ordenar por',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Título', style: TextStyle(color: Colors.white)),
                trailing: _sortBy == 'title' ? const Icon(Icons.check, color: Colors.white) : null,
                onTap: () {
                  setState(() => _sortBy = 'title');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('Artista', style: TextStyle(color: Colors.white)),
                trailing: _sortBy == 'artist' ? const Icon(Icons.check, color: Colors.white) : null,
                onTap: () {
                  setState(() => _sortBy = 'artist');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('Duración', style: TextStyle(color: Colors.white)),
                trailing: _sortBy == 'duration' ? const Icon(Icons.check, color: Colors.white) : null,
                onTap: () {
                  setState(() => _sortBy = 'duration');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSongMenu(
    BuildContext context,
    Song song,
    MusicStorageService storage,
  ) {
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
                leading: Icon(
                  song.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: song.isFavorite ? const Color(0xFFFF4081) : Colors.white,
                ),
                title: Text(
                  song.isFavorite ? 'Quitar de favoritos' : 'Añadir a "Música que te gustó"',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  storage.toggleFavorite(song);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open, color: Colors.white),
                title: const Text('Ruta de archivo', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  song.filePath,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}
