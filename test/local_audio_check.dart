import 'dart:io';

import 'package:aura_music/services/player_service.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la playlist descargada decodifica y se reproduce con el proceso real', () async {
    final root = '${Platform.environment['HOME']}/Music/AuraMusic';
    final directory = Directory('$root/#6 Ultra Slowed Dark Phonk ⚡⚡⚡⚡');
    final plugin =
        '${Directory.current.path}/.dart_tool/linux-codecs/usr/lib/x86_64-linux-gnu/gstreamer-1.0';
    final files = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.m4a'))
        .toList();
    expect(files, hasLength(16));
    for (final file in files) {
      final result = await Process.run(
        'gst-launch-1.0',
        [
          '-q',
          'filesrc',
          'location=${file.path}',
          '!',
          'decodebin',
          '!',
          'audioconvert',
          '!',
          'fakesink',
          'sync=false',
        ],
        environment: {'GST_PLUGIN_PATH': plugin},
      );
      expect(result.exitCode, 0, reason: '${file.path}: ${result.stderr}');
    }
    final storage = MusicStorageService();
    final player = PlayerService();
    try {
      await storage.setCustomRootDirectory(root);
      final songs = storage.allSongs
          .where((s) => File(s.filePath).parent.path == directory.path)
          .toList();
      expect(songs, hasLength(16));
      expect(
        songs.any((s) => RegExp(r'\[[a-zA-Z0-9_-]{11}\]$').hasMatch(s.title)),
        isFalse,
      );
      await player.playSong(songs.first, playlist: songs);
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(player.isPlaying, isTrue, reason: player.playbackError);
      expect(player.position.inSeconds, greaterThanOrEqualTo(1));
      await player.seek(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(player.isPlaying, isTrue, reason: player.playbackError);
      expect(player.playbackError, isNull);
      final mp3 = storage.allSongs.firstWhere(
        (s) => s.filePath.endsWith('.mp3'),
      );
      await player.playSong(mp3);
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(player.isPlaying, isTrue, reason: player.playbackError);
    } finally {
      await player.stopAndClear();
      player.dispose();
      storage.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
