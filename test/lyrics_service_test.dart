import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura_music/models/song_model.dart';
import 'package:aura_music/services/lyrics_fetcher.dart';
import 'package:aura_music/services/lyrics_service.dart';

class FakeLyricsFetcher implements LyricsFetcher {
  int callCount = 0;
  String? nextResult;
  Exception? errorToThrow;

  @override
  Future<String?> fetch({
    required String title,
    String? artist,
    Duration? duration,
  }) async {
    callCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return nextResult;
  }
}

Song _song(String dir, String base, {String? filePath}) => Song(
  id: filePath ?? '$dir/$base.mp3',
  title: base,
  artist: 'Artista',
  album: 'Album',
  filePath: filePath ?? '$dir/$base.mp3',
  duration: const Duration(minutes: 3),
);

void main() {
  group('normalizeForMatch', () {
    test('quita sufijos de descarga y puntuación', () {
      expect(
        LyricsService.normalizeForMatch('APAGA EL CEL(MP3_320K)'),
        'apaga el cel',
      );
      expect(
        LyricsService.normalizeForMatch(
          'DM - Mueka ft. Cosculluela [Audio Oficial](MP3_320K)',
        ),
        'dm mueka ft cosculluela',
      );
    });
  });

  group('loadLyrics', () {
    late Directory tmp;
    late Directory tmpLyrics;
    late FakeLyricsFetcher nullFetcher;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('aura_lyrics_test_');
      tmpLyrics = await Directory.systemTemp.createTemp('aura_lyrics_cache_');
      nullFetcher = FakeLyricsFetcher();
    });

    tearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (e) {
        // cleanup error
      }
      try {
        await tmpLyrics.delete(recursive: true);
      } catch (e) {
        // cleanup error
      }
    });

    test('encuentra Foo.lrc exacto y sincronizado', () async {
      await File('${tmp.path}/Tema.mp3').writeAsString('fake');
      await File('${tmp.path}/Tema.lrc')
          .writeAsString('[00:01.00]Hola\n[00:05.00]Mundo\n');
      final lyrics = await LyricsService(
        fetcher: nullFetcher,
        lyricsDirectory: () async => tmpLyrics,
      ).loadLyrics(_song(tmp.path, 'Tema'));
      expect(lyrics, isNotNull);
      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.length, 2);
      expect(nullFetcher.callCount, 0);
    });

    test('prefiere el sincronizado entre .lrc plano y _private.lrc', () async {
      await File('${tmp.path}/Tema.mp3').writeAsString('fake');
      await File('${tmp.path}/Tema.lrc')
          .writeAsString('Letra plana\nsin marcas\n');
      await File('${tmp.path}/Tema_private.lrc')
          .writeAsString('[00:01.00]Sincronizada\n');
      final lyrics = await LyricsService(
        fetcher: nullFetcher,
        lyricsDirectory: () async => tmpLyrics,
      ).loadLyrics(_song(tmp.path, 'Tema'));
      expect(lyrics, isNotNull);
      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.single.text, 'Sincronizada');
      expect(nullFetcher.callCount, 0);
    });

    test('búsqueda tolerante empareja nombres con sufijos distintos', () async {
      await File('${tmp.path}/APAGA EL CEL (Remix)(MP3_320K).mp3')
          .writeAsString('fake');
      await File('${tmp.path}/APAGA EL CEL(MP3_320K)_private.lrc')
          .writeAsString('[00:01.21]Apaga el cel\n');
      final lyrics = await LyricsService(
        fetcher: nullFetcher,
        lyricsDirectory: () async => tmpLyrics,
      ).loadLyrics(_song(tmp.path, 'APAGA EL CEL (Remix)(MP3_320K)'));
      expect(lyrics, isNotNull);
      expect(lyrics!.isSynced, isTrue);
      expect(nullFetcher.callCount, 0);
    });

    test(
      'prefiere un archivo equivalente con tiempos enteros sobre el exacto plano',
      () async {
        await File('${tmp.path}/Tema.lrc').writeAsString('Letra sin tiempos');
        await File('${tmp.path}/Tema (Audio Oficial)_private.lrc')
            .writeAsString('[00:01]Con tiempos\n[00:05]Segundo verso');
        final lyrics = await LyricsService(
          fetcher: nullFetcher,
          lyricsDirectory: () async => tmpLyrics,
        ).loadLyrics(_song(tmp.path, 'Tema'));
        expect(lyrics!.isSynced, isTrue);
        expect(lyrics.lines.first.text, 'Con tiempos');
        expect(nullFetcher.callCount, 0);
      },
    );

    test('sin archivos devuelve null', () async {
      await File('${tmp.path}/Sola.mp3').writeAsString('fake');
      final lyrics = await LyricsService(
        fetcher: nullFetcher,
        lyricsDirectory: () async => tmpLyrics,
      ).loadLyrics(_song(tmp.path, 'Sola'));
      expect(lyrics, isNull);
    });

    test('cachea por id de canción', () async {
      await File('${tmp.path}/Tema.mp3').writeAsString('fake');
      final lrc = File('${tmp.path}/Tema.lrc');
      await lrc.writeAsString('[00:01.00]Uno\n');
      final service = LyricsService(
        fetcher: nullFetcher,
        lyricsDirectory: () async => tmpLyrics,
      );
      final first = await service.loadLyrics(_song(tmp.path, 'Tema'));
      await lrc.writeAsString('[00:01.00]Dos\n');
      final second = await service.loadLyrics(_song(tmp.path, 'Tema'));
      expect(first!.lines.single.text, 'Uno');
      expect(second!.lines.single.text, 'Uno');
      service.invalidate('${tmp.path}/Tema.mp3');
      final third = await service.loadLyrics(_song(tmp.path, 'Tema'));
      expect(third!.lines.single.text, 'Dos');
      expect(nullFetcher.callCount, 0);
    });
  });

  group('LyricsService con caché y fetcher', () {
    late Directory tmp;
    late Directory tmpLyrics;
    late FakeLyricsFetcher fakeFetcher;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('aura_lyrics_flow_');
      tmpLyrics = await Directory.systemTemp.createTemp('aura_lyrics_flow_c_');
      fakeFetcher = FakeLyricsFetcher();
    });

    tearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (e) {
        // cleanup error
      }
      try {
        await tmpLyrics.delete(recursive: true);
      } catch (e) {
        // cleanup error
      }
    });

    test(
      '1. sin .lrc local: llama al fetcher una vez, guarda <id>.lrc y devuelve letra; segunda instancia lee de caché',
      () async {
        final audioPath = '${tmp.path}/FloyyMenor - BANSHEE [abcdefghijk].mp3';
        await File(audioPath).writeAsString('audio');
        final song = _song(tmp.path, 'BANSHEE', filePath: audioPath);

        fakeFetcher.nextResult = '[00:01.00]Letra sincronizada online';

        final service1 = LyricsService(
          fetcher: fakeFetcher,
          lyricsDirectory: () async => tmpLyrics,
        );
        final lyrics1 = await service1.loadLyrics(song);

        expect(lyrics1, isNotNull);
        expect(lyrics1!.isSynced, isTrue);
        expect(lyrics1.lines.first.text, 'Letra sincronizada online');
        expect(fakeFetcher.callCount, 1);

        final cachedLrc = File('${tmpLyrics.path}/abcdefghijk.lrc');
        expect(cachedLrc.existsSync(), isTrue);
        expect(
          await cachedLrc.readAsString(),
          '[00:01.00]Letra sincronizada online',
        );

        // Segunda instancia con el mismo directorio
        final fetcher2 = FakeLyricsFetcher();
        final service2 = LyricsService(
          fetcher: fetcher2,
          lyricsDirectory: () async => tmpLyrics,
        );
        final lyrics2 = await service2.loadLyrics(song);

        expect(lyrics2, isNotNull);
        expect(lyrics2!.lines.first.text, 'Letra sincronizada online');
        expect(fetcher2.callCount, 0); // No llama al fetcher
      },
    );

    test(
      '2. si el fetcher devuelve null: se crea <id>.none y otra instancia no vuelve a llamar al fetcher',
      () async {
        final audioPath = '${tmp.path}/Tema [abcdefghijk].mp3';
        await File(audioPath).writeAsString('audio');
        final song = _song(tmp.path, 'Tema', filePath: audioPath);

        fakeFetcher.nextResult = null;

        final service1 = LyricsService(
          fetcher: fakeFetcher,
          lyricsDirectory: () async => tmpLyrics,
        );
        final lyrics1 = await service1.loadLyrics(song);

        expect(lyrics1, isNull);
        expect(fakeFetcher.callCount, 1);

        final noneFile = File('${tmpLyrics.path}/abcdefghijk.none');
        expect(noneFile.existsSync(), isTrue);

        // Otra instancia con el mismo directorio
        final fetcher2 = FakeLyricsFetcher();
        final service2 = LyricsService(
          fetcher: fetcher2,
          lyricsDirectory: () async => tmpLyrics,
        );
        final lyrics2 = await service2.loadLyrics(song);

        expect(lyrics2, isNull);
        expect(fetcher2.callCount, 0);
      },
    );

    test(
      '3. si el fetcher lanza LyricsFetchException: no se crea .none y segunda llamada en la misma instancia reintenta',
      () async {
        final audioPath = '${tmp.path}/Tema [abcdefghijk].mp3';
        await File(audioPath).writeAsString('audio');
        final song = _song(tmp.path, 'Tema', filePath: audioPath);

        fakeFetcher.errorToThrow = LyricsFetchException('Sin red');

        final service = LyricsService(
          fetcher: fakeFetcher,
          lyricsDirectory: () async => tmpLyrics,
        );
        final lyrics1 = await service.loadLyrics(song);

        expect(lyrics1, isNull);
        expect(fakeFetcher.callCount, 1);

        final noneFile = File('${tmpLyrics.path}/abcdefghijk.none');
        expect(noneFile.existsSync(), isFalse);

        // Segunda llamada en la misma instancia cuando vuelve la conexión
        fakeFetcher.errorToThrow = null;
        fakeFetcher.nextResult = '[00:01.00]Letra recuperada';

        final lyrics2 = await service.loadLyrics(song);
        expect(lyrics2, isNotNull);
        expect(lyrics2!.lines.first.text, 'Letra recuperada');
        expect(fakeFetcher.callCount, 2);
      },
    );

    test('4. con un .lrc junto al audio, el fetcher no se llama', () async {
      final audioPath = '${tmp.path}/Tema [abcdefghijk].mp3';
      await File(audioPath).writeAsString('audio');
      await File(
        '${tmp.path}/Tema [abcdefghijk].lrc',
      ).writeAsString('[00:01.00]Local');

      final song = _song(tmp.path, 'Tema', filePath: audioPath);
      final service = LyricsService(
        fetcher: fakeFetcher,
        lyricsDirectory: () async => tmpLyrics,
      );

      final lyrics = await service.loadLyrics(song);
      expect(lyrics, isNotNull);
      expect(lyrics!.lines.first.text, 'Local');
      expect(fakeFetcher.callCount, 0);
    });

    test('5. deleteCachedFor borra <id>.lrc y <id>.none', () async {
      final audioPath = '${tmp.path}/Tema [abcdefghijk].mp3';
      final lrc = File('${tmpLyrics.path}/abcdefghijk.lrc');
      final none = File('${tmpLyrics.path}/abcdefghijk.none');
      await lrc.writeAsString('contenido');
      await none.writeAsString('');

      expect(lrc.existsSync(), isTrue);
      expect(none.existsSync(), isTrue);

      final service = LyricsService(
        fetcher: fakeFetcher,
        lyricsDirectory: () async => tmpLyrics,
      );

      await service.deleteCachedFor(audioPath);

      expect(lrc.existsSync(), isFalse);
      expect(none.existsSync(), isFalse);
    });

    test('prefetch precarga y guarda en caché sin lanzar', () async {
      fakeFetcher.nextResult = '[00:02.00]Prefetched lyrics';

      final service = LyricsService(
        fetcher: fakeFetcher,
        lyricsDirectory: () async => tmpLyrics,
      );

      await service.prefetch(
        cacheKey: 'pref1234567',
        title: 'Prefetched Song',
        artist: 'Artist',
        duration: const Duration(seconds: 120),
      );

      final lrc = File('${tmpLyrics.path}/pref1234567.lrc');
      expect(lrc.existsSync(), isTrue);
      expect(await lrc.readAsString(), '[00:02.00]Prefetched lyrics');
      expect(fakeFetcher.callCount, 1);

      // Segunda llamada no hace nada si ya existe .lrc
      await service.prefetch(
        cacheKey: 'pref1234567',
        title: 'Prefetched Song',
      );
      expect(fakeFetcher.callCount, 1);
    });
  });
}
