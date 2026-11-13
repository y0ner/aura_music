import 'dart:async';
import 'dart:io';

import 'package:aura_music/models/download_job.dart';
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
  Completer<void>? blocked;

  @override
  Future<PlaylistOverview> playlist(String id) async => PlaylistOverview(
    title: 'Playlist $id',
    tracks: [
      PlaylistTrack(videoId: '${id}_1', title: 'Pista 1'),
      PlaylistTrack(videoId: '${id}_2', title: 'Pista 2'),
    ],
  );

  @override
  Future<YoutubePreview> video(String id) async => YoutubePreview(
    isPlaylist: false,
    id: id,
    title: 'Canción $id',
    author: 'Artista',
    thumbnailUrl: '',
  );

  @override
  Future<YoutubeAudio> audio(String id, int attempt) async {
    calls.add('$id:$attempt');
    if (blocked != null && !blocked!.isCompleted) {
      await blocked!.future;
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
  void cancelAudio() {
    if (blocked != null && !blocked!.isCompleted) {
      blocked!.complete();
    }
  }

  @override
  void cancel() {
    cancelAnalysis();
    cancelAudio();
  }
}

void main() {
  late Directory directory;
  late Directory testTempDir;
  late FakeStorage storage;
  late FakeBackend backend;
  late YoutubeDownloadService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aura_queue_test');
    testTempDir = await Directory.systemTemp.createTemp('aura_queue_temp');
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
    'mientras el job 1 está bloqueado se encola otro enlace y terminan en orden',
    () async {
      backend.blocked = Completer<void>();
      await service.analyzeUrl('https://youtube.com/playlist?list=PLuno');
      final job1 = service.enqueue(storage);
      expect(job1, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.isDownloading, isTrue);
      expect(job1!.status, DownloadJobStatus.downloading);

      await service.analyzeUrl('https://youtube.com/playlist?list=PLdos');
      final job2 = service.enqueue(storage);
      expect(job2, isNotNull);
      expect(job2!.status, DownloadJobStatus.waiting);
      expect(service.waitingCount, 1);

      backend.blocked!.complete();
      final r1 = await job1.completer.future;
      final r2 = await job2.completer.future;

      expect(r1, isTrue);
      expect(r2, isTrue);
      expect(job1.status, DownloadJobStatus.done);
      expect(job2.status, DownloadJobStatus.done);

      final job1Calls = backend.calls
          .where((c) => c.startsWith('PLuno'))
          .toList();
      final job2Calls = backend.calls
          .where((c) => c.startsWith('PLdos'))
          .toList();
      expect(job1Calls, hasLength(2));
      expect(job2Calls, hasLength(2));

      final lastJob1Index = backend.calls.lastIndexOf(job1Calls.last);
      final firstJob2Index = backend.calls.indexOf(job2Calls.first);
      expect(lastJob1Index, lessThan(firstJob2Index));
    },
  );

  test('removeJob de un job waiting nunca se descarga', () async {
    backend.blocked = Completer<void>();
    await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
    final job1 = service.enqueue(storage);
    expect(job1, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(service.isDownloading, isTrue);

    await service.analyzeUrl('https://youtu.be/BBBBBBBBBBB');
    final job2 = service.enqueue(storage);
    expect(job2, isNotNull);
    expect(job2!.status, DownloadJobStatus.waiting);

    service.removeJob(job2.id);
    expect(service.jobs.contains(job2), isFalse);

    backend.blocked!.complete();
    await job1!.completer.future;
    expect(job1.status, DownloadJobStatus.done);

    expect(backend.calls.any((c) => c.startsWith('BBBBBBBBBBB')), isFalse);
  });

  test('cancel() durante el job 1 lo cancela y el job 2 termina done', () async {
    backend.blocked = Completer<void>();
    await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
    final job1 = service.enqueue(storage);
    expect(job1, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(service.isDownloading, isTrue);

    await service.analyzeUrl('https://youtu.be/BBBBBBBBBBB');
    final job2 = service.enqueue(storage);
    expect(job2, isNotNull);
    expect(job2!.status, DownloadJobStatus.waiting);

    service.cancel();
    final r1 = await job1!.completer.future;
    final r2 = await job2.completer.future;

    expect(r1, isFalse);
    expect(r2, isTrue);
    expect(job1.status, DownloadJobStatus.cancelled);
    expect(job2.status, DownloadJobStatus.done);
  });

  test(
    'encolar dos veces el mismo preview.id mientras espera devuelve null',
    () async {
      backend.blocked = Completer<void>();
      await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
      final job1 = service.enqueue(storage);
      expect(job1, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      await service.analyzeUrl('https://youtu.be/BBBBBBBBBBB');
      final job2 = service.enqueue(storage);
      expect(job2, isNotNull);
      expect(job2!.status, DownloadJobStatus.waiting);

      final duplicate = service.enqueue(storage);
      expect(duplicate, isNull);
      expect(service.statusMessage, 'Ya está en la cola.');
      expect(
        service.jobs.where((j) => j.preview.id == 'BBBBBBBBBBB'),
        hasLength(1),
      );

      backend.blocked!.complete();
      await job1!.completer.future;
      await job2.completer.future;
    },
  );

  test(
    'clearPreview() durante una descarga no la cancela y termina done',
    () async {
      backend.blocked = Completer<void>();
      await service.analyzeUrl('https://youtu.be/AAAAAAAAAAA');
      final job1 = service.enqueue(storage);
      expect(job1, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.isDownloading, isTrue);

      service.clearPreview();
      expect(service.preview, isNull);
      expect(service.isDownloading, isTrue);
      expect(job1!.status, DownloadJobStatus.downloading);

      backend.blocked!.complete();
      final result = await job1.completer.future;
      expect(result, isTrue);
      expect(job1.status, DownloadJobStatus.done);
    },
  );
}
