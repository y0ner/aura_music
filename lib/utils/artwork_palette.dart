import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../theme/app_theme.dart';

const int _maxCacheEntries = 32;
const int _sampleSize = 24;
const int _hashPrefixBytes = 64;

final Map<int, Color> _paletteCache = <int, Color>{};

/// Limpia la caché en memoria de paletas (uso en pruebas).
@visibleForTesting
void clearArtworkPaletteCache() => _paletteCache.clear();

int _cacheKeyFor(Uint8List bytes) {
  final headLength = min(_hashPrefixBytes, bytes.length);
  return Object.hash(
    bytes.length,
    Object.hashAll(Uint8List.sublistView(bytes, 0, headLength)),
  );
}

({int r, int g, int b})? _extractAverageRgb(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    return null;
  }

  final resized = img.copyResize(
    decoded,
    width: _sampleSize,
    height: _sampleSize,
    interpolation: img.Interpolation.average,
  );

  final singleGrayChannel = !resized.hasPalette && resized.numChannels == 1;
  var sumR = 0.0;
  var sumG = 0.0;
  var sumB = 0.0;
  var totalWeight = 0.0;

  for (final pixel in resized) {
    final a = pixel.aNormalized.toDouble().clamp(0.0, 1.0);
    if (a <= 0.0) continue;

    final r = pixel.rNormalized.toDouble().clamp(0.0, 1.0);
    final g = singleGrayChannel
        ? r
        : pixel.gNormalized.toDouble().clamp(0.0, 1.0);
    final b = singleGrayChannel
        ? r
        : pixel.bNormalized.toDouble().clamp(0.0, 1.0);

    final maxChannel = max(r, max(g, b));
    final minChannel = min(r, min(g, b));
    final chroma = maxChannel - minChannel;

    // Los grises y fondos oscuros con ruido mínimo pesan poco (0.02); los
    // tonos saturados visibles dominan el promedio de color.
    final weight = (0.02 + chroma) * a;
    sumR += r * weight;
    sumG += g * weight;
    sumB += b * weight;
    totalWeight += weight;
  }

  if (totalWeight <= 0.0) {
    return null;
  }

  return (
    r: (sumR / totalWeight * 255).round().clamp(0, 255),
    g: (sumG / totalWeight * 255).round().clamp(0, 255),
    b: (sumB / totalWeight * 255).round().clamp(0, 255),
  );
}

/// Calcula el color de fondo del reproductor a partir de la carátula [bytes].
///
/// Decodifica y reduce la imagen en otro Isolate, promedia los píxeles
/// ponderando por saturación, ajusta HSL (luminosidad 0,22–0,30 y saturación
/// máxima 0,6) para garantizar contraste con texto blanco y guarda en caché
/// los últimos 32 resultados.
Future<Color> artworkBackgroundColor(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) {
    return AppTheme.surfaceHigh;
  }

  final key = _cacheKeyFor(bytes);
  final cached = _paletteCache.remove(key);
  if (cached != null) {
    _paletteCache[key] = cached;
    return cached;
  }

  try {
    final rgb = await Isolate.run(() => _extractAverageRgb(bytes));
    if (rgb == null) {
      debugPrint(
        'artworkBackgroundColor: no se pudo decodificar la carátula '
        '(${bytes.length} bytes).',
      );
      return AppTheme.surfaceHigh;
    }

    final hsl = HSLColor.fromColor(Color.fromARGB(255, rgb.r, rgb.g, rgb.b));
    // Margen interno mínimo para que el redondeo a RGB de 8 bits no saque
    // la luminosidad ni la saturación fuera del rango [0.22, 0.30] / <= 0.6.
    final adjusted = hsl
        .withSaturation(hsl.saturation.clamp(0.0, 0.595))
        .withLightness(hsl.lightness.clamp(0.223, 0.297))
        .toColor();

    if (_paletteCache.length >= _maxCacheEntries) {
      _paletteCache.remove(_paletteCache.keys.first);
    }
    _paletteCache[key] = adjusted;
    return adjusted;
  } catch (e) {
    debugPrint('artworkBackgroundColor: error procesando carátula: $e');
    return AppTheme.surfaceHigh;
  }
}
