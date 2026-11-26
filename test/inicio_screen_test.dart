import 'dart:io';

import 'package:aura_music/screens/inicio_screen.dart';
import 'package:aura_music/services/library_state_store.dart';
import 'package:aura_music/services/player_service.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:aura_music/theme/app_theme.dart';
import 'package:aura_music/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

typedef _TestEnv = ({
  Directory root,
  Directory covers,
  Directory stateDir,
  MusicStorageService storage,
});

Future<_TestEnv> _setupStorage(
  WidgetTester tester, {
  bool withSongs = true,
  int extraPlaylists = 0,
}) {
  return tester
      .runAsync(() async {
        final root = await Directory.systemTemp.createTemp('aura_inicio_root_');
        final covers = await Directory.systemTemp.createTemp('aura_inicio_cov_');
        final stateDir = await Directory.systemTemp.createTemp(
          'aura_inicio_state_',
        );

        if (withSongs) {
          final rockDir = Directory('${root.path}/Rock')..createSync();
          await File(
            '${rockDir.path}/The Weeknd - Call Out My Name.m4a',
          ).writeAsBytes([]);

          final urbanoDir = Directory('${root.path}/Urbano')..createSync();
          await File('${urbanoDir.path}/Anuel AA - Coronamos.m4a')
              .writeAsBytes([]);

          for (var i = 1; i <= extraPlaylists; i++) {
            final extraDir = Directory('${root.path}/Mix $i')..createSync();
            await File('${extraDir.path}/Tema $i.m4a').writeAsBytes([]);
          }
        }

        final storage = MusicStorageService(
          artworkDirectory: () async => covers,
          stateStore: LibraryStateStore(directoryProvider: () async => stateDir),
        );
        await storage.setCustomRootDirectory(root.path);
        return (
          root: root,
          covers: covers,
          stateDir: stateDir,
          storage: storage,
        );
      })
      .then((value) => value!);
}

Future<void> _cleanupEnv(
  WidgetTester tester,
  _TestEnv env,
  PlayerService player,
) {
  return tester
      .runAsync(() async {
        await player.stopAndClear();
        await env.storage.stateStore.flush();
        for (final dir in [env.root, env.covers, env.stateDir]) {
          try {
            if (await dir.exists()) await dir.delete(recursive: true);
          } catch (e) {
            debugPrint('Error limpiando directorio temporal: $e');
          }
        }
      })
      .then((_) {
        player.dispose();
        env.storage.dispose();
      });
}

void main() {
  testWidgets(
    'muestra «Música que te gustó», playlists reales y oculta «Escuchado hace poco» hasta registrar reproducción',
    (WidgetTester tester) async {
      // Pantalla de celular (≈392 × 851): con la de 800 × 600 por defecto la
      // cuadrícula 3 × 3 empuja «Escuchado hace poco» fuera de la vista.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final env = await _setupStorage(tester);
      final player = PlayerService();
      player.linuxProcessStarter = (exe, args) async {
        return Process.start('sleep', ['30']);
      };
      var searchTapped = false;
      var settingsTapped = false;

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: env.storage),
                ChangeNotifierProvider.value(value: player),
              ],
              child: Scaffold(
                body: InicioScreen(
                  onOpenSearch: () => searchTapped = true,
                  onOpenSettings: () => settingsTapped = true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Aura'), findsOneWidget);
        expect(find.text('Música que te gustó'), findsOneWidget);
        expect(find.text('Rock'), findsWidgets);
        expect(find.text('Urbano'), findsWidgets);
        expect(find.text('Escuchado hace poco'), findsNothing);
        expect(find.text('Tu biblioteca está vacía'), findsNothing);

        // Registra una reproducción y verifica que aparece «Escuchado hace poco».
        final firstSong = env.storage.allSongs.first;
        await tester.runAsync(() async {
          env.storage.recordPlay(firstSong);
          await env.storage.stateStore.flush();
          await player.playSong(firstSong, playlist: env.storage.allSongs);
        });
        await tester.pump();

        expect(find.text('Escuchado hace poco'), findsOneWidget);
        expect(find.text('Más'), findsOneWidget);
        expect(find.byType(NowPlayingBars), findsAtLeastNWidgets(1));

        await tester.tap(find.byTooltip('Buscar'));
        await tester.tap(find.byTooltip('Ajustes'));
        expect(searchTapped, isTrue);
        expect(settingsTapped, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _cleanupEnv(tester, env, player);
      }
    },
  );

  testWidgets(
    'pagina la cuadrícula 3 × 3 cuando hay más de 9 playlists',
    (WidgetTester tester) async {
      final env = await _setupStorage(tester, extraPlaylists: 7);
      final player = PlayerService();

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: env.storage),
                ChangeNotifierProvider.value(value: player),
              ],
              child: const Scaffold(body: InicioScreen()),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(PageView), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _cleanupEnv(tester, env, player);
      }
    },
  );

  testWidgets(
    'con la biblioteca vacía muestra el botón «Añadir música» y llama onAddMusic',
    (WidgetTester tester) async {
      final env = await _setupStorage(tester, withSongs: false);
      final player = PlayerService();
      var addMusicTapped = false;

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: env.storage),
                ChangeNotifierProvider.value(value: player),
              ],
              child: Scaffold(
                body: InicioScreen(
                  onAddMusic: () => addMusicTapped = true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
        expect(find.text('Añadir música'), findsOneWidget);

        await tester.tap(find.text('Añadir música'));
        await tester.pump();
        expect(addMusicTapped, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _cleanupEnv(tester, env, player);
      }
    },
  );
}
