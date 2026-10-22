import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura_music/models/song_model.dart';
import 'package:aura_music/services/player_service.dart';

Song _fakeSong(String name) => Song(
  id: '/tmp/aura_test_$name.mp3',
  title: name,
  artist: 'Artista $name',
  album: 'Album',
  filePath: '/tmp/aura_test_$name.mp3',
  duration: const Duration(minutes: 3),
);

/// Cambiar rápido de canción (tocar A y enseguida tocar B) debe dejar
/// sonando SOLO la última: un único proceso vivo con B.
/// Bug reportado: se quedaba sonando siempre la primera canción porque el
/// proceso de la anterior quedaba huérfano y nunca se mataba.
void main() {
  test('tocar A y enseguida B deja un solo proceso vivo (el de B)', () async {
    final player = PlayerService();
    final started = <Process>[];
    // En vez de gst-play (necesita audio real) se usa `sleep`, que también
    // es un proceso hijo de larga vida: sirve igual para detectar fugas.
    player.linuxProcessStarter = (exe, args) async {
      final proc = await Process.start('sleep', ['30']);
      started.add(proc);
      // Evita advertencias por stderr/stdout sin drenar.
      return proc;
    };

    try {
      final songA = _fakeSong('A');
      final songB = _fakeSong('B');

      // Dos toques seguidos SIN esperar al primero (como en la app, donde
      // el onTap no hace await).
      final first = player.playSong(songA, playlist: [songA, songB]);
      final second = player.playSong(songB, playlist: [songA, songB]);
      await Future.wait([first, second]);
      // Da tiempo a que los arranques pendientes se completen.
      await Future.delayed(const Duration(milliseconds: 500));

      expect(player.currentSong?.id, songB.id);
      // Con el fix, el pedido obsoleto (A) aborta ANTES de arrancar nada:
      // solo debe existir el proceso de la última canción (B). Sin el
      // fix se arrancaban 2 y el de A quedaba huérfano sonando.
      expect(
        started.length,
        1,
        reason: 'BUG: se arrancó más de un proceso (la primera canción queda sonando)',
      );

      var currentExited = false;
      unawaited(started[0].exitCode.then((_) => currentExited = true));
      await Future.delayed(const Duration(milliseconds: 300));
      expect(
        currentExited,
        isFalse,
        reason: 'El proceso de la última canción debe seguir sonando',
      );
    } finally {
      for (final proc in started) {
        try {
          proc.kill();
        } catch (_) {}
      }
      await player.stopAndClear();
      player.dispose();
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'un fallo del proceso deja de mostrar reproducción y expone el error',
    () async {
      final player = PlayerService();
      player.linuxProcessStarter = (exe, args) => Process.start('bash', [
        '-c',
        'echo "ERROR missing plug-in" >&2; exit 1',
      ]);
      try {
        await player.playSong(_fakeSong('error'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(player.isPlaying, isFalse);
        expect(player.playbackError, contains('decodificador'));
        expect(player.position, Duration.zero);
      } finally {
        await player.stopAndClear();
        player.dispose();
      }
    },
  );

  test('cambios secuenciales (con await) siguen funcionando', () async {
    final player = PlayerService();
    final started = <Process>[];
    player.linuxProcessStarter = (exe, args) async {
      final proc = await Process.start('sleep', ['30']);
      started.add(proc);
      return proc;
    };

    try {
      final songA = _fakeSong('A');
      final songB = _fakeSong('B');

      await player.playSong(songA, playlist: [songA, songB]);
      await Future.delayed(const Duration(milliseconds: 300));
      await player.playSong(songB, playlist: [songA, songB]);
      await Future.delayed(const Duration(milliseconds: 300));

      expect(player.currentSong?.id, songB.id);
      expect(started.length, 2);
      // El primero debió morir al pasar a la segunda canción.
      await started[0].exitCode.timeout(const Duration(seconds: 5));
    } finally {
      for (final proc in started) {
        try {
          proc.kill();
        } catch (_) {}
      }
      await player.stopAndClear();
      player.dispose();
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
