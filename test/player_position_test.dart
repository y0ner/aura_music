import 'dart:io';

import 'package:aura_music/models/song_model.dart';
import 'package:aura_music/services/player_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'el avance de la canción va por positionListenable y no redibuja la app',
    () async {
      final player = PlayerService();
      // Doble del reproductor de escritorio (como en player_switch_test).
      player.linuxProcessStarter = (exe, args) => Process.start('sleep', [
        '30',
      ]);
      final song = Song(
        id: '/tmp/aura_posicion.m4a',
        title: 'Posición',
        artist: 'Prueba',
        album: 'Pruebas',
        filePath: '/tmp/aura_posicion.m4a',
        duration: const Duration(minutes: 3),
      );

      try {
        await player.playSong(song, playlist: [song]);

        var appNotifications = 0;
        var positionTicks = 0;
        player.addListener(() => appNotifications++);
        player.positionListenable.addListener(() => positionTicks++);

        // En escritorio la posición avanza con un temporizador de 1 s.
        await Future<void>.delayed(const Duration(milliseconds: 2300));

        expect(positionTicks, greaterThanOrEqualTo(2));
        expect(player.position, player.positionListenable.value);
        expect(appNotifications, 0);
      } finally {
        await player.stopAndClear();
        player.dispose();
      }
    },
    skip: !Platform.isLinux,
  );
}
