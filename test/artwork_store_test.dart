import 'dart:io';
import 'dart:typed_data';

import 'package:aura_music/services/artwork_store.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('artwork_store', () {
    test('videoIdFromPath extrae id con corchetes, rechaza sin id y admite espacios y emojis', () {
      // Con corchetes
      expect(
        videoIdFromPath('Canción [SqAGWRpccm0].m4a'),
        'SqAGWRpccm0',
      );
      expect(
        videoIdFromPath('/storage/emulated/0/Music/AuraMusic/Canción [SqAGWRpccm0].m4a'),
        'SqAGWRpccm0',
      );

      // Sin id
      expect(videoIdFromPath('Canción sin id.mp3'), isNull);
      expect(videoIdFromPath('/Music/Canción [corto].m4a'), isNull);
      expect(videoIdFromPath('Canción [123456789012].m4a'), isNull);
      expect(videoIdFromPath(''), isNull);

      // Con espacios y emojis
      expect(
        videoIdFromPath('#1 Urbano 😏🔥💯/01. Título con espacios y acento 🎵 [SqAGWRpccm0].m4a'),
        'SqAGWRpccm0',
      );
      expect(
        videoIdFromPath('/Music/🔥 Hits 2026/Track 🚀 [AAAAAAAAAAA].webm'),
        'AAAAAAAAAAA',
      );
    });

    test('artworkFileFor construye la ruta esperada', () {
      final dir = Directory('/tmp/aura_covers');
      final file = artworkFileFor(dir, 'SqAGWRpccm0');
      expect(file.path, '/tmp/aura_covers/SqAGWRpccm0.jpg');
    });

    test('MusicStorageService asocia carátula privada desde artworkDirectory', () async {
      final root = await Directory.systemTemp.createTemp('aura_music_test');
      final tmpCovers = await Directory.systemTemp.createTemp('aura_covers_test');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
        if (await tmpCovers.exists()) await tmpCovers.delete(recursive: true);
      });

      final playlistDir = Directory('${root.path}/Mi lista');
      await playlistDir.create(recursive: true);
      final songFile = File('${playlistDir.path}/Canción [AAAAAAAAAAA].m4a');
      await songFile.writeAsBytes([1, 2, 3, 4]);

      final coverBytes = Uint8List.fromList([10, 20, 30, 40]);
      final coverFile = File('${tmpCovers.path}/AAAAAAAAAAA.jpg');
      await coverFile.writeAsBytes(coverBytes);

      final storage = MusicStorageService(artworkDirectory: () async => tmpCovers);
      await storage.setCustomRootDirectory(root.path);

      expect(storage.allSongs, hasLength(1));
      expect(storage.allSongs.first.artworkBytes, equals(coverBytes));
    });

    test('deleteSongFile borra la carátula privada además del archivo de audio', () async {
      final root = await Directory.systemTemp.createTemp('aura_music_del_test');
      final tmpCovers = await Directory.systemTemp.createTemp('aura_covers_del_test');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
        if (await tmpCovers.exists()) await tmpCovers.delete(recursive: true);
      });

      final playlistDir = Directory('${root.path}/Mi lista');
      await playlistDir.create(recursive: true);
      final songFile = File('${playlistDir.path}/Canción [AAAAAAAAAAA].m4a');
      await songFile.writeAsBytes([1, 2, 3, 4]);

      final coverFile = File('${tmpCovers.path}/AAAAAAAAAAA.jpg');
      await coverFile.writeAsBytes([10, 20, 30, 40]);

      final storage = MusicStorageService(artworkDirectory: () async => tmpCovers);
      await storage.setCustomRootDirectory(root.path);

      expect(storage.allSongs, hasLength(1));
      final deleted = await storage.deleteSongFile(storage.allSongs.first);
      expect(deleted, isTrue);

      expect(await songFile.exists(), isFalse);
      expect(await coverFile.exists(), isFalse);
      expect(storage.allSongs, isEmpty);
    });
  });
}
