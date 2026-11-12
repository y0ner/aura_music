import 'dart:async';
import 'dart:io';

import 'package:aura_music/services/playlist_fetcher.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:aura_music/services/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStorage extends MusicStorageService {
  final Directory directory;
  int scans = 0;
  FakeStorage(this.directory);
  @override
  Directory get rootMusicDirectory => directory;
  @override
  Future<void> scanLibrary() async {
    scans++;
  }
}

class FakeBackend extends YoutubeBackend {
  final calls = <String>[];
  bool failSecond = false;
  bool incompleteFirst = false;
  Completer<void>? blocked;
  Stream<List<int>> Function(String id, int attempt)? audioStreamBuilder;
  int? audioSize;
  @override
  Future<PlaylistOverview> playlist(String id) async => const PlaylistOverview(
    title: 'Prueba',
    tracks: [
      PlaylistTrack(videoId: 'AAAAAAAAAAA', title: 'Mismo título'),
      PlaylistTrack(videoId: 'BBBBBBBBBBB', title: 'Mismo título'),
      PlaylistTrack(videoId: 'CCCCCCCCCCC', title: 'Tercera'),
    ],
  );
  @override
  Future<YoutubePreview> video(String id) async => YoutubePreview(
    isPlaylist: false,
    id: id,
    title: 'Individual',
    author: 'Artista',
    thumbnailUrl: '',
  );
  @override
  Future<YoutubeAudio> audio(String id, int attempt) async {
    calls.add('$id:$attempt');
    if (blocked != null) await blocked!.future;
    if (failSecond && id == 'BBBBBBBBBBB') throw StateError('No disponible');
    return YoutubeAudio(
      bytes: audioStreamBuilder != null
          ? audioStreamBuilder!(id, attempt)
          : Stream.value([1, 2, 3, 4]),
      size: audioSize ?? (incompleteFirst && attempt == 0 ? 8 : 4),
      extension: id == 'BBBBBBBBBBB' ? 'webm' : 'm4a',
      close: () {},
    );
  }

  @override
  void cancel() {
    if (blocked != null && !blocked!.isCompleted) blocked!.complete();
  }
}

void main() {
  late Directory directory;
  late Directory testTempDir;
  late FakeStorage storage;
  late FakeBackend backend;
  late YoutubeDownloadService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aura_youtube_test');
    testTempDir = await Directory.systemTemp.createTemp('aura_youtube_temp');
    storage = FakeStorage(directory);
    backend = FakeBackend();
    service = YoutubeDownloadService(
      backend: backend,
      tempDirectory: () async => testTempDir,
    );
  });
  tearDown(() async {
    service.dispose();
    storage.dispose();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    if (await testTempDir.exists()) {
      await testTempDir.delete(recursive: true);
    }
  });

  test(
    'el enlace enviado por el usuario selecciona la playlist, no el vídeo',
    () async {
      final preview = await service.analyzeUrl(
        'https://www.youtube.com/watch?v=Td9DymMNuo0&list=PL0oNlHO4mZfCHBGwxoOfCNHNeJnPDYRHU',
      );
      expect(preview!.isPlaylist, isTrue);
      expect(preview.id, 'PL0oNlHO4mZfCHBGwxoOfCNHNeJnPDYRHU');
      expect(preview.trackCount, 3);
      expect(await service.startDownload(storage), isTrue);
      expect(service.completedTracks, 3);
      expect(service.currentProgress, 1);
      expect(storage.scans, 1);
      final paths = Directory('${directory.path}/Prueba')
          .listSync()
          .map((f) => f.path)
          .toList();
      expect(paths.where((p) => p.endsWith('.m4a')), hasLength(2));
      expect(paths.where((p) => p.endsWith('.webm')), hasLength(1));
      expect(paths.any((p) => p.endsWith('.part')), isFalse);
      expect(backend.calls, hasLength(3));
      // Retry skips complete files and retains distinct tracks sharing a title.
      expect(await service.startDownload(storage), isTrue);
      expect(backend.calls, hasLength(3));
    },
  );

  test(
    'una pista fallida no bloquea las siguientes ni declara éxito completo',
    () async {
      backend.failSecond = true;
      await service.analyzeUrl('https://youtube.com/playlist?list=PLtest');
      expect(await service.startDownload(storage), isFalse);
      expect(service.completedTracks, 2);
      expect(service.failedTracks, 1);
      expect(service.isDownloading, isFalse);
      expect(backend.calls.where((id) => id.startsWith('BBBB')), hasLength(3));
      expect(backend.calls.last, 'CCCCCCCCCCC:0');
      backend.failSecond = false;
      expect(await service.startDownload(storage), isTrue);
      expect(service.completedTracks, 3);
    },
  );

  test(
    'reintenta streams truncados y actualiza el contador de canción individual',
    () async {
      backend.incompleteFirst = true;
      await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
      expect(await service.startDownload(storage), isTrue);
      expect(backend.calls, ['AAAAAAAAAAA:0', 'AAAAAAAAAAA:1']);
      expect(service.completedTracks, 1);
      expect(
        directory.listSync().where((f) => f.path.endsWith('.part')),
        isEmpty,
      );
    },
  );

  test(
    'cancelar no publica audio ni acepta otro análisis durante la descarga',
    () async {
      backend.blocked = Completer<void>();
      await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
      final download = service.startDownload(storage);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.isDownloading, isTrue);
      expect(await service.analyzeUrl('https://youtu.be/BBBBBBBBBBB'), isNull);
      service.clearPreview();
      expect(service.preview!.id, 'AAAAAAAAAAA');
      service.cancel();
      expect(await download, isFalse);
      expect(service.completedTracks, 0);
      expect(service.isDownloading, isFalse);
      expect(directory.listSync(), isEmpty);
    },
  );

  test('valida dominio y admite shorts, embed y enlaces sin esquema', () {
    for (final link in [
      'https://notyoutube.com/watch?v=AAAAAAAAAAA',
      'https://youtube.com/watch?v=bad',
    ]) {
      expect(
        () => YoutubeDownloadService.parseLink(link),
        throwsFormatException,
      );
    }
    for (final link in [
      'youtube.com/shorts/AAAAAAAAAAA',
      'https://youtube.com/embed/AAAAAAAAAAA',
      'https://music.youtube.com/watch?v=AAAAAAAAAAA',
    ]) {
      expect(YoutubeDownloadService.parseLink(link), (
        id: 'AAAAAAAAAAA',
        isPlaylist: false,
      ));
    }
  });

  test('el parcial nunca se escribe en la carpeta de música', () async {
    final firstChunkDelivered = Completer<void>();
    final allowSecondChunk = Completer<void>();

    backend.audioSize = 4;
    backend.audioStreamBuilder = (id, attempt) async* {
      yield [1, 2];
      firstChunkDelivered.complete();
      await allowSecondChunk.future;
      yield [3, 4];
    };

    await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
    final download = service.startDownload(storage);

    await firstChunkDelivered.future;

    final destFiles = directory.listSync(recursive: true);
    expect(destFiles.any((f) => f.path.endsWith('.part')), isFalse);

    final tempFiles = testTempDir.listSync(recursive: true);
    expect(tempFiles.any((f) => f.path.endsWith('.part')), isTrue);
    final tempPart = tempFiles.firstWhere((f) => f.path.endsWith('.part'));
    expect(File(tempPart.path).existsSync(), isTrue);
    expect(File(tempPart.path).lengthSync(), 2);

    allowSecondChunk.complete();
    expect(await download, isTrue);

    final m4aFiles = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.m4a'))
        .toList();
    expect(m4aFiles, hasLength(1));
    expect(m4aFiles.first.lengthSync(), 4);

    expect(
      testTempDir.listSync(recursive: true).any((f) => f.path.endsWith('.part')),
      isFalse,
    );
  });

  test(
    'un error de disco falla rápido, sin reintentos y con mensaje claro',
    () async {
      final existingFile = File('${testTempDir.path}/dummy_file');
      await existingFile.writeAsString('not a dir');

      final failingService = YoutubeDownloadService(
        backend: backend,
        tempDirectory: () async => Directory(existingFile.path),
      );
      addTearDown(failingService.dispose);

      await failingService.analyzeUrl('https://youtu.be/AAAAAAAAAAA');

      final result = await failingService
          .startDownload(storage)
          .timeout(const Duration(seconds: 5));

      expect(result, isFalse);
      expect(
        backend.calls.where((c) => c.startsWith('AAAAAAAAAAA')),
        hasLength(1),
      );
      expect(failingService.statusMessage, contains('carpeta de música'));
    },
  );
}
