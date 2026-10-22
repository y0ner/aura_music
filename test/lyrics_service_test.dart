import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura_music/models/song_model.dart';
import 'package:aura_music/services/lyrics_service.dart';

Song _song(String dir, String base) => Song(
  id: '$dir/$base.mp3',
  title: base,
  artist: 'Artista',
  album: 'Album',
  filePath: '$dir/$base.mp3',
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

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('aura_lyrics_test_');
    });

    tearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    test('encuentra Foo.lrc exacto y sincronizado', () async {
      await File('${tmp.path}/Tema.mp3').writeAsString('fake');
      await File('${tmp.path}/Tema.lrc')
          .writeAsString('[00:01.00]Hola\n[00:05.00]Mundo\n');
      final lyrics = await LyricsService().loadLyrics(_song(tmp.path, 'Tema'));
      expect(lyrics, isNotNull);
      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.length, 2);
    });

    test('prefiere el sincronizado entre .lrc plano y _private.lrc', () async {
      await File('${tmp.path}/Tema.mp3').writeAsString('fake');
      await File('${tmp.path}/Tema.lrc')
          .writeAsString('Letra plana\nsin marcas\n');
      await File('${tmp.path}/Tema_private.lrc')
          .writeAsString('[00:01.00]Sincronizada\n');
      final lyrics = await LyricsService().loadLyrics(_song(tmp.path, 'Tema'));
      expect(lyrics, isNotNull);
      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.single.text, 'Sincronizada');
    });

    test('búsqueda tolerante empareja nombres con sufijos distintos', () async {
      await File('${tmp.path}/APAGA EL CEL (Remix)(MP3_320K).mp3')
          .writeAsString('fake');
      await File('${tmp.path}/APAGA EL CEL(MP3_320K)_private.lrc')
          .writeAsString('[00:01.21]Apaga el cel\n');
      final lyrics = await LyricsService().loadLyrics(
        _song(tmp.path, 'APAGA EL CEL (Remix)(MP3_320K)'),
      );
      expect(lyrics, isNotNull);
      expect(lyrics!.isSynced, isTrue);
    });

    test('prefiere un archivo equivalente con tiempos enteros sobre el exacto plano', () async {
      await File('${tmp.path}/Tema.lrc').writeAsString('Letra sin tiempos');
      await File('${tmp.path}/Tema (Audio Oficial)_private.lrc')
          .writeAsString('[00:01]Con tiempos\n[00:05]Segundo verso');
      final lyrics = await LyricsService().loadLyrics(_song(tmp.path, 'Tema'));
      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.first.text, 'Con tiempos');
    });

    test('sin archivos devuelve null', () async {
      await File('${tmp.path}/Sola.mp3').writeAsString('fake');
      final lyrics = await LyricsService().loadLyrics(_song(tmp.path, 'Sola'));
      expect(lyrics, isNull);
    });

    test('cachea por id de canción', () async {
      await File('${tmp.path}/Tema.mp3').writeAsString('fake');
      final lrc = File('${tmp.path}/Tema.lrc');
      await lrc.writeAsString('[00:01.00]Uno\n');
      final service = LyricsService();
      final first = await service.loadLyrics(_song(tmp.path, 'Tema'));
      await lrc.writeAsString('[00:01.00]Dos\n');
      final second = await service.loadLyrics(_song(tmp.path, 'Tema'));
      expect(first!.lines.single.text, 'Uno');
      expect(second!.lines.single.text, 'Uno');
      service.invalidate('${tmp.path}/Tema.mp3');
      final third = await service.loadLyrics(_song(tmp.path, 'Tema'));
      expect(third!.lines.single.text, 'Dos');
    });
  });
}
