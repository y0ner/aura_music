import 'dart:io';

import 'package:aura_music/screens/buscar_screen.dart';
import 'package:aura_music/services/library_state_store.dart';
import 'package:aura_music/services/player_service.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:aura_music/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

typedef _SearchEnv = ({
  Directory root,
  Directory covers,
  Directory stateDir,
  MusicStorageService storage,
});

Future<_SearchEnv> _setupStorage(WidgetTester tester) {
  return tester
      .runAsync(() async {
        final root = await Directory.systemTemp.createTemp('aura_busc_root_');
        final covers = await Directory.systemTemp.createTemp('aura_busc_cov_');
        final stateDir = await Directory.systemTemp.createTemp(
          'aura_busc_state_',
        );

        final urbanoDir = Directory('${root.path}/Urbano')..createSync();
        await File('${urbanoDir.path}/Esto Es Así [12345678901].m4a')
            .writeAsBytes([]);

        final popDir = Directory('${root.path}/Pop')..createSync();
        await File(
          '${popDir.path}/The Weeknd - Call Out My Name [abcdefghijk].m4a',
        ).writeAsBytes([]);

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
  _SearchEnv env,
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
    'busca sin tildes, guarda en recientes, rellena al usar y borra el historial',
    (WidgetTester tester) async {
      final env = await _setupStorage(tester);
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
                ChangeNotifierProvider.value(value: env.storage),
                ChangeNotifierProvider.value(value: player),
              ],
              child: const Scaffold(body: BuscarScreen()),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Explora tu música'), findsOneWidget);
        expect(find.text('Recién añadidas'), findsOneWidget);
        expect(find.text('Más escuchadas'), findsNothing);
        expect(find.text('Música que te gustó'), findsNothing);
        expect(find.text('Borrar historial'), findsNothing);

        await tester.enterText(find.byType(TextField), 'asi');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.runAsync(() => env.storage.stateStore.flush());
        await tester.pump();

        expect(find.text('Canciones'), findsOneWidget);
        expect(find.text('Esto Es Así'), findsOneWidget);
        expect(find.text('Call Out My Name'), findsNothing);
        expect(env.storage.recentSearches, ['asi']);

        // Limpia el campo y comprueba que la búsqueda aparece en recientes.
        await tester.tap(find.byTooltip('Borrar búsqueda'));
        await tester.pump();

        expect(find.text('asi'), findsOneWidget);
        expect(find.byTooltip('Usar búsqueda asi'), findsOneWidget);
        expect(find.text('Borrar historial'), findsOneWidget);

        // El botón north_west rellena el campo con la búsqueda guardada.
        await tester.tap(find.byTooltip('Usar búsqueda asi'));
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          'asi',
        );
        expect(find.text('Esto Es Así'), findsOneWidget);

        // Vuelve al historial vacío y borra todo el historial.
        await tester.tap(find.byTooltip('Borrar búsqueda'));
        await tester.pump();
        await tester.tap(find.text('Borrar historial'));
        await tester.runAsync(() => env.storage.stateStore.flush());
        await tester.pump();

        expect(find.text('asi'), findsNothing);
        expect(env.storage.recentSearches, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _cleanupEnv(tester, env, player);
      }
    },
  );

  testWidgets(
    'muestra playlists coincidentes, estado sin resultados y reproduce canciones',
    (WidgetTester tester) async {
      final env = await _setupStorage(tester);
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
                ChangeNotifierProvider.value(value: env.storage),
                ChangeNotifierProvider.value(value: player),
              ],
              child: const Scaffold(body: BuscarScreen()),
            ),
          ),
        );
        await tester.pump();

        // Coincidencia con playlist y canción de la carpeta Urbano.
        await tester.enterText(find.byType(TextField), 'urb');
        await tester.pump();

        expect(find.text('Playlists'), findsOneWidget);
        expect(find.text('Urbano'), findsOneWidget);
        expect(find.text('Esto Es Así'), findsOneWidget);

        // Tocar la canción la reproduce con los resultados como cola.
        await tester.runAsync(() async {
          await tester.tap(find.text('Esto Es Así'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        expect(player.currentSong?.title, 'Esto Es Así');
        expect(player.queue.map((s) => s.title), ['Esto Es Así']);

        // Consulta sin coincidencias.
        await tester.enterText(find.byType(TextField), 'inexistente');
        await tester.pump();
        expect(find.text('Sin resultados para "inexistente"'), findsOneWidget);

        // Con historial y campo vacío aparece «Reproducido hace poco».
        await tester.runAsync(() async {
          env.storage.recordPlay(env.storage.allSongs.first);
          await env.storage.stateStore.flush();
        });
        await tester.tap(find.byTooltip('Borrar búsqueda'));
        await tester.pump();
        expect(find.text('Reproducido hace poco'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _cleanupEnv(tester, env, player);
      }
    },
  );
}
