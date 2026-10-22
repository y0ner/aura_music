import 'dart:io';

import 'package:aura_music/services/storage_service.dart';
import 'package:aura_music/services/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends MusicStorageService {
  final Directory directory;
  _Storage(this.directory);
  @override
  Directory get rootMusicDirectory => directory;
  @override
  Future<void> scanLibrary() async {}
}

void main() {
  test('descarga real de todas las canciones disponibles de la playlist del usuario', () async {
    final directory = await Directory.systemTemp.createTemp(
      'aura_youtube_live',
    );
    final storage = _Storage(directory);
    final service = YoutubeDownloadService();
    var previous = '';
    service.addListener(() {
      if (previous != service.statusMessage) {
        previous = service.statusMessage;
        stdout.writeln(previous);
      }
    });
    try {
      final preview = await service.analyzeUrl(
        'https://www.youtube.com/watch?v=Td9DymMNuo0&list=PL0oNlHO4mZfCHBGwxoOfCNHNeJnPDYRHU',
      );
      expect(preview, isNotNull, reason: service.statusMessage);
      expect(
        await service.startDownload(storage),
        isTrue,
        reason: service.statusMessage,
      );
      expect(service.completedTracks, preview!.trackCount);
      final files = directory
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      final audioFiles = files
          .where(
            (file) => file.path.endsWith('.m4a') || file.path.endsWith('.webm'),
          )
          .toList();
      expect(audioFiles, hasLength(preview.trackCount));
      expect(files.where((file) => file.path.endsWith('.part')), isEmpty);
      for (final audio in audioFiles) {
        expect(await audio.length(), greaterThan(1000));
        final probe = await Process.run('gst-discoverer-1.0', [audio.path]);
        expect(probe.exitCode, 0, reason: '${probe.stdout}\n${probe.stderr}');
        expect(probe.stdout.toString(), contains('audio'));
      }
    } finally {
      service.dispose();
      storage.dispose();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
