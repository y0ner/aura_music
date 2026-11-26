import 'dart:io';

import 'package:aura_music/screens/library_screen.dart';
import 'package:aura_music/services/player_service.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:aura_music/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<(Directory, Directory, MusicStorageService)> _setupLibrary(
  WidgetTester tester,
) {
  return tester
      .runAsync(() async {
        final root = await Directory.systemTemp.createTemp('aura_lib_root_');
        final covers = await Directory.systemTemp.createTemp('aura_lib_cov_');

        final rockDir = Directory('${root.path}/Rock')..createSync();
        await File('${rockDir.path}/Pista Uno.m4a').writeAsBytes([]);
        await File('${rockDir.path}/Pista Dos.m4a').writeAsBytes([]);

        final trapDir = Directory('${root.path}/Trap Latino')..createSync();
        await File('${trapDir.path}/Tema Trap.m4a').writeAsBytes([]);

        final storage = MusicStorageService(
          artworkDirectory: () async => covers,
        );
        await storage.setCustomRootDirectory(root.path);
        return (root, covers, storage);
      })
      .then((value) => value!);
}

Future<void> _cleanupLibrary(
  WidgetTester tester,
  Directory root,
  Directory covers,
  MusicStorageService storage,
  PlayerService player,
) {
  return tester
      .runAsync(() async {
        await player.stopAndClear();
        try {
          if (await root.exists()) await root.delete(recursive: true);
        } catch (e) {
          debugPrint('Error limpiando root temporal: $e');
        }
        try {
          if (await covers.exists()) await covers.delete(recursive: true);
        } catch (e) {
          debugPrint('Error limpiando covers temporal: $e');
        }
      })
      .then((_) {
        player.dispose();
        storage.dispose();
      });
}

void main() {
  testWidgets(
    'muestra playlists de carpeta y Me gusta, filtra canciones y oculta FAB sin callback',
    (WidgetTester tester) async {
      final (root, covers, storage) = await _setupLibrary(tester);
      final player = PlayerService();
      player.linuxProcessStarter = (exe, args) async {
        return Process.start('sleep', ['30']);
      };

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: storage),
                ChangeNotifierProvider.value(value: player),
              ],
              child: const Scaffold(body: LibraryScreen()),
            ),
          ),
        );
        await tester.pump();

        // Cabecera y playlists reales + «Música que te gustó» arriba.
        expect(find.text('Biblioteca'), findsOneWidget);
        expect(find.text('Música que te gustó'), findsOneWidget);
        expect(find.text('Rock'), findsOneWidget);
        expect(find.text('Trap Latino'), findsOneWidget);

        // Sin onCreatePlaylist ni onSearch no debe existir FAB, playlist_add ni menu.
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Nueva playlist'), findsNothing);
        expect(find.byIcon(Icons.playlist_add), findsNothing);
        expect(find.byIcon(Icons.menu), findsNothing);
        expect(find.byTooltip('Buscar en la biblioteca'), findsNothing);

        // Alterna orden y vista de cuadrícula.
        await tester.tap(find.text('Nombre'));
        await tester.pump();
        expect(find.text('Más canciones'), findsOneWidget);

        await tester.tap(find.byTooltip('Ver como cuadrícula'));
        await tester.pump();
        expect(find.byTooltip('Ver como lista'), findsOneWidget);

        // Cambia al chip «Canciones».
        await tester.tap(find.text('Canciones'));
        await tester.pumpAndSettle();

        expect(find.text('Pista Uno'), findsOneWidget);
        expect(find.text('Pista Dos'), findsOneWidget);
        expect(find.text('Tema Trap'), findsOneWidget);
        expect(find.text('Artista desconocido'), findsNothing);
        expect(find.text('3 canciones'), findsOneWidget);

        // Filtra por el chip de la carpeta «Rock».
        await tester.tap(find.text('Rock'));
        await tester.pumpAndSettle();

        expect(find.text('Pista Uno'), findsOneWidget);
        expect(find.text('Pista Dos'), findsOneWidget);
        expect(find.text('Tema Trap'), findsNothing);
        expect(find.text('2 canciones'), findsOneWidget);

        // Filtra por el chip «Trap Latino».
        await tester.tap(find.text('Trap Latino'));
        await tester.pumpAndSettle();

        expect(find.text('Tema Trap'), findsOneWidget);
        expect(find.text('Pista Uno'), findsNothing);
        expect(find.text('1 canción'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _cleanupLibrary(tester, root, covers, storage, player);
      }
    },
  );

  testWidgets('muestra FAB y buscar cuando recibe callbacks', (
    WidgetTester tester,
  ) async {
    final (root, covers, storage) = await _setupLibrary(tester);
    final player = PlayerService();
    var searchTapped = false;
    var createTapped = false;

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: storage),
              ChangeNotifierProvider.value(value: player),
            ],
            child: Scaffold(
              body: LibraryScreen(
                onSearch: () => searchTapped = true,
                onCreatePlaylist: () => createTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Nueva playlist'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byTooltip('Buscar en la biblioteca'), findsOneWidget);

      await tester.tap(find.byTooltip('Buscar en la biblioteca'));
      await tester.tap(find.text('Nueva playlist'));
      expect(searchTapped, isTrue);
      expect(createTapped, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await _cleanupLibrary(tester, root, covers, storage, player);
    }
  });
}
