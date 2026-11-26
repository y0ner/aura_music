/// Repara los textos de las etiquetas ID3 que llegan corruptos (en chino).
///
/// Causa del bug: varias apps descargadoras (y algunos rippers) escriben las
/// etiquetas ID3v2 en UTF-16 **big-endian** con BOM `FE FF`, o incluso con
/// doble BOM `FE FF FE FF`. El paquete `audio_metadata_reader` decodifica
/// esos frames SIEMPRE como UTF-16 little-endian sin respetar la BOM, y el
/// resultado son caracteres CJK sin sentido (p. ej. 「」鷸攀…).
///
/// La buena noticia: leer UTF-16BE como LE solo invierte los dos bytes de
/// cada code unit. Volviendo a invertir los bytes se recupera el texto
/// original exacto, sin volver a leer el archivo.
class MetadataTextFixer {
  MetadataTextFixer._();

  /// Limpia cualquier texto de etiqueta (título, artista, álbum...).
  ///
  /// Devuelve `null` cuando no queda texto legible, para que el llamador use
  /// su propio respaldo (normalmente el nombre del archivo).
  static String? cleanTagText(String? raw) {
    if (raw == null) return null;

    var value = _stripBomJunk(raw);
    if (value.isEmpty) return null;

    // Si el texto tiene la firma del byte-swap UTF-16BE→LE y la versión
    // re-invertida es más legible, la usamos. El doble chequeo protege los
    // títulos que SÍ están en chino de verdad.
    final swapped = _stripBomJunk(_swapCodeUnits(value));
    if (_looksLikeSwappedUtf16(value) &&
        _readabilityScore(swapped) > _readabilityScore(value)) {
      value = swapped;
    }

    value = _collapseWhitespace(value);

    // YouTube etiqueta sus pistas subidas con el canal «XXX - Topic».
    value = value.replaceFirst(
      RegExp(r'\s*-\s*Topic$', caseSensitive: false),
      '',
    );

    if (value.isEmpty) return null;

    // Si después de todo sigue siendo ilegible, mejor devolver null y que el
    // llamador muestre el nombre del archivo.
    if (_readabilityScore(value) < 0.2) return null;

    return value;
  }

  /// Título de canción a partir del texto de la etiqueta TIT2.
  ///
  /// Además de [cleanTagText], quita la basura que dejan las apps de
  /// descarga: `(MP3_320K)`, `[MP3 320Kbps]`, `(320kbps)`, etc.
  static String? cleanTitle(String? raw) {
    var value = cleanTagText(raw);
    if (value == null) return null;

    value = _stripDownloadJunk(value);
    value = _collapseWhitespace(value);
    return value.isEmpty ? null : value;
  }

  /// Título de respaldo construido desde el nombre del archivo.
  ///
  /// Es lo que se usa cuando la etiqueta no existe o viene corrupta. Quita la
  /// extensión y los sufijos técnicos de las descargas.
  static String titleFromFileName(String fileName) {
    var t = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    t = _stripDownloadJunk(t);
    // The downloader keeps a stable video ID in filenames for collision-free
    // retries. It is storage identity, never part of the displayed song title.
    t = t.replaceFirst(RegExp(r'\s+\[[a-zA-Z0-9_-]{11}\]$'), '');
    t = _collapseWhitespace(t);
    return t.isEmpty ? fileName : t;
  }

  static final RegExp _junkGroupKeywords = RegExp(
    r'(?:^|[^a-zA-Z0-9])(?:videos?|videoclips?|official|oficial|audio|visualizers?|lyrics?|letras?|clips?|hd|4k)(?=$|[^a-zA-Z0-9])',
    caseSensitive: false,
  );

  static final RegExp _bracketedGroup = RegExp(r'\s*[\(\[][^\)\]]*[\)\]]');

  static final RegExp _parenFeaturing = RegExp(
    r'\s*[\(\[]\s*(?:featuring|feat\.?|ft\.?)\s+([^\)\]]+?)[\)\]]',
    caseSensitive: false,
  );

  static final RegExp _trailingFeaturing = RegExp(
    r'\s+(?:featuring|feat\.?|ft\.?)\s+([^\(\[\)\]]+?)(?=\s*[\(\[]|$)',
    caseSensitive: false,
  );

  static final RegExp _artistSeparator = RegExp(
    r',|\s+(?:y|&|x)\s+|\s+(?:featuring|feat|ft)\.?(?=\s|$)|\b(?:feat|ft)\.(?=\s|$)',
    caseSensitive: false,
  );

  /// Separa artista y título a partir de un nombre tipo `Artista - Título`.
  ///
  /// Quita del título los grupos `(...)`/`[...]` promocionales (`Official Video`,
  /// `Audio Oficial`, `HD`, `4K`, etc.) conservando `(Remix)` y similares, y
  /// mueve `ft.` / `feat.` / `ft` / `featuring` del título al artista.
  static ({String? artist, String title}) splitArtistTitle(String rawTitle) {
    final normalized = _collapseWhitespace(rawTitle);
    if (normalized.isEmpty) {
      return (artist: null, title: '');
    }

    String? artist;
    var titlePart = normalized;

    final sepIndex = normalized.indexOf(' - ');
    if (sepIndex != -1) {
      final left = normalized.substring(0, sepIndex).trim();
      final right = normalized.substring(sepIndex + 3).trim();
      if (left.isNotEmpty && left.length <= 80 && right.isNotEmpty) {
        artist = left;
        titlePart = right;
      }
    }

    // Quita primero los grupos basura entre paréntesis o corchetes.
    var cleanedTitle = titlePart.replaceAllMapped(_bracketedGroup, (match) {
      final full = match.group(0)!;
      final openIdx = full.indexOf(RegExp(r'[\(\[]'));
      final inner = full.substring(openIdx + 1, full.length - 1);
      return _junkGroupKeywords.hasMatch(inner) ? '' : full;
    });
    cleanedTitle = _collapseWhitespace(cleanedTitle);

    if (artist != null) {
      final featured = <String>[];

      cleanedTitle = cleanedTitle.replaceAllMapped(_parenFeaturing, (match) {
        final guest = _collapseWhitespace(match.group(1) ?? '');
        if (guest.isNotEmpty) featured.add(guest);
        return '';
      });
      cleanedTitle = _collapseWhitespace(cleanedTitle);

      cleanedTitle = cleanedTitle.replaceAllMapped(_trailingFeaturing, (match) {
        final guest = _collapseWhitespace(match.group(1) ?? '');
        if (guest.isNotEmpty) featured.add(guest);
        return '';
      });
      cleanedTitle = _collapseWhitespace(cleanedTitle);

      if (featured.isNotEmpty) {
        artist = '$artist, ${featured.join(', ')}';
      }
    }

    if (cleanedTitle.isEmpty) {
      cleanedTitle = _collapseWhitespace(titlePart);
    }

    return (artist: artist, title: cleanedTitle);
  }

  /// Divide una cadena de créditos en artistas individuales sin vacíos.
  static List<String> splitArtists(String credits) {
    final trimmed = credits.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed
        .split(_artistSeparator)
        .map((part) => _collapseWhitespace(part))
        .where((part) => part.isNotEmpty)
        .toList();
  }

  /// Elimina tokens técnicos tipo `(MP3_320K)` / `[MP3 320Kbps]` / `(320kbps)`.
  static String _stripDownloadJunk(String input) {
    return input.replaceAll(
      RegExp(
        r'[\(\[\{]\s*MP3\s*_?\d{2,3}\s*K(?:bps)?\s*[\)\]\}]|[\(\[\{]\s*\d{2,3}\s*kbps\s*[\)\]\}]',
        caseSensitive: false,
      ),
      '',
    );
  }

  /// Quita BOM y sobrantes del intercambio de bytes (U+FEFF / U+FFFE) y NULs.
  static String _stripBomJunk(String input) {
    return input
        .replaceAll('\u0000', '')
        .replaceAll(
          RegExp('^[\uFEFF\uFFFE\u200B]+|[\uFEFF\uFFFE\u200B]+\$'),
          '',
        );
  }

  /// Invierte los dos bytes de cada code unit UTF-16.
  ///
  /// Es la operación inversa exacta de leer un stream big-endian como
  /// little-endian, por eso recupera el texto original.
  static String _swapCodeUnits(String input) {
    final buffer = StringBuffer();
    for (final cu in input.codeUnits) {
      buffer.writeCharCode(((cu & 0xFF) << 8) | (cu >> 8));
    }
    return buffer.toString();
  }

  /// Detecta la firma del mojibake UTF-16BE leído como LE.
  ///
  /// Cuando el texto original es latino (bytes altos 0x00), el swap produce
  /// caracteres CJK cuyo byte bajo SIEMPRE es 0x00 (U+3000, U+5300, U+6500...).
  /// Un título chino real casi nunca tiene esa propiedad.
  static bool _looksLikeSwappedUtf16(String input) {
    var suspicious = 0;
    var nonAscii = 0;
    for (final cu in input.codeUnits) {
      if (cu <= 0x7F) continue;
      nonAscii++;
      if (cu >= 0x2000 && (cu & 0xFF) == 0) suspicious++;
    }
    if (nonAscii == 0) return false;
    return suspicious / nonAscii >= 0.6;
  }

  /// Proporción de caracteres «normales» (ASCII, acentos latinos y
  /// puntuación común). El texto correcto de una biblioteca latina ronda 1.0;
  /// el mojibake chino ronda 0.
  static double _readabilityScore(String input) {
    var good = 0;
    var total = 0;
    for (final cu in input.codeUnits) {
      if (cu == 0xFEFF || cu == 0xFFFE || cu == 0x200B) continue;
      total++;
      if ((cu >= 0x20 && cu <= 0x7E) || // ASCII imprimible
          (cu >= 0xA1 && cu <= 0xFF) || // á é í ñ ¿ ¡ ü ...
          cu == 0x2019 ||
          cu == 0x2018 ||
          cu == 0x201C ||
          cu == 0x201D ||
          cu == 0x2013 ||
          cu == 0x2014 ||
          cu == 0x2026) {
        good++;
      }
    }
    if (total == 0) return 0;
    return good / total;
  }

  static String _collapseWhitespace(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
