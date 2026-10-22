import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aura_music/models/song_model.dart';
import 'package:aura_music/services/lyrics_service.dart';
import 'package:aura_music/services/player_service.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:aura_music/widgets/fullscreen_player.dart';
import 'package:aura_music/widgets/lyrics_view.dart';

/// Prepara una canción temporal con .lrc sincronizado y precalienta el caché
/// del servicio compartido. Todo I/O real va en runAsync porque el cuerpo
/// del widget test corre en tiempo falso (FakeAsync).
Future<(Directory, Song)> _setupSong(WidgetTester tester) {
  return tester
      .runAsync(() async {
        final tmp = await Directory.systemTemp.createTemp(
          'aura_lyrics_widget_',
        );
        final base = '${tmp.path}/Tema';
        await File('$base.mp3').writeAsString('fake-audio');
        await File(
          '$base.lrc',
        ).writeAsString('[00:01.00]Primera línea\n[00:05.00]Segunda línea\n');
        final song = Song(
          id: '$base.mp3',
          title: 'Tema',
          artist: 'Artista',
          album: 'Album',
          filePath: '$base.mp3',
          duration: const Duration(minutes: 3),
        );
        final cached = await LyricsService.shared.loadLyrics(song);
        expect(cached, isNotNull);
        expect(cached!.isSynced, isTrue);
        return (tmp, song);
      })
      .then((v) => v!);
}

Future<void> _cleanup(WidgetTester tester, Directory tmp) {
  return tester
      .runAsync(() async {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      })
      .then((_) {
        LyricsService.shared.clearCache();
      });
}

void main() {
  testWidgets('la píldora Letra muestra la letra sincronizada', (
    WidgetTester tester,
  ) async {
    final (tmp, song) = await _setupSong(tester);
    final player = PlayerService();
    await tester.runAsync(() async {
      // Doble del reproductor de escritorio (igual que player_switch_test).
      player.linuxProcessStarter = (exe, args) async {
        final proc = await Process.start('sleep', ['30']);
        return proc;
      };
      await player.playSong(song, playlist: [song]);
    });

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: player),
              ChangeNotifierProvider(create: (_) => MusicStorageService()),
            ],
            child: FullscreenPlayer(onCollapse: () {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // La píldora ahora dice Canción | Letra (ya no Video). 'Letra'
      // aparece dos veces: píldora superior y pestaña inferior.
      expect(find.text('Canción'), findsOneWidget);
      expect(find.text('Letra'), findsNWidgets(2));
      expect(find.text('Video'), findsNothing);
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Guardar en una\nplaylist'), findsOneWidget);
      expect(find.text('Agregar a la fila'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.playlist_play));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(player.queue, hasLength(2));
      expect(player.currentSong, song);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Letra').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Vista estilo YouTube Music con la letra sincronizada cargada.
      expect(find.text('SINCRONIZADA'), findsNothing);
      expect(find.text('Compartir'), findsOneWidget);
      expect(find.byTooltip('Cerrar letra'), findsOneWidget);
      expect(find.text('Primera línea'), findsOneWidget);
      expect(find.text('Segunda línea'), findsOneWidget);
    } finally {
      await tester.runAsync(() => player.stopAndClear());
      player.dispose();
      await _cleanup(tester, tmp);
    }
  });

  testWidgets('la letra sigue un verso fuera de pantalla y permite buscarlo', (
    tester,
  ) async {
    final (tmp, song) = await _setupSong(tester);
    await tester.runAsync(() async {
      await File('${tmp.path}/Tema.lrc').writeAsString(
        List.generate(
          80,
          (i) => '[00:${i.toString().padLeft(2, '0')}.00]Verso número $i',
        ).join('\n'),
      );
      LyricsService.shared.invalidate(song.id);
      await LyricsService.shared.loadLyrics(song);
    });
    Duration? sought;
    Widget view(Duration position) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 500,
          child: LyricsView(
            song: song,
            position: position,
            onSeek: (target) async {
              sought = target;
            },
          ),
        ),
      ),
    );
    try {
      await tester.pumpWidget(view(Duration.zero));
      await tester.pumpAndSettle();
      await tester.pumpWidget(view(const Duration(seconds: 60)));
      await tester.pumpAndSettle();
      expect(find.text('Verso número 60').hitTestable(), findsOneWidget);
      final animated = tester.widget<AnimatedDefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Verso número 60'),
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      );
      expect(animated.style.color, Colors.white);
      expect(animated.style.fontWeight, FontWeight.w700);
      await tester.tap(find.text('Verso número 60'));
      expect(sought, const Duration(seconds: 60));
      expect(tester.takeException(), isNull);
    } finally {
      await _cleanup(tester, tmp);
    }
  });

  testWidgets('tocar una línea de la letra salta a ese momento', (
    WidgetTester tester,
  ) async {
    final (tmp, song) = await _setupSong(tester);
    try {
      Duration? sought;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LyricsView(
              song: song,
              position: Duration.zero,
              onSeek: (target) async {
                sought = target;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Primera línea'), findsOneWidget);
      await tester.tap(find.text('Segunda línea'));
      await tester.pump();
      expect(sought, const Duration(seconds: 5));
    } finally {
      await _cleanup(tester, tmp);
    }
  });
}
