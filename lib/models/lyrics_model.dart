/// Modelo y parser de letras (.lrc) para la vista de Letra estilo YouTube Music.
///
/// Soporta los dos formatos que hay en la biblioteca:
/// * **Sincronizado**: líneas con marcas `[mm:ss.xx]` (también `[m:ss.xxx]`
///   o varias marcas en la misma línea). Es el que permite resaltar la línea
///   activa y hacer auto-scroll con la música.
/// * **Plano**: texto sin marcas (algunos `.lrc` y `_private.lrc` son solo la
///   letra). Se muestra como texto estático sin resaltado.
///
/// Las etiquetas de metadatos (`[ti:]`, `[ar:]`, `[al:]`, `[by:]`,
/// `[offset:]`) se ignoran, salvo `offset` que desplaza todos los tiempos.
class LyricLine {
  /// Momento en que la línea se vuelve activa. [Duration.zero] si la letra
  /// no está sincronizada (texto plano).
  final Duration time;

  /// Texto de la línea (sin marcas).
  final String text;

  const LyricLine({required this.time, required this.text});
}

class ParsedLyrics {
  final List<LyricLine> lines;

  /// true si al menos una línea trae marca de tiempo.
  final bool isSynced;

  const ParsedLyrics({required this.lines, required this.isSynced});

  bool get isEmpty => lines.isEmpty;

  /// Índice de la línea activa para [position]: la última línea cuyo tiempo
  /// es <= position. Devuelve -1 si aún no empezó ninguna (o si no hay
  /// sincronización).
  int activeIndexAt(Duration position) {
    if (!isSynced || lines.isEmpty) return -1;
    var active = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= position) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }
}

class _RawLine {
  final Duration time;
  final String text;

  /// true si la línea nació de una marca `[mm:ss]` (aunque sea 00:00).
  final bool stamped;

  _RawLine({required this.time, required this.text, required this.stamped});
}

/// Parsea el contenido de un archivo `.lrc` (o `_private.lrc`).
ParsedLyrics parseLrc(String content) {
  final stampPattern = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final metaPattern =
      RegExp(r'^\s*\[(ti|ar|al|au|by|offset|length):', caseSensitive: false);
  final offsetPattern =
      RegExp(r'\[offset:([+-]?\d+)\]', caseSensitive: false);

  var offset = Duration.zero;
  final raw = <_RawLine>[];

  for (final lineRaw in content.split(RegExp(r'\r?\n'))) {
    final line = lineRaw.trim();
    if (line.isEmpty) continue;

    final meta = metaPattern.firstMatch(line);
    if (meta != null) {
      // Solo `offset` afecta los tiempos (p. ej. [offset:+500] retrasa la
      // letra medio segundo). El resto de metadatos se ignora.
      if (meta.group(1)!.toLowerCase() == 'offset') {
        final value = offsetPattern.firstMatch(line)?.group(1);
        if (value != null) {
          offset = Duration(milliseconds: int.tryParse(value) ?? 0);
        }
      }
      continue;
    }

    final stamps = stampPattern.allMatches(line).toList();
    if (stamps.isEmpty) {
      // Texto plano sin marcas: se conserva como línea no sincronizada.
      raw.add(_RawLine(time: Duration.zero, text: line, stamped: false));
      continue;
    }

    final text = line.replaceAll(stampPattern, '').trim();
    if (text.isEmpty) continue;

    // Una línea puede traer varias marcas ([00:10.00][00:32.00]Estribillo):
    // se repite el texto en cada momento.
    for (final m in stamps) {
      final minutes = int.parse(m.group(1)!);
      final seconds = int.parse(m.group(2)!);
      var millis = 0;
      final frac = m.group(3);
      if (frac != null) {
        // .x = décimas, .xx = centésimas, .xxx = milésimas.
        if (frac.length == 1) {
          millis = int.parse(frac) * 100;
        } else if (frac.length == 2) {
          millis = int.parse(frac) * 10;
        } else {
          millis = int.parse(frac.substring(0, 3));
        }
      }
      var time = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: millis,
      ) +
          offset;
      if (time.isNegative) time = Duration.zero;
      raw.add(_RawLine(time: time, text: text, stamped: true));
    }
  }

  final hasSync = raw.any((l) => l.stamped);
  // Si hay mezcla (cabecera plana + líneas sincronizadas), el texto plano
  // estorba el resaltado: se conserva solo lo sincronizado.
  final kept = hasSync ? raw.where((l) => l.stamped).toList() : raw;
  kept.sort((a, b) => a.time.compareTo(b.time));

  return ParsedLyrics(
    lines: kept.map((l) => LyricLine(time: l.time, text: l.text)).toList(),
    isSynced: hasSync && kept.isNotEmpty,
  );
}
