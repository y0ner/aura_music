import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:aura_music/theme/app_theme.dart';
import 'package:aura_music/utils/artwork_palette.dart';

Uint8List _solidPng(int r, int g, int b, {int width = 32, int height = 32}) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel.setRgb(r, g, b);
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  setUp(clearArtworkPaletteCache);

  group('artworkBackgroundColor', () {
    test('una imagen roja sólida da tono ≈ 0° y luminosidad entre 0,22 y 0,30', () async {
      final redBytes = _solidPng(255, 0, 0);

      final color = await artworkBackgroundColor(redBytes);
      final hsl = HSLColor.fromColor(color);

      expect(hsl.hue, closeTo(0.0, 2.0));
      expect(hsl.lightness, inInclusiveRange(0.22, 0.30));
      expect(hsl.saturation, lessThanOrEqualTo(0.6));
    });

    test('null, vacío y bytes corruptos devuelven AppTheme.surfaceHigh', () async {
      expect(await artworkBackgroundColor(null), AppTheme.surfaceHigh);
      expect(await artworkBackgroundColor(Uint8List(0)), AppTheme.surfaceHigh);

      final corrupt = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(await artworkBackgroundColor(corrupt), AppTheme.surfaceHigh);
    });

    test('pondera los píxeles saturados sobre fondos oscuros o grises', () async {
      final image = img.Image(width: 48, height: 48);
      for (final pixel in image) {
        if (pixel.x < 16 && pixel.y < 16) {
          // Acento dorado vivo (~11% del área).
          pixel.setRgb(230, 175, 30);
        } else {
          // Fondo casi negro.
          pixel.setRgb(10, 10, 10);
        }
      }
      final bytes = Uint8List.fromList(img.encodePng(image));

      final color = await artworkBackgroundColor(bytes);
      final hsl = HSLColor.fromColor(color);

      expect(hsl.hue, inInclusiveRange(30.0, 55.0));
      expect(hsl.lightness, inInclusiveRange(0.22, 0.30));
      expect(hsl.saturation, greaterThan(0.2));
      expect(hsl.saturation, lessThanOrEqualTo(0.6));
    });

    test('cachea los resultados por longitud y prefijo de bytes', () async {
      final redA = _solidPng(255, 0, 0);
      final redB = Uint8List.fromList(redA);

      final first = await artworkBackgroundColor(redA);
      final second = await artworkBackgroundColor(redB);

      expect(second, first);

      // Rellena más de 32 entradas para verificar el desalojo LRU sin errores.
      for (var i = 0; i < 35; i++) {
        final sample = _solidPng((i * 7) % 256, 40, 180, width: 8, height: 8);
        final res = await artworkBackgroundColor(sample);
        final hsl = HSLColor.fromColor(res);
        expect(hsl.lightness, inInclusiveRange(0.22, 0.30));
      }
    });
  });
}
