import 'package:flutter_test/flutter_test.dart';

import 'package:aura_music/utils/metadata_text_fixer.dart';

void main() {
  group('MetadataTextFixer.cleanTagText', () {
    test('repara el mojibake UTF-16BE leído como LE (título real)', () {
      // Cuando el decodificador lee un stream UTF-16BE como LE, invierte los
      // dos bytes de cada code unit. Reproducimos exactamente ese daño para
      // verificar que el reparador lo deshace (caso real: «0 Sentimientos
      // (Remix)» de la biblioteca del usuario).
      String swap(String input) {
        final buffer = StringBuffer();
        for (final cu in input.codeUnits) {
          buffer.writeCharCode(((cu & 0xFF) << 8) | (cu >> 8));
        }
        return buffer.toString();
      }

      const original = '0 Sentimientos (Remix)';
      final mojibake = swap(original);
      expect(mojibake.contains(RegExp(r'[\u3000-\u9FFF]')), isTrue);

      final fixed = MetadataTextFixer.cleanTagText(mojibake);
      expect(fixed, original);
    });

    test('no rompe un título chino real', () {
      const realChinese = '周杰伦 - 稻香';
      final fixed = MetadataTextFixer.cleanTagText(realChinese);
      expect(fixed, realChinese);
    });

    test('no rompe un texto latino normal', () {
      const normal = '0 Sentimientos (Remix)';
      expect(MetadataTextFixer.cleanTagText(normal), normal);
    });

    test('conserva acentos españoles', () {
      const accented = 'Diabólica - Cariñitos y Flores';
      expect(MetadataTextFixer.cleanTagText(accented), accented);
    });

    test('quita el sufijo «- Topic» de canales automáticos de YouTube', () {
      expect(MetadataTextFixer.cleanTagText('Jon Z - Topic'), 'Jon Z');
      // No toca guiones que forman parte del título.
      expect(
        MetadataTextFixer.cleanTagText(
          'Anuel AA - Ñengo Flow_ Darell - Jersey',
        ),
        'Anuel AA - Ñengo Flow_ Darell - Jersey',
      );
    });

    test('devuelve null para texto vacío o ilegible', () {
      expect(MetadataTextFixer.cleanTagText(null), isNull);
      expect(MetadataTextFixer.cleanTagText(''), isNull);
      expect(MetadataTextFixer.cleanTagText('   '), isNull);
    });

    test('quita BOM y NULs sobrantes', () {
      expect(MetadataTextFixer.cleanTagText('\uFEFFHola\u0000'), 'Hola');
    });
  });

  group('MetadataTextFixer.cleanTitle', () {
    test('quita sufijos técnicos de descargas', () {
      expect(
        MetadataTextFixer.cleanTitle('0 Sentimientos (Remix)(MP3_320K)'),
        '0 Sentimientos (Remix)',
      );
      expect(MetadataTextFixer.cleanTitle('Canción [MP3 320Kbps]'), 'Canción');
      expect(MetadataTextFixer.cleanTitle('Tema (320kbps)'), 'Tema');
    });

    test('deja títulos limpios igual', () {
      expect(MetadataTextFixer.cleanTitle('47 (Remix)'), '47 (Remix)');
    });
  });

  group('MetadataTextFixer.titleFromFileName', () {
    test('usa el nombre del archivo como título de respaldo', () {
      expect(
        MetadataTextFixer.titleFromFileName(
          '0 Sentimientos (Remix)(MP3_320K).mp3',
        ),
        '0 Sentimientos (Remix)',
      );
      expect(
        MetadataTextFixer.titleFromFileName('Demonia Baila(MP3_320K).mp3'),
        'Demonia Baila',
      );
    });

    test('oculta IDs de YouTube y conserva sufijos musicales', () {
      expect(
        MetadataTextFixer.titleFromFileName(
          'Outcast (Super Slowed) [ylqkT5qkplw].m4a',
        ),
        'Outcast (Super Slowed)',
      );
      expect(
        MetadataTextFixer.titleFromFileName('Char [i9ym5C776B4].webm'),
        'Char',
      );
      expect(
        MetadataTextFixer.titleFromFileName('Tema [Live].mp3'),
        'Tema [Live]',
      );
    });

    test('no rompe nombres normales con extensión', () {
      expect(MetadataTextFixer.titleFromFileName('Coronamos.mp3'), 'Coronamos');
    });

    test('devuelve el nombre original si queda vacío', () {
      expect(MetadataTextFixer.titleFromFileName('.mp3'), '.mp3');
    });
  });

  group('MetadataTextFixer.splitArtistTitle', () {
    test('casos reales de YouTube y nombres locales', () {
      expect(
        MetadataTextFixer.splitArtistTitle(
          'The Weeknd - Call Out My Name (Official Video)',
        ),
        (artist: 'The Weeknd', title: 'Call Out My Name'),
      );
      expect(
        MetadataTextFixer.splitArtistTitle(
          'Maluma - Cuatro Babys (Official Video) ft. Trap Capos, Noriel, Bryant Myers, Juhn',
        ),
        (
          artist: 'Maluma, Trap Capos, Noriel, Bryant Myers, Juhn',
          title: 'Cuatro Babys',
        ),
      );
      expect(
        MetadataTextFixer.splitArtistTitle(
          'DM - Mueka ft. Cosculluela [Audio Oficial]',
        ),
        (artist: 'DM, Cosculluela', title: 'Mueka'),
      );
      expect(
        MetadataTextFixer.splitArtistTitle(
          'Cris MJ, Kali Uchis, JHAYCO - SI NO ES CONTIGO REMIX',
        ),
        (
          artist: 'Cris MJ, Kali Uchis, JHAYCO',
          title: 'SI NO ES CONTIGO REMIX',
        ),
      );
      expect(
        MetadataTextFixer.splitArtistTitle('Esto Es Así (Remix)'),
        (artist: null, title: 'Esto Es Así (Remix)'),
      );
      expect(
        MetadataTextFixer.splitArtistTitle('Compa_Chappie'),
        (artist: null, title: 'Compa_Chappie'),
      );
    });

    test('mueve feat/ft/featuring dentro o fuera de paréntesis y quita basura', () {
      expect(
        MetadataTextFixer.splitArtistTitle(
          'Artista - Canción (feat. Invitado) [Official Visualizer]',
        ),
        (artist: 'Artista, Invitado', title: 'Canción'),
      );
      expect(
        MetadataTextFixer.splitArtistTitle(
          'Artista - Canción [ft Invitado] (Letra) (4K) (HD)',
        ),
        (artist: 'Artista, Invitado', title: 'Canción'),
      );
      expect(
        MetadataTextFixer.splitArtistTitle(
          'Artista - Canción (Remix) featuring Invitado [Clip Oficial]',
        ),
        (artist: 'Artista, Invitado', title: 'Canción (Remix)'),
      );
      expect(
        MetadataTextFixer.splitArtistTitle(
          'Canción Sola (Official Lyric Video)',
        ),
        (artist: null, title: 'Canción Sola'),
      );
    });

    test('ignora separador si el artista supera 80 caracteres', () {
      final longArtist = 'A' * 81;
      expect(
        MetadataTextFixer.splitArtistTitle('$longArtist - Título (Official Video)'),
        (artist: null, title: '$longArtist - Título'),
      );
    });
  });

  group('MetadataTextFixer.splitArtists', () {
    test('separa por comas, conjunciones y créditos de colaboración', () {
      expect(
        MetadataTextFixer.splitArtists('Cris MJ, Kali Uchis, JHAYCO'),
        ['Cris MJ', 'Kali Uchis', 'JHAYCO'],
      );
      expect(
        MetadataTextFixer.splitArtists(
          'Lito Kirino y Anuel AA & Ozuna x Bad Bunny X Feid ft. Bryant Myers feat. Juhn',
        ),
        [
          'Lito Kirino',
          'Anuel AA',
          'Ozuna',
          'Bad Bunny',
          'Feid',
          'Bryant Myers',
          'Juhn',
        ],
      );
      expect(
        MetadataTextFixer.splitArtists('  Artista A , ,  Artista B  '),
        ['Artista A', 'Artista B'],
      );
      expect(MetadataTextFixer.splitArtists('   '), isEmpty);
    });
  });
}
