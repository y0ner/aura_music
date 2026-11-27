import 'dart:io';
import 'dart:typed_data';

import 'package:aura_music/services/artwork_store.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

Uint8List _makeJpg({
  required int width,
  required int height,
  img.Color? background,
  List<({int x1, int y1, int x2, int y2, img.Color color})> rects = const [],
  int quality = 95,
}) {
  final image = img.Image(width: width, height: height);
  if (background != null) {
    img.fill(image, color: background);
  }
  for (final rect in rects) {
    img.fillRect(
      image,
      x1: rect.x1,
      y1: rect.y1,
      x2: rect.x2,
      y2: rect.y2,
      color: rect.color,
    );
  }
  return img.encodeJpg(image, quality: quality);
}

void main() {
  group('artwork_store', () {
    test('videoIdFromPath extrae id con corchetes, rechaza sin id y admite espacios y emojis', () {
      // Con corchetes
      expect(
        videoIdFromPath('Canción [SqAGWRpccm0].m4a'),
        'SqAGWRpccm0',
      );
      expect(
        videoIdFromPath('/storage/emulated/0/Music/AuraMusic/Canción [SqAGWRpccm0].m4a'),
        'SqAGWRpccm0',
      );

      // Sin id
      expect(videoIdFromPath('Canción sin id.mp3'), isNull);
      expect(videoIdFromPath('/Music/Canción [corto].m4a'), isNull);
      expect(videoIdFromPath('Canción [123456789012].m4a'), isNull);
      expect(videoIdFromPath(''), isNull);

      // Con espacios y emojis
      expect(
        videoIdFromPath('#1 Urbano 😏🔥💯/01. Título con espacios y acento 🎵 [SqAGWRpccm0].m4a'),
        'SqAGWRpccm0',
      );
      expect(
        videoIdFromPath('/Music/🔥 Hits 2026/Track 🚀 [AAAAAAAAAAA].webm'),
        'AAAAAAAAAAA',
      );
    });

    test('artworkFileFor construye la ruta esperada', () {
      final dir = Directory('/tmp/aura_covers');
      final file = artworkFileFor(dir, 'SqAGWRpccm0');
      expect(file.path, '/tmp/aura_covers/SqAGWRpccm0.jpg');
    });

    test('MusicStorageService asocia carátula privada desde artworkDirectory', () async {
      final root = await Directory.systemTemp.createTemp('aura_music_test');
      final tmpCovers = await Directory.systemTemp.createTemp('aura_covers_test');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
        if (await tmpCovers.exists()) await tmpCovers.delete(recursive: true);
      });

      final playlistDir = Directory('${root.path}/Mi lista');
      await playlistDir.create(recursive: true);
      final songFile = File('${playlistDir.path}/Canción [AAAAAAAAAAA].m4a');
      await songFile.writeAsBytes([1, 2, 3, 4]);

      final coverBytes = Uint8List.fromList([10, 20, 30, 40]);
      final coverFile = File('${tmpCovers.path}/AAAAAAAAAAA.jpg');
      await coverFile.writeAsBytes(coverBytes);

      final storage = MusicStorageService(artworkDirectory: () async => tmpCovers);
      await storage.setCustomRootDirectory(root.path);

      expect(storage.allSongs, hasLength(1));
      expect(storage.allSongs.first.artworkBytes, equals(coverBytes));
    });

    test('deleteSongFile borra la carátula privada además del archivo de audio', () async {
      final root = await Directory.systemTemp.createTemp('aura_music_del_test');
      final tmpCovers = await Directory.systemTemp.createTemp('aura_covers_del_test');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
        if (await tmpCovers.exists()) await tmpCovers.delete(recursive: true);
      });

      final playlistDir = Directory('${root.path}/Mi lista');
      await playlistDir.create(recursive: true);
      final songFile = File('${playlistDir.path}/Canción [AAAAAAAAAAA].m4a');
      await songFile.writeAsBytes([1, 2, 3, 4]);

      final coverFile = File('${tmpCovers.path}/AAAAAAAAAAA.jpg');
      await coverFile.writeAsBytes([10, 20, 30, 40]);

      final storage = MusicStorageService(artworkDirectory: () async => tmpCovers);
      await storage.setCustomRootDirectory(root.path);

      expect(storage.allSongs, hasLength(1));
      final deleted = await storage.deleteSongFile(storage.allSongs.first);
      expect(deleted, isTrue);

      expect(await songFile.exists(), isFalse);
      expect(await coverFile.exists(), isFalse);
      expect(storage.allSongs, isEmpty);
    });

    test(
      'removeLetterbox recorta franjas negras de 45 px en 480x360 y conserva el color del centro',
      () {
        final centerColor = img.ColorUint8.rgb(35, 160, 225);
        final input = _makeJpg(
          width: 480,
          height: 360,
          rects: [(x1: 0, y1: 45, x2: 479, y2: 314, color: centerColor)],
        );

        final croppedBytes = removeLetterbox(input);
        expect(croppedBytes, isNotNull);

        final decoded = img.decodeImage(croppedBytes!);
        expect(decoded, isNotNull);
        expect(decoded!.width, 480);
        expect(decoded.height, 270);

        for (final (x, y) in [(240, 4), (240, 135), (240, 265)]) {
          final p = decoded.getPixel(x, y);
          expect(p.r, closeTo(35, 12));
          expect(p.g, closeTo(160, 12));
          expect(p.b, closeTo(225, 12));
        }
      },
    );

    test(
      'removeLetterbox devuelve null con franjas de color aunque el centro sea negro, en 1:1 y con bytes corruptos',
      () {
        final black = img.ColorUint8.rgb(0, 0, 0);

        // 4:3 con centro negro y franjas de color.
        final coloredBands = _makeJpg(
          width: 480,
          height: 360,
          background: img.ColorUint8.rgb(30, 120, 200),
          rects: [(x1: 0, y1: 45, x2: 479, y2: 314, color: black)],
        );
        expect(removeLetterbox(coloredBands), isNull);

        // 4:3 con franjas gris oscuro (luminancia ~30: máxima < 48 pero media >= 20).
        final dimGrayBands = _makeJpg(
          width: 480,
          height: 360,
          background: img.ColorUint8.rgb(30, 30, 30),
          rects: [(x1: 0, y1: 45, x2: 479, y2: 314, color: black)],
        );
        expect(removeLetterbox(dimGrayBands), isNull);

        // 4:3 con solo una franja negra (abajo de color).
        final singleBand = _makeJpg(
          width: 480,
          height: 360,
          rects: [
            (x1: 0, y1: 45, x2: 479, y2: 359, color: img.ColorUint8.rgb(80, 90, 100)),
          ],
        );
        expect(removeLetterbox(singleBand), isNull);

        // Imagen 1:1 aunque tenga franjas negras.
        final square = _makeJpg(
          width: 360,
          height: 360,
          rects: [
            (x1: 0, y1: 45, x2: 359, y2: 314, color: img.ColorUint8.rgb(200, 100, 50)),
          ],
        );
        expect(removeLetterbox(square), isNull);

        // Bytes corruptos o vacíos.
        expect(
          removeLetterbox(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2])),
          isNull,
        );
        expect(removeLetterbox(Uint8List.fromList([1, 2, 3, 4])), isNull);
        expect(removeLetterbox(Uint8List(0)), isNull);
      },
    );

    test(
      'removeLetterbox devuelve null si un dibujo en fondo negro entra en la banda superior',
      () {
        final white = img.ColorUint8.rgb(240, 240, 240);

        // Dibujo centrado que invade la banda superior [0, 45).
        final enteringTop = _makeJpg(
          width: 480,
          height: 360,
          rects: [(x1: 180, y1: 20, x2: 300, y2: 280, color: white)],
        );
        expect(removeLetterbox(enteringTop), isNull);

        // Detalle pequeño que mantiene la media < 20 pero supera la máxima (48).
        final smallSpikeInTop = _makeJpg(
          width: 480,
          height: 360,
          rects: [(x1: 232, y1: 24, x2: 248, y2: 60, color: white)],
        );
        expect(removeLetterbox(smallSpikeInTop), isNull);
      },
    );

    test(
      'normalizeArtworkDirectory recorta solo pendientes, escribe .normalizadas-v2 y evita redecodificar',
      () async {
        final dir = await Directory.systemTemp.createTemp('aura_norm_test');
        addTearDown(() async {
          if (await dir.exists()) await dir.delete(recursive: true);
        });

        final letterboxA = _makeJpg(
          width: 480,
          height: 360,
          rects: [
            (x1: 0, y1: 45, x2: 479, y2: 314, color: img.ColorUint8.rgb(200, 60, 60)),
          ],
        );
        final letterboxB = _makeJpg(
          width: 480,
          height: 360,
          rects: [
            (x1: 0, y1: 45, x2: 479, y2: 314, color: img.ColorUint8.rgb(60, 200, 90)),
          ],
        );
        final fullFrameC = _makeJpg(
          width: 480,
          height: 360,
          background: img.ColorUint8.rgb(80, 120, 210),
        );

        final fileA = File('${dir.path}/a.jpg');
        final fileB = File('${dir.path}/b.jpg');
        final fileC = File('${dir.path}/c.jpg');
        await fileA.writeAsBytes(letterboxA);
        await fileB.writeAsBytes(letterboxB);
        await fileC.writeAsBytes(fullFrameC);
        await File('${dir.path}/ignore.txt').writeAsString('texto');

        final firstCount = await normalizeArtworkDirectory(dir);
        expect(firstCount, 2);

        for (final file in [fileA, fileB]) {
          final decoded = img.decodeImage(await file.readAsBytes());
          expect(decoded, isNotNull);
          expect(decoded!.width, 480);
          expect(decoded.height, 270);
        }
        expect(await fileC.readAsBytes(), equals(fullFrameC));

        final markerFile = File('${dir.path}/.normalizadas-v2');
        expect(await markerFile.exists(), isTrue);
        final lines = (await markerFile.readAsLines())
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        expect(lines, unorderedEquals(['a.jpg', 'b.jpg', 'c.jpg']));

        // Segunda llamada: devuelve 0 y no vuelve a procesar archivos listados.
        await fileC.writeAsBytes(letterboxA);
        final secondCount = await normalizeArtworkDirectory(dir);
        expect(secondCount, 0);
        final decodedC = img.decodeImage(await fileC.readAsBytes());
        expect(decodedC!.width, 480);
        expect(decodedC.height, 360);
      },
    );

    test(
      'normalizeArtworkDirectory no lanza ante errores y respeta .normalizadas-v2 previo sin salto final',
      () async {
        final missing = Directory(
          '${Directory.systemTemp.path}/aura_no_existe_${DateTime.now().microsecondsSinceEpoch}',
        );
        expect(await normalizeArtworkDirectory(missing), 0);

        final dir = await Directory.systemTemp.createTemp('aura_norm_err_test');
        addTearDown(() async {
          if (await dir.exists()) await dir.delete(recursive: true);
        });

        await File('${dir.path}/.normalizadas-v2').writeAsString('prev.jpg');
        final corruptFile = File('${dir.path}/bad.jpg');
        final corruptBytes = Uint8List.fromList([1, 2, 3, 4]);
        await corruptFile.writeAsBytes(corruptBytes);

        expect(await normalizeArtworkDirectory(dir), 0);
        expect(await corruptFile.readAsBytes(), equals(corruptBytes));

        final lines = (await File('${dir.path}/.normalizadas-v2').readAsLines())
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        expect(lines, ['prev.jpg', 'bad.jpg']);
        expect(await normalizeArtworkDirectory(dir), 0);
      },
    );
  });

  group('recoverMissingCovers', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('aura_recover_');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('baja la miniatura, le quita las franjas y no repite lo que ya está',
        () async {
      final requested = <String>[];
      final thumbnail = _makeJpg(
        width: 480,
        height: 360,
        background: img.ColorRgb8(0, 0, 0),
        rects: [(x1: 0, y1: 45, x2: 479, y2: 314, color: img.ColorRgb8(40, 160, 220))],
      );
      final client = MockClient((request) async {
        requested.add(request.url.toString());
        if (request.url.path.contains('missingId01')) {
          return http.Response('', 404);
        }
        return http.Response.bytes(thumbnail, 200);
      });
      await File('${dir.path}/yaExisteId1.jpg').writeAsBytes([1, 2, 3]);

      final recovered = await recoverMissingCovers(
        dir,
        ['abcdefghijk', 'missingId01', 'yaExisteId1'],
        client: client,
      );

      expect(recovered, 1);
      expect(requested, hasLength(2));
      expect(
        requested,
        contains('https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg'),
      );
      final saved = img.decodeImage(
        await File('${dir.path}/abcdefghijk.jpg').readAsBytes(),
      )!;
      expect(saved.width, 480);
      expect(saved.height, 270);

      // Segunda pasada: el 404 quedó anotado y la recuperada ya existe.
      requested.clear();
      expect(
        await recoverMissingCovers(
          dir,
          ['abcdefghijk', 'missingId01'],
          client: client,
        ),
        0,
      );
      expect(requested, isEmpty);
    });

    test('un fallo de red no se anota: se reintenta en el siguiente escaneo',
        () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        throw const SocketException('sin red');
      });
      expect(await recoverMissingCovers(dir, ['abcdefghijk'], client: client), 0);
      expect(await recoverMissingCovers(dir, ['abcdefghijk'], client: client), 0);
      expect(calls, 2);
      expect(await File('${dir.path}/abcdefghijk.jpg').exists(), isFalse);
    });
  });
}
