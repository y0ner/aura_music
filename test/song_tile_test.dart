import 'dart:io';

import 'package:aura_music/models/song_model.dart';
import 'package:aura_music/services/player_service.dart';
import 'package:aura_music/theme/app_theme.dart';
import 'package:aura_music/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('artista desconocido no muestra ese texto y sí la duración', (
    WidgetTester tester,
  ) async {
    final unknownArtistSong = Song(
      id: '/tmp/sin_artista.m4a',
      title: 'Pista sin artista',
      artist: Song.unknownArtist,
      album: 'General',
      filePath: '/tmp/sin_artista.m4a',
      duration: const Duration(minutes: 3, seconds: 25),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SongTile(
            song: unknownArtistSong,
            isCurrent: false,
          ),
        ),
      ),
    );

    expect(find.text('Pista sin artista'), findsOneWidget);
    expect(find.text('Artista desconocido'), findsNothing);
    expect(find.text('3:25'), findsOneWidget);
    expect(find.byTooltip('Más opciones'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('artista conocido respeta showDuration e insignia explícita', (
    WidgetTester tester,
  ) async {
    final explicitSong = Song(
      id: '/tmp/coronamos.m4a',
      title: 'Coronamos',
      artist: 'Lito Kirino y Anuel AA',
      album: 'Trap',
      filePath: '/tmp/coronamos.m4a',
      duration: const Duration(minutes: 3, seconds: 8),
      isExplicit: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Column(
            children: [
              SongTile(
                song: explicitSong,
                showDuration: true,
                isCurrent: false,
              ),
              SongTile(
                song: explicitSong,
                showDuration: false,
                isCurrent: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Lito Kirino y Anuel AA · 3:08'), findsOneWidget);
    expect(find.text('Lito Kirino y Anuel AA'), findsOneWidget);
    expect(find.text('E'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('la canción actual en PlayerService muestra «Sonando ahora»', (
    WidgetTester tester,
  ) async {
    final songA = Song(
      id: '/tmp/a.m4a',
      title: 'Canción A',
      artist: 'Artista A',
      album: 'Album',
      filePath: '/tmp/a.m4a',
      duration: const Duration(minutes: 2, seconds: 30),
    );
    final songB = Song(
      id: '/tmp/b.m4a',
      title: 'Canción B',
      artist: 'Artista B',
      album: 'Album',
      filePath: '/tmp/b.m4a',
      duration: const Duration(minutes: 4, seconds: 10),
    );

    final player = PlayerService();
    await tester.runAsync(() async {
      player.linuxProcessStarter = (exe, args) async {
        return Process.start('sleep', ['30']);
      };
      await player.playSong(songA, playlist: [songA, songB]);
    });

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChangeNotifierProvider.value(
            value: player,
            child: Scaffold(
              body: Column(
                children: [
                  SongTile(song: songA),
                  SongTile(song: songB),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(NowPlayingBars), findsOneWidget);
      expect(find.bySemanticsLabel('Sonando ahora'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.runAsync(() => player.stopAndClear());
      player.dispose();
    }
  });
}
