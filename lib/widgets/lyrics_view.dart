import 'package:flutter/material.dart';

import '../models/lyrics_model.dart';
import '../models/song_model.dart';
import '../services/lyrics_service.dart';
import '../theme/app_theme.dart';

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
          colors: [AppTheme.surfaceHigh, AppTheme.surface, AppTheme.bg],
        ),
      ),
      child: FutureBuilder<ParsedLyrics?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.textSecondary),
                  const SizedBox(height: AppTheme.space16),
                  Text(
                    'Buscando letra…',
                    style: AppTheme.itemTitle.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          final lyrics = snapshot.data;
          if (lyrics == null || lyrics.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space24),
                child: Text(
                  'Letra no disponible para esta canción.',
                  textAlign: TextAlign.center,
                  style: AppTheme.itemTitle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final fontSize = constraints.maxWidth < 600
                  ? AppTheme.titleLarge.fontSize!
                  : AppTheme.space32;
              final horizontal = constraints.maxWidth < 600
                  ? AppTheme.space24
                  : AppTheme.space32 + AppTheme.space12;
              final style = AppTheme.titleLarge.copyWith(
                fontSize: fontSize,
                height: 1.3,
                fontWeight: FontWeight.w700,
              );
              final active = lyrics.activeIndexAt(widget.position);
              final offsets = <double>[];
              final heights = <double>[];
              var offset = AppTheme.space24;
              for (final line in lyrics.lines) {
                final painter = TextPainter(
                  text: TextSpan(text: line.text, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: constraints.maxWidth - horizontal * 2);
                offsets.add(offset);
                heights.add(painter.height + AppTheme.space24 + AppTheme.space4);
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
                      AppTheme.space24,
                      horizontal,
                      constraints.maxHeight * .45,
                    ),
                    itemCount: lyrics.lines.length + (lyrics.isSynced ? 0 : 1),
                    itemBuilder: (context, i) {
                      if (i == lyrics.lines.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: AppTheme.space16),
                          child: Text(
                            'Esta letra no incluye tiempos de sincronización.',
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textPrimary.withValues(alpha: 0.7),
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
                                      ? AppTheme.textPrimary
                                      : AppTheme.textPrimary.withValues(
                                          alpha: 0.4,
                                        ),
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
