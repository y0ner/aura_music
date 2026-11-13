import 'dart:async';
import 'dart:io';

import 'package:aura_music/services/playlist_fetcher.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:aura_music/services/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage extends MusicStorageService {
  final Directory directory;
  int scans = 0;
  _FakeStorage(this.directory);
  @override
  Directory get rootMusicDirectory => directory;
  @override
  Future<void> scanLibrary() async {
    scans++;
  }
}

class _FakeBackend extends YoutubeBackend {
  final calls = <String>[];
  bool failTrack = false;

  @override
  Future<PlaylistOverview> playlist(String id) async => const PlaylistOverview(
    title: 'Prueba',
    tracks: [
      PlaylistTrack(videoId: 'AAAAAAAAAAA', title: 'Pista 1'),
      PlaylistTrack(videoId: 'BBBBBBBBBBB', title: 'Pista 2'),
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
    if (failTrack) {
      throw StateError('Fallo simulado en descarga');
    }
    return YoutubeAudio(
      bytes: Stream.value([1, 2, 3, 4]),
      size: 4,
      extension: 'm4a',
      close: () {},
    );
  }

  @override
  void cancelAnalysis() {}

  @override
  void cancelAudio() {}

  @override
  void cancel() {}
}

void main() {
  late Directory directory;
  late Directory testTempDir;
  late _FakeStorage storage;
  late _FakeBackend backend;
  late YoutubeDownloadService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aura_state_test');
    testTempDir = await Directory.systemTemp.createTemp('aura_state_temp');
    storage = _FakeStorage(directory);
    backend = _FakeBackend();
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

  test('tras una descarga exitosa isPreviewDownloaded es true', () async {
    expect(service.isPreviewDownloaded, isFalse);

    final preview = await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
    expect(preview, isNotNull);
    expect(service.isPreviewDownloaded, isFalse);

    final ok = await service.startDownload(storage);
    expect(ok, isTrue);
    expect(service.completedTracks, 1);
    expect(service.failedTracks, 0);
    expect(service.isPreviewDownloaded, isTrue);
  });

  test('tras analyzeUrl de otro enlace vuelve a false', () async {
    await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
    final ok = await service.startDownload(storage);
    expect(ok, isTrue);
    expect(service.isPreviewDownloaded, isTrue);

    await service.analyzeUrl('https://youtu.be/BBBBBBBBBBB');
    expect(service.isPreviewDownloaded, isFalse);
  });

  test('con una pista fallida queda en false', () async {
    backend.failTrack = true;
    await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
    final ok = await service.startDownload(storage);
    expect(ok, isFalse);
    expect(service.failedTracks, 1);
    expect(service.isPreviewDownloaded, isFalse);
  });

  test('un enlace nuevo no hereda las pistas fallidas del anterior', () async {
    backend.failTrack = true;
    await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
    expect(await service.startDownload(storage), isFalse);
    expect(service.failedTracks, 1);
    await service.analyzeUrl('https://youtu.be/BBBBBBBBBBB');
    expect(service.failedTracks, 0);
    expect(service.completedTracks, 0);
  });

  test('clearPreview restablece isPreviewDownloaded a false', () async {
    await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
    final ok = await service.startDownload(storage);
    expect(ok, isTrue);
    expect(service.isPreviewDownloaded, isTrue);

    service.clearPreview();
    expect(service.isPreviewDownloaded, isFalse);
    expect(service.preview, isNull);
  });
}
