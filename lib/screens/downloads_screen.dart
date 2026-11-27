import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song_model.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';

enum _SongSort {
  title('Título'),
  artist('Artista'),
  duration('Duración');

  final String label;
  const _SongSort(this.label);
}

/// Vista de todas las canciones de la biblioteca, filtrables por carpeta real
/// y ordenables por título, artista o duración.
class DownloadsScreen extends StatefulWidget {
  final double bottomInset;

  const DownloadsScreen({super.key, this.bottomInset = 80});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  String _selectedCategory = 'Todas';
  _SongSort _sortBy = _SongSort.title;

  @override
  Widget build(BuildContext context) {
    // Solo escucha la biblioteca: el reproductor se usa para acciones
    // (listen: false) y así reproducir/pausar no redibuja la pantalla.
    return Consumer<MusicStorageService>(
      builder: (context, storage, child) {
        final player = Provider.of<PlayerService>(context, listen: false);
        if (storage.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = <String>{};
        for (final song in storage.allSongs) {
          final category = song.category.trim();
          if (category.isNotEmpty) {
            categories.add(category);
          }
        }
        final sortedCategories = categories.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final chips = ['Todas', ...sortedCategories];

        final activeCategory =
            _selectedCategory == 'Todas' || categories.contains(_selectedCategory)
                ? _selectedCategory
                : 'Todas';

        var songs = List<Song>.from(storage.allSongs);
        if (activeCategory != 'Todas') {
          songs = songs
              .where((s) => s.category.trim() == activeCategory)
              .toList();
        }

        _sortSongs(songs);

        final countText =
            songs.length == 1 ? '1 canción' : '${songs.length} canciones';

        return RefreshIndicator(
          color: AppTheme.textPrimary,
          backgroundColor: AppTheme.surfaceHigh,
          onRefresh: () => storage.scanLibrary(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (chips.length > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AppTheme.space4,
                      bottom: AppTheme.space8,
                    ),
                    child: SizedBox(
                      height: AppTheme.chipHeight,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.pagePadding,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: chips.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppTheme.space8),
                        itemBuilder: (context, index) {
                          final cat = chips[index];
                          final isSelected = activeCategory == cat;
                          return _FilterChipButton(
                            label: cat,
                            selected: isSelected,
                            onTap: () => setState(() => _selectedCategory = cat),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space8,
                    0,
                    AppTheme.pagePadding,
                    AppTheme.space4,
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        onTap: () => _showSortModal(context),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppTheme.minTouch,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.sort_rounded,
                                  color: AppTheme.textPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: AppTheme.space8),
                                Text(_sortBy.label, style: AppTheme.label),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(countText, style: AppTheme.itemSubtitle),
                    ],
                  ),
                ),
              ),

              if (songs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppTheme.space24,
                        AppTheme.space24,
                        AppTheme.space24,
                        widget.bottomInset,
                      ),
                      child: Text(
                        storage.allSongs.isEmpty
                            ? 'No hay canciones en tu biblioteca'
                            : 'No hay canciones en esta carpeta',
                        textAlign: TextAlign.center,
                        style: AppTheme.itemSubtitle,
                      ),
                    ),
                  ),
                )
              else ...[
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songs[index];
                      return SongTile(
                        song: song,
                        onTap: () => player.playSong(song, playlist: songs),
                        onMore: () => _showSongMenu(context, song, storage),
                      );
                    },
                    childCount: songs.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: widget.bottomInset),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _sortSongs(List<Song> songs) {
    switch (_sortBy) {
      case _SongSort.title:
        songs.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _SongSort.artist:
        songs.sort((a, b) {
          if (a.hasKnownArtist != b.hasKnownArtist) {
            return a.hasKnownArtist ? -1 : 1;
          }
          return a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        });
      case _SongSort.duration:
        songs.sort((a, b) => b.duration.compareTo(a.duration));
    }
  }

  void _showSortModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.pagePadding),
                child: Text(
                  'Ordenar por',
                  style: AppTheme.itemTitle.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              for (final option in _SongSort.values)
                ListTile(
                  title: Text(option.label, style: AppTheme.itemTitle),
                  trailing: _sortBy == option
                      ? const Icon(Icons.check, color: AppTheme.textPrimary)
                      : null,
                  onTap: () {
                    setState(() => _sortBy = option);
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
      backgroundColor: AppTheme.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  song.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color:
                      song.isFavorite ? AppTheme.accent : AppTheme.textPrimary,
                ),
                title: Text(
                  song.isFavorite
                      ? 'Quitar de favoritos'
                      : 'Añadir a "Música que te gustó"',
                  style: AppTheme.itemTitle,
                ),
                onTap: () {
                  storage.toggleFavorite(song);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.folder_open,
                  color: AppTheme.textPrimary,
                ),
                title: const Text('Ruta de archivo', style: AppTheme.itemTitle),
                subtitle: Text(song.filePath, style: AppTheme.caption),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.textPrimary : AppTheme.chip,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: onTap,
        child: Container(
          height: AppTheme.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTheme.label.copyWith(
              color: selected ? AppTheme.bg : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
