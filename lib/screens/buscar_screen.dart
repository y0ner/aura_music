import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/collage_cover.dart';
import '../widgets/delete_dialogs.dart';
import '../widgets/song_tile.dart';
import 'playlist_detail_screen.dart';

/// Pantalla Buscar con historial reciente, exploración y resultados locales.
class BuscarScreen extends StatefulWidget {
  const BuscarScreen({super.key});

  @override
  State<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends State<BuscarScreen> {
  static const double _searchFieldHeight = 52;
  static const double _recentThumbSize = 104;
  static const double _exploreMinHeight = 112;
  static const double _playlistRowHeight = 72;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setQueryText(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {});
  }

  void _submitSearch(MusicStorageService storage, String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    storage.addSearch(query);
  }

  void _applyRecentSearch(MusicStorageService storage, String query) {
    _setQueryText(query);
    storage.addSearch(query);
    _focusNode.unfocus();
  }

  void _fillFromRecent(String query) {
    _setQueryText(query);
    _focusNode.requestFocus();
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {});
  }

  void _openPlaylist(BuildContext context, Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MusicStorageService, PlayerService>(
      builder: (context, storage, player, child) {
        final query = _controller.text.trim();

        return ColoredBox(
          color: AppTheme.bg,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildSearchField(storage),
                Expanded(
                  child: query.isEmpty
                      ? _buildDiscoverBody(context, storage, player)
                      : _buildResultsBody(context, storage, player, query),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField(MusicStorageService storage) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.pagePadding,
        AppTheme.pagePadding,
        AppTheme.space8,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: _searchFieldHeight),
        decoration: const ShapeDecoration(
          color: AppTheme.surfaceHigh,
          shape: StadiumBorder(),
        ),
        padding: const EdgeInsets.only(
          left: AppTheme.pagePadding,
          right: AppTheme.space4,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search,
              color: AppTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (value) => _submitSearch(storage, value),
                style: AppTheme.itemTitle.copyWith(fontWeight: FontWeight.w400),
                decoration: InputDecoration(
                  hintText: 'Canciones, artistas, playlists…',
                  hintStyle: AppTheme.itemTitle.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppTheme.space12,
                  ),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                onPressed: _clearSearch,
                tooltip: 'Borrar búsqueda',
                icon: const Icon(
                  Icons.close,
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
    );
  }

  Widget _buildDiscoverBody(
    BuildContext context,
    MusicStorageService storage,
    PlayerService player,
  ) {
    final recentSongs = storage.recentlyPlayed;
    final recentSearches = storage.recentSearches;

    final exploreItems = <({String title, IconData icon, Playlist playlist})>[];
    final recentlyAdded = storage.autoPlaylist(AutoPlaylistKind.recentlyAdded);
    if (recentlyAdded != null && recentlyAdded.songs.isNotEmpty) {
      exploreItems.add((
        title: 'Recién añadidas',
        icon: Icons.schedule_rounded,
        playlist: recentlyAdded,
      ));
    }
    final mostPlayed = storage.autoPlaylist(AutoPlaylistKind.mostPlayed);
    if (mostPlayed != null && mostPlayed.songs.isNotEmpty) {
      exploreItems.add((
        title: 'Más escuchadas',
        icon: Icons.trending_up_rounded,
        playlist: mostPlayed,
      ));
    }
    final liked = storage.likedSongsPlaylist;
    if (liked != null && liked.songs.isNotEmpty) {
      exploreItems.add((
        title: 'Música que te gustó',
        icon: Icons.thumb_up_outlined,
        playlist: liked,
      ));
    }

    if (recentSongs.isEmpty && recentSearches.isEmpty && exploreItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.space24),
          child: Text(
            'Escribe para buscar canciones, artistas o playlists.',
            textAlign: TextAlign.center,
            style: AppTheme.itemSubtitle,
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (recentSongs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeading('Reproducido hace poco'),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pagePadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < recentSongs.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppTheme.space12),
                    _CompactRecentCard(
                      song: recentSongs[i],
                      size: _recentThumbSize,
                      onTap: () => player.playSong(
                        recentSongs[i],
                        playlist: recentSongs,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (recentSearches.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.space16,
                AppTheme.space8,
                AppTheme.space4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Búsquedas recientes',
                    style: AppTheme.itemTitle.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      minimumSize: const Size(0, AppTheme.minTouch),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space8,
                      ),
                      textStyle: AppTheme.label,
                    ),
                    onPressed: storage.clearSearches,
                    child: const Text('Borrar historial'),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final text = recentSearches[index];
                return InkWell(
                  onTap: () => _applyRecentSearch(storage, text),
                  child: SizedBox(
                    height: AppTheme.playlistThumb,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: AppTheme.pagePadding,
                        right: AppTheme.space4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.history,
                            color: AppTheme.textPrimary,
                            size: 24,
                          ),
                          const SizedBox(width: AppTheme.space16),
                          Expanded(
                            child: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.itemTitle.copyWith(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _fillFromRecent(text),
                            tooltip: 'Usar búsqueda $text',
                            icon: const Icon(
                              Icons.north_west,
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
              },
              childCount: recentSearches.length,
            ),
          ),
        ],
        if (exploreItems.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeading('Explora tu música'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pagePadding,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < exploreItems.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: _ExploreCard(
                          title: exploreItems[i].title,
                          icon: exploreItems[i].icon,
                          minHeight: _exploreMinHeight,
                          onTap: () => _openPlaylist(
                            context,
                            exploreItems[i].playlist,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(
          child: SizedBox(height: AppTheme.space24),
        ),
      ],
    );
  }

  Widget _buildResultsBody(
    BuildContext context,
    MusicStorageService storage,
    PlayerService player,
    String query,
  ) {
    final matchingPlaylists = storage.searchPlaylists(query);
    final matchingSongs = storage.searchSongs(query);

    if (matchingPlaylists.isEmpty && matchingSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Text(
            'Sin resultados para "$query"',
            textAlign: TextAlign.center,
            style: AppTheme.itemSubtitle,
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (matchingPlaylists.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionHeading('Playlists')),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final playlist = matchingPlaylists[index];
                return InkWell(
                  onTap: () => _openPlaylist(context, playlist),
                  child: SizedBox(
                    height: _playlistRowHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.pagePadding,
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
                                Text(
                                  playlist.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.itemSubtitle,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: matchingPlaylists.length,
            ),
          ),
        ],
        if (matchingSongs.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionHeading('Canciones')),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = matchingSongs[index];
                return SongTile(
                  song: song,
                  onTap: () => player.playSong(song, playlist: matchingSongs),
                  onMore: () => _showSongMenu(
                    context,
                    song,
                    matchingSongs,
                    storage,
                    player,
                  ),
                );
              },
              childCount: matchingSongs.length,
            ),
          ),
        ],
        const SliverToBoxAdapter(
          child: SizedBox(height: AppTheme.space24),
        ),
      ],
    );
  }

  Widget _sectionHeading(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.space16,
        AppTheme.pagePadding,
        AppTheme.space12,
      ),
      child: Text(
        text,
        style: AppTheme.itemTitle.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }

  void _showSongMenu(
    BuildContext context,
    Song song,
    List<Song> queueContext,
    MusicStorageService storage,
    PlayerService player,
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
                leading: const Icon(
                  Icons.play_circle_fill,
                  color: AppTheme.textPrimary,
                ),
                title: const Text('Reproducir', style: AppTheme.itemTitle),
                onTap: () {
                  player.playSong(song, playlist: queueContext);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.playlist_add,
                  color: AppTheme.textPrimary,
                ),
                title: const Text(
                  'Añadir a la fila',
                  style: AppTheme.itemTitle,
                ),
                onTap: () {
                  player.enqueue(song);
                  Navigator.pop(ctx);
                },
              ),
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
                  Icons.delete_outline_rounded,
                  color: AppTheme.danger,
                ),
                title: Text(
                  'Eliminar canción',
                  style: AppTheme.itemTitle.copyWith(color: AppTheme.danger),
                ),
                subtitle: const Text(
                  'Borra el archivo del disco',
                  style: AppTheme.caption,
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
}

class _CompactRecentCard extends StatelessWidget {
  final Song song;
  final double size;
  final VoidCallback onTap;

  const _CompactRecentCard({
    required this.song,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasArtwork = song.artworkBytes != null && song.artworkBytes!.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: SizedBox.square(
                dimension: size,
                child: hasArtwork
                    ? Image.memory(
                        song.artworkBytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : const ColoredBox(
                        color: AppTheme.surfaceHigh,
                        child: Center(
                          child: Icon(
                            Icons.music_note_rounded,
                            color: AppTheme.textSecondary,
                            size: 28,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.label,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double minHeight;
  final VoidCallback onTap;

  const _ExploreCard({
    required this.title,
    required this.icon,
    required this.minHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: AppTheme.accent, size: 24),
                const SizedBox(height: AppTheme.space12),
                Text(
                  title,
                  style: AppTheme.label.copyWith(height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
