import 'package:flutter/material.dart';

import '../models/lyrics_model.dart';
import '../models/song_model.dart';
import '../services/lyrics_service.dart';

class LyricsView extends StatefulWidget {
  final Song song;
  final Duration position;
  final Future<void> Function(Duration target)? onSeek;
  final LyricsService lyricsService;
  final double? maxHeight;

  LyricsView({
    super.key,
    required this.song,
    required this.position,
    this.onSeek,
    LyricsService? lyricsService,
    this.maxHeight,
  }) : lyricsService = lyricsService ?? LyricsService.shared;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  late Future<ParsedLyrics?> _future;
  final ScrollController _scroll = ScrollController();
  int _lastActive = -2;
  DateTime? _manualScroll;

  @override
  void initState() {
    super.initState();
    _future = widget.lyricsService.loadLyrics(widget.song);
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.lyricsService != widget.lyricsService) {
      _lastActive = -2;
      _manualScroll = null;
      _future = widget.lyricsService.loadLyrics(widget.song);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow(int active, List<double> offsets, double height) {
    if (active < 0 ||
        _manualScroll != null &&
            DateTime.now().difference(_manualScroll!) <
                const Duration(seconds: 4)) {
      return;
    }
    if (_lastActive == active) return;
    _lastActive = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = (offsets[active] - height * .32).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF292211), Color(0xFF191919), Color(0xFF302027)],
        ),
      ),
      child: FutureBuilder<ParsedLyrics?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            );
          }
          final lyrics = snapshot.data;
          if (lyrics == null || lyrics.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Letra no disponible\nAgrega un archivo .lrc junto a la canción.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 18),
                ),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final fontSize = constraints.maxWidth < 600 ? 26.0 : 32.0;
              final horizontal = constraints.maxWidth < 600 ? 28.0 : 44.0;
              final style = TextStyle(
                fontSize: fontSize,
                height: 1.22,
                fontWeight: FontWeight.w700,
              );
              final active = lyrics.activeIndexAt(widget.position);
              final offsets = <double>[];
              final heights = <double>[];
              var offset = 24.0;
              for (final line in lyrics.lines) {
                final painter = TextPainter(
                  text: TextSpan(text: line.text, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: constraints.maxWidth - horizontal * 2);
                offsets.add(offset);
                heights.add(painter.height + 28);
                offset += heights.last;
                painter.dispose();
              }
              _follow(active, offsets, constraints.maxHeight);
              return NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification &&
                      notification.dragDetails != null) {
                    _manualScroll = DateTime.now();
                    _lastActive = -2;
                  }
                  return false;
                },
                child: Scrollbar(
                  controller: _scroll,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      24,
                      horizontal,
                      constraints.maxHeight * .45,
                    ),
                    itemCount: lyrics.lines.length + (lyrics.isSynced ? 0 : 1),
                    itemBuilder: (context, i) {
                      if (i == lyrics.lines.length) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text(
                            'Esta letra no incluye tiempos de sincronización.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }
                      final line = lyrics.lines[i];
                      return SizedBox(
                        height: heights[i],
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Semantics(
                            selected: lyrics.isSynced && i == active,
                            child: InkWell(
                              onTap: lyrics.isSynced && widget.onSeek != null
                                  ? () => widget.onSeek!(line.time)
                                  : null,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                style: style.copyWith(
                                  color: !lyrics.isSynced || i == active
                                      ? Colors.white
                                      : const Color(0xFF686868),
                                ),
                                child: Text(line.text),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
    if (widget.maxHeight != null) {
      body = SizedBox(height: widget.maxHeight, child: body);
    }
    return body;
  }
}
