import 'package:flutter_test/flutter_test.dart';

import 'package:aura_music/models/lyrics_model.dart';

void main() {
  group('parseLrc sincronizado', () {
    test('marcas [mm:ss.xx] con centésimas', () {
      final parsed = parseLrc(
        '[00:01.21] Así que, ma, ven y apaga el cel\n'
        '[00:03.62] Mami, no te hagas la loca\n',
      );
      expect(parsed.isSynced, isTrue);
      expect(parsed.lines.length, 2);
      expect(parsed.lines[0].time,
          const Duration(seconds: 1, milliseconds: 210));
      expect(parsed.lines[0].text, 'Así que, ma, ven y apaga el cel');
      expect(parsed.lines[1].time,
          const Duration(seconds: 3, milliseconds: 620));
    });

    test('décimas, milésimas y minutos de un dígito', () {
      final parsed = parseLrc(
        '[0:02.3] décimas\n'
        '[01:02.486] milésimas\n'
        '[1:05] sin fracción\n',
      );
      expect(parsed.isSynced, isTrue);
      expect(parsed.lines[0].time,
          const Duration(seconds: 2, milliseconds: 300));
      expect(parsed.lines[1].time,
          const Duration(minutes: 1, seconds: 2, milliseconds: 486));
      expect(parsed.lines[2].time, const Duration(minutes: 1, seconds: 5));
    });

    test('varias marcas en la misma línea repiten el texto', () {
      final parsed = parseLrc('[00:10.00][00:32.00]Estribillo\n');
      expect(parsed.lines.length, 2);
      expect(parsed.lines[0].time, const Duration(seconds: 10));
      expect(parsed.lines[1].time, const Duration(seconds: 32));
      expect(parsed.lines[1].text, 'Estribillo');
    });

    test('metadatos se ignoran y offset desplaza tiempos', () {
      final parsed = parseLrc(
        '[ti:Título]\n'
        '[ar:Artista]\n'
        '[offset:+500]\n'
        '[00:10.00]Hola\n',
      );
      expect(parsed.isSynced, isTrue);
      expect(parsed.lines.length, 1);
      expect(parsed.lines[0].time, const Duration(seconds: 10, milliseconds: 500));
    });

    test('se ordena por tiempo aunque el archivo venga desordenado', () {
      final parsed = parseLrc('[00:30.00]B\n[00:10.00]A\n');
      expect(parsed.lines[0].text, 'A');
      expect(parsed.lines[1].text, 'B');
    });
  });

  group('parseLrc plano', () {
    test('texto sin marcas queda como letra no sincronizada', () {
      final parsed = parseLrc(
        'Cuando estoy contigo la paso fenomenal\n'
        '\n'
        'Yo no tengo carro te invito a caminar\n',
      );
      expect(parsed.isSynced, isFalse);
      expect(parsed.lines.length, 2);
      expect(parsed.lines[0].text, 'Cuando estoy contigo la paso fenomenal');
    });

    test('mezcla: el texto plano se descarta si hay sincronizadas', () {
      final parsed = parseLrc(
        'Título suelto\n'
        '[00:01.00]Primera\n'
        '[00:05.00]Segunda\n',
      );
      expect(parsed.isSynced, isTrue);
      expect(parsed.lines.length, 2);
      expect(parsed.lines[0].text, 'Primera');
    });
  });

  group('activeIndexAt', () {
    test('devuelve la última línea con tiempo <= position', () {
      final parsed = parseLrc(
        '[00:01.00]A\n[00:05.00]B\n[00:10.00]C\n',
      );
      expect(parsed.activeIndexAt(Duration.zero), -1);
      expect(parsed.activeIndexAt(const Duration(seconds: 1)), 0);
      expect(parsed.activeIndexAt(const Duration(seconds: 7)), 1);
      expect(parsed.activeIndexAt(const Duration(minutes: 5)), 2);
    });

    test('sin sincronización siempre es -1', () {
      final parsed = parseLrc('Hola\nMundo\n');
      expect(parsed.activeIndexAt(const Duration(seconds: 30)), -1);
    });
  });
}
