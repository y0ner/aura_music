import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

typedef DirectoryProvider = Future<Directory> Function();

const _normalizedMarkerName = '.normalizadas';

Future<Directory> defaultArtworkDirectory() async =>
    Directory('${(await getApplicationSupportDirectory()).path}/covers');

final _videoIdRegExp = RegExp(r'\[([A-Za-z0-9_-]{11})\]\.[A-Za-z0-9]+$');

String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;

String? videoIdFromPath(String path) {
  final fileName = _fileName(path);
  final match = _videoIdRegExp.firstMatch(fileName);
  return match?.group(1);
}

File artworkFileFor(Directory dir, String videoId) =>
    File('${dir.path}/$videoId.jpg');

/// Recorta las franjas negras superior e inferior de miniaturas 4:3 (p. ej.
/// `hqdefault` 480×360 de YouTube) para dejar solo el cuadro central 16:9.
///
/// Devuelve el JPEG resultante (calidad 90) si la imagen es exactamente 4:3 y
/// ambas bandas (`[0, alto/8)` y `[alto*7/8, alto)`) cumplen los umbrales de
/// negro; en cualquier otro caso o si falla la decodificación devuelve `null`.
Uint8List? removeLetterbox(Uint8List bytes) {
  if (bytes.isEmpty) return null;

  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (e) {
    debugPrint('No se pudo decodificar la carátula: $e');
    return null;
  }
  if (decoded == null || !decoded.isValid) return null;

  final width = decoded.width;
  final height = decoded.height;
  if (width <= 0 || height < 8 || width * 3 != height * 4) return null;

  final topEnd = height ~/ 8;
  final bottomStart = (height * 7) ~/ 8;
  if (topEnd <= 0 || bottomStart >= height || bottomStart <= topEnd) {
    return null;
  }

  if (!_isBlackBand(decoded, 0, topEnd) ||
      !_isBlackBand(decoded, bottomStart, height)) {
    return null;
  }

  var cropped = img.copyCrop(
    decoded,
    x: 0,
    y: topEnd,
    width: width,
    height: bottomStart - topEnd,
  );
  if (cropped.numChannels < 3 ||
      cropped.hasPalette ||
      cropped.format != img.Format.uint8) {
    cropped = cropped.convert(format: img.Format.uint8, numChannels: 3);
  }
  return img.encodeJpg(cropped, quality: 90);
}

bool _isBlackBand(img.Image image, int startY, int endY) {
  var sumLuminance = 0.0;
  var count = 0;
  final width = image.width;
  final singleGrayChannel = image.numChannels == 1 && !image.hasPalette;
  final isUint8 = image.format == img.Format.uint8;
  img.Pixel? pixel;

  for (var y = startY; y < endY; y++) {
    for (var x = 0; x < width; x += 4) {
      pixel = image.getPixel(x, y, pixel);
      final double luminance;
      if (singleGrayChannel) {
        luminance = isUint8 ? pixel.r.toDouble() : pixel.rNormalized * 255.0;
      } else {
        luminance = isUint8
            ? pixel.luminance.toDouble()
            : pixel.luminanceNormalized * 255.0;
      }
      if (luminance >= 48) return false;
      sumLuminance += luminance;
      count++;
    }
  }

  if (count == 0) return false;
  return (sumLuminance / count) < 20;
}

/// Normaliza en segundo plano las carátulas `*.jpg` de [dir] que aún no figuran
/// en `<dir>/.normalizadas`, recortando sus franjas negras cuando corresponda.
///
/// Devuelve cuántos archivos recortó. Nunca lanza: los errores se registran
/// con [debugPrint] y el archivo original permanece intacto.
Future<int> normalizeArtworkDirectory(Directory dir) async {
  try {
    if (!await dir.exists()) return 0;

    final markerFile = File('${dir.path}/$_normalizedMarkerName');
    final processed = <String>{};
    var needsLeadingNewline = false;

    if (await markerFile.exists()) {
      final content = await markerFile.readAsString();
      needsLeadingNewline = content.isNotEmpty && !content.endsWith('\n');
      for (final line in content.split('\n')) {
        final name = line.trim();
        if (name.isNotEmpty) {
          processed.add(name);
        }
      }
    }

    final pending = <({File file, String name})>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = _fileName(entity.path);
      if (!name.toLowerCase().endsWith('.jpg')) continue;
      if (processed.contains(name)) continue;
      pending.add((file: entity, name: name));
    }
    pending.sort((a, b) => a.name.compareTo(b.name));

    var croppedCount = 0;
    for (final item in pending) {
      final tempFile = File('${item.file.path}.tmp');
      try {
        final bytes = await item.file.readAsBytes();
        final cropped = await Isolate.run(() => removeLetterbox(bytes));
        if (cropped != null) {
          await tempFile.writeAsBytes(cropped, flush: true);
          await tempFile.rename(item.file.path);
          croppedCount++;
        }
        final prefix = needsLeadingNewline ? '\n' : '';
        needsLeadingNewline = false;
        await markerFile.writeAsString(
          '$prefix${item.name}\n',
          mode: FileMode.append,
          flush: true,
        );
        processed.add(item.name);
      } catch (e) {
        debugPrint('Error normalizando carátula ${item.name}: $e');
      } finally {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          debugPrint('Error limpiando temporal de carátula ${item.name}: $e');
        }
      }
    }
    return croppedCount;
  } catch (e) {
    debugPrint('Error normalizando directorio de carátulas ${dir.path}: $e');
    return 0;
  }
}
