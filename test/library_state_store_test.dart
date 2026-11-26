import 'dart:convert';
import 'dart:io';

import 'package:aura_music/models/song_model.dart';
import 'package:aura_music/services/library_state_store.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song(String filePath) => Song(
  id: filePath,
  title: 'Tema',
  artist: 'Artista',
  album: 'Álbum',
  filePath: filePath,
  duration: const Duration(minutes: 3),
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('library_state_store_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('keyFor prioriza el videoId de 11 caracteres sobre la ruta', () {
    expect(
      LibraryStateStore.keyFor(
        _song('/music/Hits/The Weeknd - Call Out [abcdefghijk].m4a'),
      ),
      'abcdefghijk',
    );
    expect(
      LibraryStateStore.keyFor(_song('/music/Local/Tema sin id.mp3')),
      '/music/Local/Tema sin id.mp3',
    );
  });

  test(
    'guarda y vuelve a cargar favoritos, reproducciones y búsquedas',
    () async {
      final store = LibraryStateStore(directoryProvider: () async => tempDir);
      await store.load();

      await store.setFavorite('abcdefghijk', true);
      final t1 = DateTime.utc(2026, 5, 10, 14, 30);
      final t2 = DateTime.utc(2026, 5, 10, 15, 0);
      await store.recordPlay('abcdefghijk', at: t1);
      await store.recordPlay('abcdefghijk', at: t2);
      await store.recordPlay('/local/otra.mp3', at: t1);
      await store.addSearch('The Weeknd');
      await store.addSearch('Maluma');

      final file = File('${tempDir.path}/library_state.json');
      expect(await file.exists(), isTrue);
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(raw['version'], 1);

      final reloaded = LibraryStateStore(
        directoryProvider: () async => tempDir,
      );
      await reloaded.load();

      expect(reloaded.isFavorite('abcdefghijk'), isTrue);
      expect(reloaded.isFavorite('/local/otra.mp3'), isFalse);
      expect(reloaded.playCount('abcdefghijk'), 2);
      expect(reloaded.lastPlayed('abcdefghijk'), t2);
      expect(reloaded.playCount('/local/otra.mp3'), 1);
      expect(reloaded.lastPlayed('/local/otra.mp3'), t1);
      expect(reloaded.recentSearches, ['Maluma', 'The Weeknd']);
    },
  );

  test('un JSON corrupto o inexistente carga vacío sin lanzar', () async {
    final store = LibraryStateStore(directoryProvider: () async => tempDir);
    await store.load();
    expect(store.isFavorite('algo'), isFalse);
    expect(store.playCount('algo'), 0);
    expect(store.lastPlayed('algo'), isNull);
    expect(store.recentSearches, isEmpty);

    final file = File('${tempDir.path}/library_state.json');
    await file.writeAsString('{json roto sin cerrar');
    await store.load();
    expect(store.isFavorite('algo'), isFalse);
    expect(store.recentSearches, isEmpty);

    await file.writeAsString('[1, 2, 3]');
    await store.load();
    expect(store.recentSearches, isEmpty);
  });

  test(
    'las búsquedas se limitan a 10, no se repiten e ignoran vacías',
    () async {
      final store = LibraryStateStore(directoryProvider: () async => tempDir);
      await store.load();

      await store.addSearch('');
      await store.addSearch('   ');
      expect(store.recentSearches, isEmpty);

      for (var i = 1; i <= 12; i++) {
        await store.addSearch('Consulta $i');
      }
      expect(store.recentSearches, hasLength(10));
      expect(store.recentSearches.first, 'Consulta 12');
      expect(store.recentSearches.last, 'Consulta 3');

      // Repetida sin distinguir mayúsculas mueve al inicio sin duplicar.
      await store.addSearch('consulta 5');
      expect(store.recentSearches, hasLength(10));
      expect(store.recentSearches.first, 'consulta 5');
      expect(
        store.recentSearches.where((s) => s.toLowerCase() == 'consulta 5'),
        hasLength(1),
      );

      await store.removeSearch('CONSULTA 5');
      expect(store.recentSearches, hasLength(9));
      await store.clearSearches();
      expect(store.recentSearches, isEmpty);
    },
  );

  test('escrituras seguidas en serie no se pisan entre sí', () async {
    final store = LibraryStateStore(directoryProvider: () async => tempDir);
    await store.load();

    await Future.wait([
      store.setFavorite('id1', true),
      store.setFavorite('id2', true),
      store.recordPlay('id1', at: DateTime.utc(2026, 1, 1)),
      store.recordPlay('id2', at: DateTime.utc(2026, 1, 2)),
      store.addSearch('primera'),
      store.addSearch('segunda'),
    ]);

    final reloaded = LibraryStateStore(directoryProvider: () async => tempDir);
    await reloaded.load();
    expect(reloaded.isFavorite('id1'), isTrue);
    expect(reloaded.isFavorite('id2'), isTrue);
    expect(reloaded.playCount('id1'), 1);
    expect(reloaded.playCount('id2'), 1);
    expect(reloaded.recentSearches, ['segunda', 'primera']);
  });

  test('un error de disco al guardar no lanza ni rompe el estado', () async {
    // Un archivo normal pasado como directorio provoca fallo al crear/renombrar.
    final blockingFile = File('${tempDir.path}/not_a_dir');
    await blockingFile.writeAsString('bloqueo');

    final store = LibraryStateStore(
      directoryProvider: () async => Directory(blockingFile.path),
    );
    await store.load();
    await store.setFavorite('k1', true);
    expect(store.isFavorite('k1'), isTrue);
  });
}
