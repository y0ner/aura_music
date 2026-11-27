import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aura_music/main.dart';
import 'package:aura_music/services/player_service.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:aura_music/services/youtube_service.dart';

void main() {
  testWidgets(
    'usa barra inferior de 4 destinos, abre ajustes y navega entre pestañas',
    (WidgetTester tester) async {
      final storage = MusicStorageService();
      final player = PlayerService();
      final youtube = YoutubeDownloadService();

      try {
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

        // Barra inferior nueva con 4 destinos.
        expect(find.text('Inicio'), findsOneWidget);
        expect(find.text('Buscar'), findsOneWidget);
        expect(find.text('Biblioteca'), findsOneWidget);
        expect(find.text('Añadir'), findsOneWidget);

        // Sin restos de la navegación ni de la marca anterior.
        expect(find.text('BIBLIOTECA'), findsNothing);
        expect(find.text('DESCARGAS'), findsNothing);
        expect(find.text('YOUTUBE'), findsNothing);
        expect(find.text('Abrir app'), findsNothing);
        expect(find.byIcon(Icons.menu), findsNothing);

        // Ajustes abre la hoja «Configuración» y su flujo de crear playlist.
        await tester.tap(find.byTooltip('Ajustes'));
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

        await tester.tap(find.byTooltip('Ajustes'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Cerrar configuración'));
        await tester.pumpAndSettle();
        expect(find.text('Configuración'), findsNothing);

        // Tocar «Añadir» muestra la pantalla «Añadir música».
        await tester.tap(find.text('Añadir'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          3,
        );
        expect(find.text('Añadir música'), findsAtLeastNWidgets(1));
        expect(find.text('Analizar enlace'), findsOneWidget);

        // El botón atrás fuera de Inicio vuelve a Inicio en lugar de salir.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          0,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        youtube.dispose();
        player.dispose();
        storage.dispose();
      }
    },
  );
}
