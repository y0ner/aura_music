import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/song_model.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'explicit_badge.dart';
import 'lyrics_view.dart';

class FullscreenPlayer extends StatefulWidget {
  final VoidCallback onCollapse;

  const FullscreenPlayer({super.key, required this.onCollapse});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  int _selectedBottomTab =
      0; // 0: A continuación, 1: Letra, 2: Comentarios, 3: Similares
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
          milliseconds:
              (_dragValue ?? player.position.inMilliseconds.toDouble()).toInt(),
        );
        final totalDuration = player.duration.inMilliseconds > 0
            ? player.duration
            : song.duration;

        if (player.isLyricsMode) {
          return Scaffold(
            backgroundColor: const Color(0xFF100D06),
            body: SafeArea(
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
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF030303),
          body: SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
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
                      // Pill toggle: Canción | Letra
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
                                if (player.isLyricsMode) {
                                  player.toggleLyricsMode();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: !player.isLyricsMode
                                      ? const Color(0xFF383838)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Canción',
                                  style: TextStyle(
                                    color: !player.isLyricsMode
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
                                if (!player.isLyricsMode) {
                                  player.toggleLyricsMode();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: player.isLyricsMode
                                      ? const Color(0xFF383838)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Letra',
                                  style: TextStyle(
                                    color: player.isLyricsMode
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

                // Contenido central: carátula gigante o letra sincronizada
                // estilo YouTube Music según la píldora Canción | Letra.
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: player.isLyricsMode
                        ? LyricsView(
                            song: song,
                            position: position,
                            onSeek: (target) => player.seek(target),
                          )
                        : Center(
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
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
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.graphic_eq_rounded,
                                                    size: 48,
                                                    color: Colors.white70,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 20,
                                                        ),
                                                    child: Text(
                                                      song.title,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
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
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
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
                      value: position.inMilliseconds.toDouble().clamp(
                        0.0,
                        totalDuration.inMilliseconds.toDouble() > 0
                            ? totalDuration.inMilliseconds.toDouble()
                            : 1.0,
                      ),
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
                          color: player.isShuffle
                              ? Colors.white
                              : Colors.white54,
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
          fontWeight: isSelected || isBold
              ? FontWeight.bold
              : FontWeight.normal,
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
        backgroundColor: const Color(0xFF292211),
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
                child: index == 1
                    // Hoja de Letra con la misma vista sincronizada del
                    // modo Letra (se suscribe a la posición en vivo).
                    ? Consumer<PlayerService>(
                        builder: (context, livePlayer, _) {
                          final liveSong = livePlayer.currentSong;
                          if (liveSong == null) {
                            return const SizedBox.shrink();
                          }
                          return LyricsView(
                            song: liveSong,
                            position: livePlayer.position,
                            onSeek: (target) => livePlayer.seek(target),
                          );
                        },
                      )
                    : index == 0
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
                                    ? Image.memory(
                                        song.artworkBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.music_note,
                                        color: Colors.white54,
                                      ),
                              ),
                            ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent
                                    ? AppTheme.redAccent
                                    : Colors.white,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              song.artist,
                              style: const TextStyle(
                                color: Color(0xFFAAAAAA),
                                fontSize: 12,
                              ),
                            ),
                            trailing: isCurrent
                                ? const Icon(
                                    Icons.volume_up_rounded,
                                    color: AppTheme.redAccent,
                                  )
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
                          index == 2
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

  Widget _lyricsNowPlaying(PlayerService player, Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: song.artworkBytes == null
                ? const Icon(
                    Icons.album_outlined,
                    color: Colors.white54,
                    size: 44,
                  )
                : Image.memory(song.artworkBytes!, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 15),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: player.isPlaying ? 'Pausar' : 'Reproducir',
            onPressed: player.togglePlayPause,
            icon: Icon(
              player.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lyricsPanel(PlayerService player, Song song, VoidCallback close) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white38,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Letra',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar letra',
                onPressed: close,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
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
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
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
    await Clipboard.setData(
      ClipboardData(text: '${song.title} — ${song.artist}'),
    );
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
      backgroundColor: const Color(0xFF212121),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: destinations
              .map(
                (p) => ListTile(
                  leading: const Icon(Icons.playlist_play, color: Colors.white),
                  title: Text(
                    p.name,
                    style: const TextStyle(color: Colors.white),
                  ),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  void _showTrackOptionsMenu(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        final player = context.read<PlayerService>();
        Widget quick(IconData icon, String label, VoidCallback action) =>
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 68,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF343434),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          action();
                        },
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 8, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${song.artist} • ${song.formattedDuration}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Me gusta',
                          icon: Icon(
                            song.isFavorite
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            color: Colors.white,
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
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 20,
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
                    leading: const Icon(Icons.queue_music, color: Colors.white),
                    title: const Text(
                      'Agregar a la fila',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    onTap: () {
                      player.enqueue(song);
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.favorite_outline,
                      color: Colors.white,
                    ),
                    title: Text(
                      song.isFavorite
                          ? 'Quitar de favoritos'
                          : 'Añadir a Música que te gustó',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    onTap: () {
                      context.read<MusicStorageService>().toggleFavorite(song);
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Detalles de la pista',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    subtitle: Text(
                      song.filePath,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.playlist_remove,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Descartar fila',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    onTap: () {
                      player.stopAndClear();
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
