import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aura_music/models/song_model.dart';
import 'package:aura_music/services/player_service.dart';
import 'package:aura_music/theme/app_theme.dart';
import 'package:aura_music/widgets/mini_player.dart';

Song _makeSong({
  required String id,
  required String title,
  required String artist,
  Duration duration = const Duration(minutes: 3, seconds: 8),
  bool isExplicit = false,
}) {
  return Song(
    id: id,
    title: title,
    artist: artist,
    album: 'Álbum',
    filePath: id,
    duration: duration,
    isExplicit: isExplicit,
  );
}

void main() {
  testWidgets('muestra el título, el artista y los tooltips de control', (
    WidgetTester tester,
  ) async {
    final player = PlayerService();
    await tester.runAsync(() async {
      player.linuxProcessStarter = (exe, args) async =>
          Process.start('sleep', ['30']);
      await player.playSong(
        _makeSong(
          id: '/tmp/aura_mini_conocido.mp3',
          title: 'Coronamos',
          artist: 'Lito Kirino y Anuel AA',
        ),
      );
    });

    var expanded = false;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChangeNotifierProvider.value(
                value: player,
                child: MiniPlayer(onExpand: () => expanded = true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Coronamos'), findsOneWidget);
      expect(find.text('Lito Kirino y Anuel AA'), findsOneWidget);
      expect(find.byTooltip('Pausar'), findsOneWidget);
      expect(find.byTooltip('Siguiente'), findsOneWidget);

      await tester.runAsync(() => player.togglePlayPause());
      await tester.pump();
      expect(find.byTooltip('Reproducir'), findsOneWidget);

      await tester.tap(find.text('Coronamos'));
      await tester.pump();
      expect(expanded, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.runAsync(() => player.stopAndClear());
      player.dispose();
    }
  });

  testWidgets(
    'con artista desconocido no muestra "Artista desconocido" y sí la duración',
    (WidgetTester tester) async {
      final player = PlayerService();
      final song = _makeSong(
        id: '/tmp/aura_mini_desconocido.mp3',
        title: 'Tema sin artista',
        artist: Song.unknownArtist,
        duration: const Duration(minutes: 4, seconds: 12),
        isExplicit: true,
      );
      await tester.runAsync(() async {
        player.linuxProcessStarter = (exe, args) async =>
            Process.start('sleep', ['30']);
        await player.playSong(song);
      });

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ChangeNotifierProvider.value(
                  value: player,
                  child: MiniPlayer(onExpand: () {}),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Tema sin artista'), findsOneWidget);
        expect(find.text(Song.unknownArtist), findsNothing);
        expect(find.textContaining(Song.unknownArtist), findsNothing);
        expect(find.text('4:12'), findsOneWidget);
        expect(find.text('E'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(() => player.stopAndClear());
        player.dispose();
      }
    },
  );
}
