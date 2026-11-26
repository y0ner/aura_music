import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/cover_image.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/collage_cover.dart';
import '../widgets/delete_dialogs.dart';
import '../widgets/fullscreen_player.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';

/// Detalle de una playlist o de «Música que te gustó».
class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  String _selectedCategory = 'Todas';

  Playlist _resolvePlaylist(BuildContext context) {
    MusicStorageService? storage;
    try {
      storage = Provider.of<MusicStorageService>(context);
    } on ProviderNotFoundException catch (e) {
      debugPrint('PlaylistDetailScreen sin MusicStorageService: $e');
    }
    if (storage == null) return widget.playlist;

    if (widget.playlist.id == 'liked_songs_auto') {
      if (storage.allSongs.isNotEmpty && storage.likedSongsPlaylist != null) {
        return storage.likedSongsPlaylist!;
      }
      return widget.playlist;
    }

    for (final candidate in storage.playlists) {
      if (candidate.id == widget.playlist.id) {
        return candidate;
      }
    }
    return widget.playlist;
  }

  @override
  Widget build(BuildContext context) {
    final currentPlaylist = _resolvePlaylist(context);
    final isLiked = currentPlaylist.id == 'liked_songs_auto';

    final categories = <String>{};
    if (isLiked) {
      for (final song in currentPlaylist.songs) {
        final cat = song.category.trim();
        if (cat.isNotEmpty) categories.add(cat);
      }
    }
    final sortedCategories = categories.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final activeCategory =
        _selectedCategory == 'Todas' || categories.contains(_selectedCategory)
            ? _selectedCategory
            : 'Todas';

    final visibleSongs = !isLiked || activeCategory == 'Todas'
        ? currentPlaylist.songs
        : currentPlaylist.songs
            .where((s) => s.category.trim() == activeCategory)
            .toList();

    return Consumer<PlayerService>(
      builder: (context, player, child) {
        return Scaffold(
          backgroundColor: AppTheme.bg,
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  if (isLiked)
                    SliverToBoxAdapter(
                      child: _buildLikedHeader(
                        context,
                        currentPlaylist,
                        player,
                        visibleSongs,
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: _buildStandardHeader(
                        context,
                        currentPlaylist,
                        player,
                        visibleSongs,
                      ),
                    ),

                  if (isLiked && currentPlaylist.songs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTheme.space24,
                            AppTheme.space24,
                            AppTheme.space24,
                            AppTheme.miniPlayerHeight + AppTheme.space24,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.thumb_up_outlined,
                                size: 48,
                                color: AppTheme.textSecondary,
                              ),
                              SizedBox(height: AppTheme.space16),
                              Text(
                                'Toca Me gusta en el reproductor para guardar canciones aquí',
                                textAlign: TextAlign.center,
                                style: AppTheme.itemSubtitle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (isLiked && sortedCategories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppTheme.space12,
                          bottom: AppTheme.space8,
                        ),
                        child: SizedBox(
                          height: AppTheme.chipHeight,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.pagePadding,
                            ),
                            scrollDirection: Axis.horizontal,
                            itemCount: sortedCategories.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: AppTheme.space8),
                            itemBuilder: (context, index) {
                              final label = index == 0
                                  ? 'Todas'
                                  : sortedCategories[index - 1];
                              final selected = activeCategory == label;
                              return _DetailChip(
                                label: label,
                                selected: selected,
                                onTap: () =>
                                    setState(() => _selectedCategory = label),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                  if (visibleSongs.isEmpty && !isLiked)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppTheme.space24,
                            AppTheme.space24,
                            AppTheme.space24,
                            AppTheme.miniPlayerHeight + AppTheme.space24,
                          ),
                          child: Text(
                            'No hay pistas en esta carpeta.',
                            textAlign: TextAlign.center,
                            style: AppTheme.itemSubtitle,
                          ),
                        ),
                      ),
                    )
                  else if (visibleSongs.isNotEmpty) ...[
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = visibleSongs[index];
                          return SongTile(
                            song: song,
                            showDuration: isLiked,
                            onTap: () => player.playSong(
                              song,
                              playlist: visibleSongs,
                            ),
                            onMore: () => _showSongMenu(
                              context,
                              song,
                              visibleSongs,
                            ),
                          );
                        },
                        childCount: visibleSongs.length,
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(
                        height: AppTheme.miniPlayerHeight + AppTheme.space24,
                      ),
                    ),
                  ],
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: MiniPlayer(
                  onExpand: () => _openFullscreenPlayer(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStandardHeader(
    BuildContext context,
    Playlist playlist,
    PlayerService player,
    List<Song> songs,
  ) {
    final screen = MediaQuery.sizeOf(context);
    final headerHeight =
        screen.width > screen.height * 0.6 ? screen.height * 0.48 : screen.width;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: headerHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PlaylistArtwork(
                playlist: playlist,
                size: double.infinity,
                radius: 0,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.bg.withValues(alpha: 0.55),
                      AppTheme.bg.withValues(alpha: 0),
                      AppTheme.bg.withValues(alpha: 0),
                      AppTheme.bg,
                    ],
                    stops: const [0.0, 0.22, 0.52, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopNavRow(context, playlist),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space24),
          child: Column(
            children: [
              Text(
                playlist.name,
                textAlign: TextAlign.center,
                style: AppTheme.titleLarge,
              ),
              const SizedBox(height: AppTheme.space8),
              Text(
                playlist.subtitle,
                textAlign: TextAlign.center,
                style: AppTheme.itemSubtitle,
              ),
            ],
          ),
        ),
        _buildActionsRow(context, player, songs),
      ],
    );
  }

  Widget _buildLikedHeader(
    BuildContext context,
    Playlist playlist,
    PlayerService player,
    List<Song> songs,
  ) {
    final topColor = Color.lerp(AppTheme.brandViolet, AppTheme.bg, 0.18)!;
    final midColor = Color.lerp(AppTheme.brandViolet, AppTheme.bg, 0.48)!;
    final lowColor = Color.lerp(AppTheme.brandViolet, AppTheme.bg, 0.82)!;
    final lavenderText = Color.lerp(
      AppTheme.textPrimary,
      AppTheme.brandViolet,
      0.2,
    )!;
    final count = playlist.songs.length;
    final countText = count == 1 ? '1 canción' : '$count canciones';

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topColor, midColor, lowColor, AppTheme.bg],
                stops: const [0.0, 0.38, 0.72, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 260,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.7, -0.8),
                  radius: 0.9,
                  colors: [
                    AppTheme.brandRose.withValues(alpha: 0.42),
                    AppTheme.brandRose.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopNavRow(context, playlist),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.space24,
                AppTheme.pagePadding,
                0,
              ),
              child: Row(
                children: [
                  PlaylistArtwork(
                    playlist: playlist,
                    size: AppTheme.playButtonSize,
                    radius: AppTheme.radiusArtwork,
                  ),
                  const SizedBox(width: AppTheme.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playlist.name, style: AppTheme.titleLarge),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          countText,
                          style: AppTheme.itemSubtitle.copyWith(
                            color: lavenderText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.space16,
                AppTheme.pagePadding,
                0,
              ),
              child: Text(
                'Lo que marques con Me gusta en Aura. Vive en tu dispositivo: sin cuenta y sin conexión.',
                style: AppTheme.itemSubtitle.copyWith(
                  height: 1.45,
                  color: lavenderText,
                ),
              ),
            ),
            _buildActionsRow(context, player, songs),
          ],
        ),
      ],
    );
  }

  Widget _buildTopNavRow(BuildContext context, Playlist playlist) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space4,
          vertical: AppTheme.space8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              tooltip: 'Volver',
              icon: const Icon(
                Icons.arrow_back,
                color: AppTheme.textPrimary,
              ),
              constraints: const BoxConstraints.tightFor(
                width: AppTheme.minTouch,
                height: AppTheme.minTouch,
              ),
            ),
            IconButton(
              onPressed: () => _showPlaylistOptionsMenu(context, playlist),
              tooltip: 'Opciones de la playlist',
              icon: const Icon(
                Icons.more_vert,
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
    );
  }

  Widget _buildActionsRow(
    BuildContext context,
    PlayerService player,
    List<Song> songs,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.space16,
        AppTheme.pagePadding,
        AppTheme.space8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: AppTheme.surfaceHigh,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: songs.isEmpty
                  ? null
                  : () => _enqueueAll(context, player, songs),
              tooltip: 'Añadir a la fila',
              color: AppTheme.textPrimary,
              disabledColor: AppTheme.textMuted,
              icon: const Icon(Icons.playlist_add, size: 22),
              constraints: const BoxConstraints.tightFor(
                width: AppTheme.minTouch,
                height: AppTheme.minTouch,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: songs.isEmpty
                    ? null
                    : () {
                        if (!player.isShuffle) {
                          player.toggleShuffle();
                        }
                        final picked = songs[Random().nextInt(songs.length)];
                        player.playSong(picked, playlist: songs);
                      },
                tooltip: 'Aleatorio',
                color: player.isShuffle ? AppTheme.accent : AppTheme.textPrimary,
                disabledColor: AppTheme.textMuted,
                icon: const Icon(Icons.shuffle_rounded, size: 26),
                constraints: const BoxConstraints.tightFor(
                  width: AppTheme.minTouch,
                  height: AppTheme.minTouch,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              IconButton(
                onPressed: songs.isEmpty
                    ? null
                    : () => player.playSong(songs.first, playlist: songs),
                tooltip: 'Reproducir',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.textPrimary,
                  foregroundColor: AppTheme.bg,
                  disabledBackgroundColor:
                      AppTheme.textPrimary.withValues(alpha: 0.4),
                  disabledForegroundColor: AppTheme.bg,
                  fixedSize: const Size.square(AppTheme.playButtonSize),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _enqueueAll(
    BuildContext context,
    PlayerService player,
    List<Song> songs,
  ) async {
    for (final song in songs) {
      await player.enqueue(song);
    }
    if (!context.mounted) return;
    final label = songs.length == 1
        ? '1 canción añadida a la fila'
        : '${songs.length} canciones añadidas a la fila';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          label,
          style: AppTheme.itemSubtitle.copyWith(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.surfaceHigh,
      ),
    );
  }

  void _showPlaylistOptionsMenu(BuildContext context, Playlist playlist) {
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
                    'Eliminar playlist',
                    style: AppTheme.itemTitle.copyWith(color: AppTheme.danger),
                  ),
                  subtitle: const Text(
                    'Borra la carpeta y todas sus canciones del disco',
                    style: AppTheme.caption,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final deleted = await DeleteDialogs.confirmDeletePlaylist(
                      context,
                      playlist,
                    );
                    if (deleted && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showSongMenu(
    BuildContext context,
    Song song,
    List<Song> queueContext,
  ) {
    final player = Provider.of<PlayerService>(context, listen: false);
    MusicStorageService? storage;
    try {
      storage = Provider.of<MusicStorageService>(context, listen: false);
    } on ProviderNotFoundException catch (e) {
      debugPrint('PlaylistDetailScreen menú sin MusicStorageService: $e');
    }

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
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: SizedBox(
                        width: AppTheme.chipHeight,
                        height: AppTheme.chipHeight,
                        child: song.artworkBytes != null
                            ? CoverImage(
                                song.artworkBytes!,
                                fit: BoxFit.cover,
                              )
                            : const ColoredBox(
                                color: AppTheme.chip,
                                child: Icon(
                                  Icons.music_note,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.itemTitle,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.outline),
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
              if (storage != null) ...[
                ListTile(
                  leading: Icon(
                    song.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: song.isFavorite
                        ? AppTheme.accent
                        : AppTheme.textPrimary,
                  ),
                  title: Text(
                    song.isFavorite
                        ? 'Quitar de favoritos'
                        : 'Añadir a "Música que te gustó"',
                    style: AppTheme.itemTitle,
                  ),
                  onTap: () {
                    storage?.toggleFavorite(song);
                    Navigator.pop(ctx);
                  },
                ),
              ],
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

  void _openFullscreenPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullscreenPlayer(onCollapse: () => Navigator.pop(context)),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DetailChip({
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
