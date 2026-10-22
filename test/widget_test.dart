import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aura_music/main.dart';
import 'package:aura_music/services/player_service.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:aura_music/services/youtube_service.dart';

void main() {
  testWidgets('la aplicación muestra sus pestañas principales', (
    WidgetTester tester,
  ) async {
    final storage = MusicStorageService();
    final player = PlayerService();
    final youtube = YoutubeDownloadService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: storage),
          ChangeNotifierProvider.value(value: player),
          ChangeNotifierProvider.value(value: youtube),
        ],
        child: const AuraMusicApp(),
      ),
    );
    await tester.pump();

    expect(find.text('BIBLIOTECA'), findsOneWidget);
    expect(find.text('DESCARGAS'), findsOneWidget);
    expect(find.text('YOUTUBE'), findsOneWidget);

    // The hamburger opens the actual folder settings, not the track menu.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Configuración'), findsOneWidget);
    expect(find.byTooltip('Cerrar configuración'), findsOneWidget);
    expect(find.text('Crear una\nplaylist'), findsOneWidget);
    expect(find.text('Elegir\ncarpeta'), findsOneWidget);
    expect(find.text('Actualizar\nbiblioteca'), findsOneWidget);
    expect(find.text('Seleccionar carpeta de música'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.playlist_add).first);
    await tester.pumpAndSettle();
    expect(find.text('Crear Playlist (Subcarpeta)'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar configuración'));
    await tester.pumpAndSettle();
    expect(find.text('Configuración'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    youtube.dispose();
    player.dispose();
    storage.dispose();
  });
}
