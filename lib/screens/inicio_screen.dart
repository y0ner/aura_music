import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/cover_image.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/collage_cover.dart';
import '../widgets/header_bar.dart';
import '../widgets/song_tile.dart';
import 'playlist_detail_screen.dart';

/// Pantalla principal de Inicio con accesos rápidos, cuadrícula 3 × 3 y
/// canciones escuchadas hace poco.
class InicioScreen extends StatefulWidget {
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onAddMusic;

  const InicioScreen({
    super.key,
    this.onOpenSearch,
    this.onOpenSettings,
    this.onAddMusic,
  });

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  static const int _maxChips = 8;
  static const int _tilesPerPage = 9;
  static const int _maxGridPages = 3;
  static const double _glowHeight = 300;
  static const double _recentCardWidth = 144;
  static const double _moreButtonHeight = 36;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Playlist> _collectGridPlaylists(MusicStorageService storage) {
    const maxTiles = _tilesPerPage * _maxGridPages;
    final items = <Playlist>[];
    final seenIds = <String>{};

    void addIfEligible(Playlist? playlist, {bool allowEmpty = false}) {
      if (playlist == null || items.length >= maxTiles) return;
      if (!allowEmpty && playlist.songs.isEmpty) return;
      if (seenIds.add(playlist.id)) {
        items.add(playlist);
      }
    }

    addIfEligible(storage.likedSongsPlaylist, allowEmpty: true);
    for (final playlist in storage.playlists) {
      addIfEligible(playlist);
    }
    addIfEligible(storage.autoPlaylist(AutoPlaylistKind.recentlyAdded));
    addIfEligible(storage.autoPlaylist(AutoPlaylistKind.mostPlayed));
    for (final artist in storage.topArtists) {
      if (items.length >= maxTiles) break;
      addIfEligible(storage.artistMix(artist));
    }
    return items;
  }

  bool _playlistContainsSong(Playlist playlist, String? songId) {
    if (songId == null) return false;
    for (final song in playlist.songs) {
      if (song.id == songId) return true;
    }
    return false;
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
    // Solo escucha la biblioteca: el reproductor se usa para acciones
    // (listen: false) y así reproducir/pausar no redibuja la pantalla.
    return Consumer<MusicStorageService>(
      builder: (context, storage, child) {
        final player = Provider.of<PlayerService>(context, listen: false);
        final chips = storage.playlists.take(_maxChips).toList();
        final gridItems = _collectGridPlaylists(storage);
        final recentSongs = storage.recentlyPlayed;
        final currentSongId = context.select<PlayerService, String?>(
          (p) => p.currentSong?.id,
        );

        return ColoredBox(
          color: AppTheme.bg,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _glowHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.4, -1.0),
                        radius: 1.0,
                        colors: [
                          AppTheme.brandViolet.withValues(alpha: 0.22),
                          AppTheme.bg.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  color: AppTheme.textPrimary,
                  backgroundColor: AppTheme.surfaceHigh,
                  onRefresh: () => storage.scanLibrary(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: InicioHeader(
                          onSearchPressed: widget.onOpenSearch,
                          onSettingsPressed: widget.onOpenSettings,
                        ),
                      ),
                      if (storage.isLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (storage.allSongs.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyLibrary(context),
                        )
                      else ...[
                        if (chips.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildQuickChips(context, chips),
                          ),
                        if (gridItems.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildGridSection(
                              context,
                              gridItems,
                              currentSongId,
                            ),
                          ),
                        if (recentSongs.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildRecentlyPlayedSection(
                              context,
                              storage,
                              player,
                              recentSongs,
                            ),
                          ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: AppTheme.space24),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickChips(BuildContext context, List<Playlist> playlists) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppTheme.space8,
        bottom: AppTheme.space12,
      ),
      child: SizedBox(
        height: AppTheme.chipHeight,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
          scrollDirection: Axis.horizontal,
          itemCount: playlists.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppTheme.space8),
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return Material(
              color: AppTheme.chip,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                onTap: () => _openPlaylist(context, playlist),
                child: Container(
                  height: AppTheme.chipHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.pagePadding,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.label,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridSection(
    BuildContext context,
    List<Playlist> gridItems,
    String? currentSongId,
  ) {
    final pages = <List<Playlist>>[];
    for (var start = 0;
        start < gridItems.length && pages.length < _maxGridPages;
        start += _tilesPerPage) {
      final end = (start + _tilesPerPage).clamp(0, gridItems.length);
      pages.add(gridItems.sublist(start, end));
    }
    final activePage = _currentPage.clamp(0, pages.length - 1);

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.space4),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final tileSize = (constraints.maxWidth -
                      (AppTheme.pagePadding * 2) -
                      (AppTheme.space8 * 2)) /
                  3;
              if (tileSize <= 0) return const SizedBox.shrink();

              final rows = pages.length > 1
                  ? 3
                  : ((gridItems.length + 2) ~/ 3).clamp(1, 3);
              final gridHeight =
                  rows * tileSize + (rows - 1) * AppTheme.space8;

              if (pages.length == 1) {
                return SizedBox(
                  height: gridHeight,
                  child: _buildGridPage(
                    context,
                    pages.first,
                    tileSize,
                    currentSongId,
                  ),
                );
              }

              return SizedBox(
                height: gridHeight,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, pageIndex) => _buildGridPage(
                    context,
                    pages[pageIndex],
                    tileSize,
                    currentSongId,
                  ),
                ),
              );
            },
          ),
          if (pages.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.space12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppTheme.space8),
                    Container(
                      width: AppTheme.space8,
                      height: AppTheme.space8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == activePage
                            ? AppTheme.textPrimary
                            : AppTheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridPage(
    BuildContext context,
    List<Playlist> items,
    double tileSize,
    String? currentSongId,
  ) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppTheme.space8,
        crossAxisSpacing: AppTheme.space8,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final playlist = items[index];
        final isActive = _playlistContainsSong(playlist, currentSongId);
        return _GridPlaylistTile(
          playlist: playlist,
          tileSize: tileSize,
          isActive: isActive,
          onTap: () => _openPlaylist(context, playlist),
        );
      },
    );
  }

  Widget _buildRecentlyPlayedSection(
    BuildContext context,
    MusicStorageService storage,
    PlayerService player,
    List<Song> recentSongs,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              0,
              AppTheme.pagePadding,
              AppTheme.space12,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Escuchado hace poco',
                    style: AppTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.outline),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, _moreButtonHeight),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.pagePadding,
                    ),
                    textStyle: AppTheme.label,
                  ),
                  onPressed: () {
                    final playlist = storage.autoPlaylist(
                      AutoPlaylistKind.recentlyPlayed,
                    );
                    if (playlist != null) {
                      _openPlaylist(context, playlist);
                    }
                  },
                  child: const Text('Más'),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pagePadding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < recentSongs.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppTheme.space12),
                  _RecentSongCard(
                    song: recentSongs[i],
                    size: _recentCardWidth,
                    onTap: () => player.playSong(
                      recentSongs[i],
                      playlist: recentSongs,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLibrary(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.library_music_outlined,
              size: 56,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: AppTheme.space16),
            const Text(
              'Tu biblioteca está vacía',
              textAlign: TextAlign.center,
              style: AppTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.space8),
            const Text(
              'Descarga canciones o elige una carpeta de música en Ajustes.',
              textAlign: TextAlign.center,
              style: AppTheme.itemSubtitle,
            ),
            const SizedBox(height: AppTheme.space24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.textPrimary,
                foregroundColor: AppTheme.bg,
                minimumSize: const Size(0, AppTheme.minTouch),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space24,
                  vertical: AppTheme.space12,
                ),
                shape: const StadiumBorder(),
                textStyle: AppTheme.itemTitle,
              ),
              onPressed: widget.onAddMusic,
              icon: const Icon(Icons.download_outlined, size: 20),
              label: const Text('Añadir música'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final double tileSize;
  final bool isActive;
  final VoidCallback onTap;

  const _GridPlaylistTile({
    required this.playlist,
    required this.tileSize,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final outerRadius = BorderRadius.circular(AppTheme.radiusMedium);
    final innerRadius = BorderRadius.circular(
      isActive ? AppTheme.radiusMedium - 2 : AppTheme.radiusMedium,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        border: isActive
            ? Border.all(color: AppTheme.textPrimary, width: 2)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(isActive ? 2 : 0),
        child: ClipRRect(
          borderRadius: innerRadius,
          child: Material(
            color: AppTheme.surfaceHigh,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlaylistArtwork(
                    playlist: playlist,
                    size: tileSize,
                    radius: 0,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: AppTheme.playlistThumb,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0),
                              Colors.black.withValues(alpha: 0.82),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      top: AppTheme.space4 + 2,
                      left: AppTheme.space4 + 2,
                      child: Container(
                        width: AppTheme.space24,
                        height: AppTheme.space24,
                        padding: const EdgeInsets.all(AppTheme.space4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall + 2,
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: NowPlayingBars(),
                        ),
                      ),
                    ),
                  Positioned(
                    left: AppTheme.space8,
                    right: AppTheme.space4,
                    bottom: AppTheme.space8,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.label,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textPrimary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentSongCard extends StatelessWidget {
  final Song song;
  final double size;
  final VoidCallback onTap;

  const _RecentSongCard({
    required this.song,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasArtwork = song.artworkBytes != null && song.artworkBytes!.isNotEmpty;
    final subtitle = song.hasKnownArtist ? song.artist : song.category;

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
                    ? CoverImage(
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
                            size: 36,
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
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.itemSubtitle,
            ),
          ],
        ),
      ),
    );
  }
}
