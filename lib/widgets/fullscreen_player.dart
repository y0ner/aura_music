import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/song_model.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/artwork_palette.dart';
import 'explicit_badge.dart';
import 'lyrics_view.dart';

class FullscreenPlayer extends StatefulWidget {
  final VoidCallback onCollapse;

  const FullscreenPlayer({super.key, required this.onCollapse});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  // 0: A continuación, 1: Letra
  int _selectedBottomTab = 0;
  double? _dragValue;

  String? _paletteSongId;
  Uint8List? _paletteArtworkBytes;
  Color _bgColor = AppTheme.surfaceHigh;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _syncArtworkColor(Song song) {
    final bytes = song.artworkBytes;
    if (_paletteSongId == song.id && identical(_paletteArtworkBytes, bytes)) {
      return;
    }
    _paletteSongId = song.id;
    _paletteArtworkBytes = bytes;
    if (bytes == null || bytes.isEmpty) {
      _bgColor = AppTheme.surfaceHigh;
      return;
    }
    final targetId = song.id;
    artworkBackgroundColor(bytes).then((color) {
      if (!mounted || _paletteSongId != targetId) return;
      if (_bgColor != color) {
        setState(() => _bgColor = color);
      }
    });
  }

  Widget _buildGradientBackground({required Widget child}) {
    final top = _bgColor;
    final midUpper = Color.lerp(top, AppTheme.bg, 0.45)!;
    final midLower = Color.lerp(top, AppTheme.bg, 0.85)!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, midUpper, midLower, AppTheme.bg],
          stops: const [0.0, 0.34, 0.66, 1.0],
        ),
      ),
      child: child,
    );
  }

  String _songSubtitle(Song song) =>
      song.hasKnownArtist ? song.artist : song.category;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, child) {
        final song = player.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }

        _syncArtworkColor(song);

        final position = Duration(
          milliseconds:
              (_dragValue ?? player.position.inMilliseconds.toDouble()).toInt(),
        );
        final totalDuration = player.duration.inMilliseconds > 0
            ? player.duration
            : song.duration;

        if (player.isLyricsMode) {
          return Scaffold(
            backgroundColor: AppTheme.bg,
            body: _buildGradientBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    _lyricsNowPlaying(player, song),
                    Expanded(
                      child: _lyricsPanel(
                        player,
                        song,
                        () => player.toggleLyricsMode(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.bg,
          body: _buildGradientBackground(
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context, player, song),
                  Expanded(child: _buildArtwork(context, song)),
                  _buildTitleAndArtist(song),
                  _buildActionPills(context, song),
                  _buildProgressBar(context, player, position, totalDuration),
                  _buildPlaybackControls(player),
                  _buildBottomTabs(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, PlayerService player, Song song) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space4,
        AppTheme.space12,
        AppTheme.space4,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Minimizar',
            constraints: const BoxConstraints.tightFor(
              width: AppTheme.minTouch,
              height: AppTheme.minTouch,
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textPrimary,
              size: 28,
            ),
            onPressed: widget.onCollapse,
          ),
          Container(
            padding: const EdgeInsets.all(AppTheme.space4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppTheme.space24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeSegment(
                  label: 'Canción',
                  selected: !player.isLyricsMode,
                  onTap: () {
                    if (player.isLyricsMode) {
                      player.toggleLyricsMode();
                    }
                  },
                ),
                _buildModeSegment(
                  label: 'Letra',
                  selected: player.isLyricsMode,
                  onTap: () {
                    if (!player.isLyricsMode) {
                      player.toggleLyricsMode();
                    }
                  },
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Más opciones',
            constraints: const BoxConstraints.tightFor(
              width: AppTheme.minTouch,
              height: AppTheme.minTouch,
            ),
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.textPrimary,
              size: 24,
            ),
            onPressed: () => _showTrackOptionsMenu(context, song),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSegment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final pillRadius = BorderRadius.circular(AppTheme.space24);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: pillRadius,
          onTap: onTap,
          child: Container(
            height: AppTheme.chipHeight - AppTheme.space4,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.textPrimary.withValues(alpha: 0.20)
                  : Colors.transparent,
              borderRadius: pillRadius,
            ),
            child: Text(
              label,
              style: selected
                  ? AppTheme.label
                  : AppTheme.label.copyWith(
                      color: AppTheme.textPrimary.withValues(alpha: 0.75),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(BuildContext context, Song song) {
    final screenArtwork =
        MediaQuery.sizeOf(context).width - AppTheme.space24 * 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space24,
        AppTheme.space24,
        AppTheme.space24,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dimension = [
            screenArtwork,
            constraints.maxWidth,
            constraints.maxHeight,
          ].reduce((a, b) => a < b ? a : b).clamp(0.0, double.infinity);
          return Center(
            child: Container(
              width: dimension,
              height: dimension,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusArtwork),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusArtwork),
                child: song.artworkBytes != null
                    ? Image.memory(song.artworkBytes!, fit: BoxFit.cover)
                    : Container(
                        color: AppTheme.surfaceHigh,
                        child: const Center(
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 72,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitleAndArtist(Song song) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space24,
        AppTheme.space24,
        AppTheme.space16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.space4),
          Row(
            children: [
              if (song.isExplicit) const ExplicitBadge(size: 14),
              Expanded(
                child: Text(
                  _songSubtitle(song),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.itemTitle.copyWith(
                    color: AppTheme.textPrimary.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionPills(BuildContext context, Song song) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space24,
        AppTheme.space16,
        AppTheme.space24,
        0,
      ),
      child: Row(
        children: [
          _buildPillButton(
            icon: song.isFavorite ? Icons.thumb_up : Icons.thumb_up_outlined,
            label: 'Me gusta',
            onTap: () =>
                context.read<MusicStorageService>().toggleFavorite(song),
          ),
          const SizedBox(width: AppTheme.space8),
          _buildPillButton(
            icon: Icons.playlist_add,
            label: 'Guardar',
            onTap: () => _saveToPlaylist(song),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final radius = BorderRadius.circular(AppTheme.chipHeight / 2);
    return Material(
      color: AppTheme.textPrimary.withValues(alpha: 0.12),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: AppTheme.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppTheme.textPrimary),
              const SizedBox(width: AppTheme.space8),
              Text(label, style: AppTheme.label),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    PlayerService player,
    Duration position,
    Duration totalDuration,
  ) {
    final maxMillis = totalDuration.inMilliseconds > 0
        ? totalDuration.inMilliseconds.toDouble()
        : 1.0;
    final sliderTheme = Theme.of(context).sliderTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space8,
            AppTheme.space8,
            AppTheme.space8,
            0,
          ),
          child: SliderTheme(
            data: sliderTheme.copyWith(
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.textPrimary.withValues(alpha: 0.25),
              thumbColor: AppTheme.textPrimary,
              overlayColor: AppTheme.textPrimary.withValues(alpha: 0.16),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              min: 0.0,
              max: maxMillis,
              value: position.inMilliseconds.toDouble().clamp(0.0, maxMillis),
              onChanged: (val) => setState(() => _dragValue = val),
              onChangeEnd: (val) {
                player.seek(Duration(milliseconds: val.toInt()));
                setState(() => _dragValue = null);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textPrimary.withValues(alpha: 0.75),
                ),
              ),
              Text(
                _formatDuration(totalDuration),
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textPrimary.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(PlayerService player) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space16,
        AppTheme.space12,
        AppTheme.space16,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Aleatorio',
            constraints: const BoxConstraints.tightFor(
              width: AppTheme.minTouch,
              height: AppTheme.minTouch,
            ),
            icon: Icon(
              Icons.shuffle_rounded,
              color: player.isShuffle
                  ? AppTheme.accent
                  : AppTheme.textPrimary.withValues(alpha: 0.6),
              size: 24,
            ),
            onPressed: player.toggleShuffle,
          ),
          IconButton(
            tooltip: 'Anterior',
            constraints: const BoxConstraints.tightFor(
              width: AppTheme.playlistThumb,
              height: AppTheme.playlistThumb,
            ),
            icon: const Icon(
              Icons.skip_previous_rounded,
              color: AppTheme.textPrimary,
              size: 36,
            ),
            onPressed: player.previous,
          ),
          SizedBox(
            width: AppTheme.playerPlayButtonSize,
            height: AppTheme.playerPlayButtonSize,
            child: IconButton(
              tooltip: player.isPlaying ? 'Pausar' : 'Reproducir',
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.textPrimary,
                foregroundColor: AppTheme.bg,
                shape: const CircleBorder(),
              ),
              iconSize: 38,
              icon: Icon(
                player.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              onPressed: player.togglePlayPause,
            ),
          ),
          IconButton(
            tooltip: 'Siguiente',
            constraints: const BoxConstraints.tightFor(
              width: AppTheme.playlistThumb,
              height: AppTheme.playlistThumb,
            ),
            icon: const Icon(
              Icons.skip_next_rounded,
              color: AppTheme.textPrimary,
              size: 36,
            ),
            onPressed: player.next,
          ),
          IconButton(
            tooltip: switch (player.repeatMode) {
              AudioRepeatMode.off => 'Repetir',
              AudioRepeatMode.all => 'Repetir lista',
              AudioRepeatMode.one => 'Repetir canción',
            },
            constraints: const BoxConstraints.tightFor(
              width: AppTheme.minTouch,
              height: AppTheme.minTouch,
            ),
            icon: Icon(
              player.repeatMode == AudioRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: player.repeatMode != AudioRepeatMode.off
                  ? AppTheme.accent
                  : AppTheme.textPrimary.withValues(alpha: 0.6),
              size: 24,
            ),
            onPressed: player.toggleRepeat,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTabs() {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppTheme.space4,
        bottom: AppTheme.space8,
      ),
      child: SizedBox(
        height: AppTheme.playlistThumb,
        child: Row(
          children: [
            Expanded(child: _buildBottomTab(0, 'A continuación')),
            Expanded(child: _buildBottomTab(1, 'Letra')),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTab(int index, String title) {
    final isSelected = _selectedBottomTab == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedBottomTab = index);
        _showBottomTabSheet(index, title);
      },
      child: Center(
        child: Text(
          title,
          style: AppTheme.label.copyWith(
            color: isSelected
                ? AppTheme.textPrimary
                : AppTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  void _showBottomTabSheet(int index, String title) {
    if (index == 1) {
      final player = context.read<PlayerService>();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.surfaceHigh,
        builder: (ctx) => ChangeNotifierProvider.value(
          value: player,
          child: Consumer<PlayerService>(
            builder: (_, live, _) {
              final song = live.currentSong;
              if (song == null) return const SizedBox.shrink();
              return SafeArea(
                child: SizedBox(
                  height: MediaQuery.sizeOf(ctx).height * .9,
                  child: Column(
                    children: [
                      _lyricsNowPlaying(live, song),
                      Expanded(
                        child: _lyricsPanel(
                          live,
                          song,
                          () => Navigator.pop(ctx),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      return;
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
        final player = Provider.of<PlayerService>(context, listen: false);
        return Container(
          padding: const EdgeInsets.all(AppTheme.space16),
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: AppTheme.chipHeight,
                  height: AppTheme.space4,
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              Text(title, style: AppTheme.titleLarge),
              const SizedBox(height: AppTheme.space12),
              Expanded(
                child: ListView.builder(
                  itemCount: player.queue.length,
                  itemBuilder: (context, i) {
                    final song = player.queue[i];
                    final isCurrent = i == player.currentIndex;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                        child: Container(
                          width: AppTheme.songThumb,
                          height: AppTheme.songThumb,
                          color: AppTheme.chip,
                          child: song.artworkBytes != null
                              ? Image.memory(
                                  song.artworkBytes!,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(
                                  Icons.music_note_rounded,
                                  color: AppTheme.textSecondary,
                                ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.itemTitle.copyWith(
                          color: isCurrent
                              ? AppTheme.accent
                              : AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        song.hasKnownArtist
                            ? song.artist
                            : song.formattedDuration,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.itemSubtitle,
                      ),
                      trailing: isCurrent
                          ? const Icon(
                              Icons.volume_up_rounded,
                              color: AppTheme.accent,
                            )
                          : null,
                      onTap: () {
                        player.playSong(song, playlist: player.queue);
                        Navigator.pop(ctx);
                      },
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

  Widget _lyricsNowPlaying(PlayerService player, Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: Container(
              width: AppTheme.songThumb,
              height: AppTheme.songThumb,
              color: AppTheme.surfaceHigh,
              child: song.artworkBytes == null
                  ? const Icon(
                      Icons.music_note_rounded,
                      color: AppTheme.textSecondary,
                      size: 24,
                    )
                  : Image.memory(song.artworkBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.itemTitle,
                ),
                Text(
                  _songSubtitle(song),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.itemSubtitle,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: player.isPlaying ? 'Pausar' : 'Reproducir',
            onPressed: player.togglePlayPause,
            icon: Icon(
              player.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lyricsPanel(PlayerService player, Song song, VoidCallback close) {
    return Column(
      children: [
        const SizedBox(height: AppTheme.space8),
        Container(
          width: AppTheme.chipHeight,
          height: AppTheme.space4,
          decoration: BoxDecoration(
            color: AppTheme.textPrimary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space16,
            AppTheme.space12,
            AppTheme.space8,
            AppTheme.space12,
          ),
          child: Row(
            children: [
              const Expanded(child: Text('Letra', style: AppTheme.titleLarge)),
              IconButton(
                tooltip: 'Cerrar letra',
                onPressed: close,
                icon: const Icon(Icons.close, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.dividerColor),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: LyricsView(
                  song: song,
                  position: player.position,
                  onSeek: player.seek,
                ),
              ),
              Positioned(
                bottom: AppTheme.space24,
                left: 0,
                right: 0,
                child: Center(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.textPrimary,
                      foregroundColor: AppTheme.bg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space24,
                        vertical: AppTheme.space12,
                      ),
                    ),
                    onPressed: () => _copySong(song),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Compartir'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _copySong(Song song) async {
    final sharedText = song.hasKnownArtist
        ? '${song.title} — ${song.artist}'
        : song.title;
    await Clipboard.setData(ClipboardData(text: sharedText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Título y artista copiados para compartir.'),
      ),
    );
  }

  Future<void> _saveToPlaylist(Song song) async {
    final storage = context.read<MusicStorageService>();
    final destinations = storage.playlists
        .where((p) => p.folderPath != File(song.filePath).parent.path)
        .toList();
    if (destinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crea otra playlist en Biblioteca primero.'),
        ),
      );
      return;
    }
    final destination = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: destinations
              .map(
                (p) => ListTile(
                  leading: const Icon(
                    Icons.playlist_play,
                    color: AppTheme.textPrimary,
                  ),
                  title: Text(p.name, style: AppTheme.itemTitle),
                  onTap: () => Navigator.pop(ctx, p.folderPath),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (destination == null) return;
    try {
      final source = File(song.filePath);
      final target = File('$destination/${source.uri.pathSegments.last}');
      if (await target.exists()) {
        throw StateError('Esta canción ya existe en la playlist.');
      }
      await source.copy(target.path);
      final base = song.filePath.substring(0, song.filePath.lastIndexOf('.'));
      for (final extension in ['.jpg', '.lrc', '_private.lrc']) {
        final sidecar = File('$base$extension');
        if (await sidecar.exists()) {
          await sidecar.copy('$destination/${sidecar.uri.pathSegments.last}');
        }
      }
      await storage.scanLibrary();
    } catch (e) {
      debugPrint('Error al guardar la canción en playlist: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  void _showTrackOptionsMenu(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        final player = context.read<PlayerService>();
        Widget quick(IconData icon, String label, VoidCallback action) =>
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space8,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: AppTheme.playButtonSize,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.chip,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusArtwork,
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          action();
                        },
                        child: Icon(icon, color: AppTheme.textPrimary, size: 28),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );

        final trackMeta = song.hasKnownArtist
            ? '${song.artist} • ${song.formattedDuration}'
            : song.formattedDuration;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.space24,
                      AppTheme.space24,
                      AppTheme.space8,
                      AppTheme.space16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.titleLarge,
                              ),
                              const SizedBox(height: AppTheme.space4),
                              Text(trackMeta, style: AppTheme.itemSubtitle),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Me gusta',
                          icon: Icon(
                            song.isFavorite
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            color: AppTheme.textPrimary,
                          ),
                          onPressed: () {
                            context.read<MusicStorageService>().toggleFavorite(
                              song,
                            );
                            Navigator.pop(ctx);
                          },
                        ),
                        IconButton(
                          tooltip: 'Cerrar opciones',
                          icon: const Icon(
                            Icons.close,
                            color: AppTheme.textPrimary,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.dividerColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: AppTheme.space24,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        quick(
                          Icons.playlist_play,
                          'Reproducir a\ncontinuación',
                          () => player.enqueue(song, next: true),
                        ),
                        quick(
                          Icons.playlist_add,
                          'Guardar en una\nplaylist',
                          () => _saveToPlaylist(song),
                        ),
                        quick(
                          Icons.ios_share,
                          'Compartir',
                          () => _copySong(song),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.queue_music,
                      color: AppTheme.textPrimary,
                    ),
                    title: const Text(
                      'Agregar a la fila',
                      style: AppTheme.itemTitle,
                    ),
                    onTap: () {
                      player.enqueue(song);
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.favorite_outline,
                      color: AppTheme.textPrimary,
                    ),
                    title: Text(
                      song.isFavorite
                          ? 'Quitar de favoritos'
                          : 'Añadir a Música que te gustó',
                      style: AppTheme.itemTitle,
                    ),
                    onTap: () {
                      context.read<MusicStorageService>().toggleFavorite(song);
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: AppTheme.textPrimary,
                    ),
                    title: const Text(
                      'Detalles de la pista',
                      style: AppTheme.itemTitle,
                    ),
                    subtitle: Text(song.filePath, style: AppTheme.itemSubtitle),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.playlist_remove,
                      color: AppTheme.textPrimary,
                    ),
                    title: const Text(
                      'Descartar fila',
                      style: AppTheme.itemTitle,
                    ),
                    onTap: () {
                      player.stopAndClear();
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: AppTheme.space12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
