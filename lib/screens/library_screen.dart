import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist_model.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/collage_cover.dart';
import '../widgets/delete_dialogs.dart';
import 'downloads_screen.dart';
import 'playlist_detail_screen.dart';

/// Pantalla Biblioteca: playlists (lista o cuadrícula) y todas las canciones.
class LibraryScreen extends StatefulWidget {
  final VoidCallback? onSearch;
  final VoidCallback? onCreatePlaylist;
  final double bottomInset;

  const LibraryScreen({
    super.key,
    this.onSearch,
    this.onCreatePlaylist,
    this.bottomInset = 80,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const double _playlistRowHeight = 72;

  int _selectedSection = 0; // 0: Playlists, 1: Canciones
  bool _sortByCount = false;
  bool _isGrid = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<MusicStorageService, PlayerService>(
      builder: (context, storage, player, child) {
        return ColoredBox(
          color: AppTheme.bg,
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(storage),
                    _buildSectionChips(),
                    Expanded(
                      child: storage.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _selectedSection == 0
                              ? _buildPlaylistsContent(context, storage, player)
                              : DownloadsScreen(bottomInset: widget.bottomInset),
                    ),
                  ],
                ),
              ),
              if (widget.onCreatePlaylist != null)
                Positioned(
                  right: AppTheme.pagePadding,
                  bottom: widget.bottomInset + AppTheme.space16,
                  child: SizedBox(
                    height: AppTheme.minTouch,
                    child: FloatingActionButton.extended(
                      onPressed: widget.onCreatePlaylist,
                      backgroundColor: AppTheme.textPrimary,
                      foregroundColor: AppTheme.bg,
                      shape: const StadiumBorder(),
                      icon: const Icon(Icons.add),
                      label: Text(
                        'Nueva playlist',
                        style: AppTheme.label.copyWith(color: AppTheme.bg),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(MusicStorageService storage) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.pagePadding,
        AppTheme.space8,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Biblioteca', style: AppTheme.titleLarge),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onSearch != null)
                IconButton(
                  onPressed: widget.onSearch,
                  tooltip: 'Buscar en la biblioteca',
                  icon: const Icon(
                    Icons.search,
                    color: AppTheme.textPrimary,
                  ),
                  constraints: const BoxConstraints.tightFor(
                    width: AppTheme.minTouch,
                    height: AppTheme.minTouch,
                  ),
                ),
              IconButton(
                onPressed: () => storage.scanLibrary(),
                tooltip: 'Actualizar biblioteca',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.textPrimary,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: AppTheme.minTouch,
                  height: AppTheme.minTouch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pagePadding,
        vertical: AppTheme.space12,
      ),
      child: Row(
        children: [
          _SectionChip(
            label: 'Playlists',
            selected: _selectedSection == 0,
            onTap: () => setState(() => _selectedSection = 0),
          ),
          const SizedBox(width: AppTheme.space8),
          _SectionChip(
            label: 'Canciones',
            selected: _selectedSection == 1,
            onTap: () => setState(() => _selectedSection = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsContent(
    BuildContext context,
    MusicStorageService storage,
    PlayerService player,
  ) {
    final likedSongs = storage.likedSongsPlaylist ??
        Playlist(
          id: 'liked_songs_auto',
          name: 'Música que te gustó',
          folderPath: '',
          songs: [],
          isAutoGenerated: true,
        );

    final userPlaylists = List<Playlist>.from(storage.playlists);
    if (_sortByCount) {
      userPlaylists.sort((a, b) {
        final byCount = b.songs.length.compareTo(a.songs.length);
        if (byCount != 0) return byCount;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    } else {
      userPlaylists.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    final allPlaylists = [likedSongs, ...userPlaylists];

    return RefreshIndicator(
      color: AppTheme.textPrimary,
      backgroundColor: AppTheme.surfaceHigh,
      onRefresh: () => storage.scanLibrary(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space8,
                0,
                AppTheme.space4,
                AppTheme.space4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    onTap: () => setState(() => _sortByCount = !_sortByCount),
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
                            Text(
                              _sortByCount ? 'Más canciones' : 'Nombre',
                              style: AppTheme.label,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _isGrid = !_isGrid),
                    tooltip: _isGrid ? 'Ver como lista' : 'Ver como cuadrícula',
                    icon: Icon(
                      _isGrid
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      color: AppTheme.textPrimary,
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

          if (_isGrid)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pagePadding,
                vertical: AppTheme.space12,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppTheme.space12,
                  mainAxisSpacing: AppTheme.space16,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildGridItem(
                    context,
                    playlist: allPlaylists[index],
                    player: player,
                    storage: storage,
                  ),
                  childCount: allPlaylists.length,
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildListItem(
                  context,
                  playlist: allPlaylists[index],
                  storage: storage,
                ),
                childCount: allPlaylists.length,
              ),
            ),

          SliverToBoxAdapter(
            child: SizedBox(height: widget.bottomInset),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context, {
    required Playlist playlist,
    required MusicStorageService storage,
  }) {
    final isLiked = playlist.id == 'liked_songs_auto';
    return InkWell(
      onTap: () => _openPlaylist(context, playlist),
      child: SizedBox(
        height: _playlistRowHeight,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppTheme.pagePadding,
            right: isLiked ? AppTheme.pagePadding : AppTheme.space4,
          ),
          child: Row(
            children: [
              PlaylistArtwork(
                playlist: playlist,
                size: AppTheme.playlistThumb,
                radius: AppTheme.radiusMedium,
              ),
              const SizedBox(width: AppTheme.space16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.itemTitle,
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Row(
                      children: [
                        if (isLiked) ...[
                          const Icon(
                            Icons.push_pin,
                            size: 14,
                            color: AppTheme.textSecondary,
                            semanticLabel: 'Fijada',
                          ),
                          const SizedBox(width: AppTheme.space4),
                        ],
                        Expanded(
                          child: Text(
                            playlist.subtitle,
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
              if (!isLiked)
                IconButton(
                  onPressed: () =>
                      _showPlaylistMenu(context, playlist, storage),
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

  Widget _buildGridItem(
    BuildContext context, {
    required Playlist playlist,
    required PlayerService player,
    required MusicStorageService storage,
  }) {
    final isLiked = playlist.id == 'liked_songs_auto';
    return GestureDetector(
      onTap: () => _openPlaylist(context, playlist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: CollageCover(
              playlist: playlist,
              size: double.infinity,
              onPlayPressed: playlist.songs.isEmpty
                  ? null
                  : () => player.playSong(
                        playlist.songs.first,
                        playlist: playlist.songs,
                      ),
              onMenuPressed: isLiked
                  ? null
                  : () => _showPlaylistMenu(context, playlist, storage),
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.itemTitle,
          ),
          const SizedBox(height: AppTheme.space4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLiked) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.push_pin,
                    size: 14,
                    color: AppTheme.textSecondary,
                    semanticLabel: 'Fijada',
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
              ],
              Expanded(
                child: Text(
                  playlist.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.itemSubtitle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openPlaylist(BuildContext context, Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  void _showPlaylistMenu(
    BuildContext context,
    Playlist playlist,
    MusicStorageService storage,
  ) {
    final isAuto =
        playlist.isAutoGenerated || playlist.id == 'liked_songs_auto';
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
                leading: const Icon(
                  Icons.play_circle_fill,
                  color: AppTheme.textPrimary,
                ),
                title: const Text(
                  'Reproducir playlist',
                  style: AppTheme.itemTitle,
                ),
                onTap: () {
                  final player = Provider.of<PlayerService>(
                    context,
                    listen: false,
                  );
                  if (playlist.songs.isNotEmpty) {
                    player.playSong(
                      playlist.songs.first,
                      playlist: playlist.songs,
                    );
                  }
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.folder_open,
                  color: AppTheme.textPrimary,
                ),
                title: const Text(
                  'Ubicación de la carpeta',
                  style: AppTheme.itemTitle,
                ),
                subtitle: Text(playlist.folderPath, style: AppTheme.caption),
                onTap: () => Navigator.pop(ctx),
              ),
              if (!isAuto) ...[
                const Divider(color: AppTheme.outline),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.danger,
                  ),
                  title: Text(
                    'Eliminar álbum',
                    style: AppTheme.itemTitle.copyWith(color: AppTheme.danger),
                  ),
                  subtitle: const Text(
                    'Borra la carpeta y todas sus canciones del disco',
                    style: AppTheme.caption,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    DeleteDialogs.confirmDeletePlaylist(context, playlist);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SectionChip({
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
