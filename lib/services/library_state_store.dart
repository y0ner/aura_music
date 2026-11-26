import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song_model.dart';
import 'artwork_store.dart';

class _PlayEntry {
  final int count;
  final DateTime? last;
  final int sequence;

  const _PlayEntry({
    required this.count,
    required this.last,
    required this.sequence,
  });
}

/// Estado persistente de la biblioteca del usuario en `library_state.json`.
///
/// Guarda favoritos, historial de reproducciones y búsquedas recientes mediante
/// escrituras atómicas (archivo temporal + `rename`) serializadas en cola.
class LibraryStateStore {
  static const int currentVersion = 1;
  static const int maxRecentSearches = 10;

  final DirectoryProvider _directoryProvider;

  final Set<String> _favorites = <String>{};
  final Map<String, _PlayEntry> _plays = <String, _PlayEntry>{};
  final List<String> _searches = <String>[];

  int _sequence = 0;
  bool _isLoaded = false;
  bool _hasInMemoryMutations = false;
  Future<void> _writeChain = Future<void>.value();

  LibraryStateStore({DirectoryProvider? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationSupportDirectory;

  bool get isLoaded => _isLoaded;
  bool get hasInMemoryMutations => _hasInMemoryMutations;

  /// Clave estable de persistencia: el id de YouTube (11 caracteres) cuando
  /// el nombre lo incluye o la ruta completa del archivo en caso contrario.
  static String keyForPath(String filePath) {
    final id = videoIdFromPath(filePath);
    if (id != null && id.isNotEmpty) return id;
    return filePath;
  }

  /// Clave estable de persistencia para [song].
  static String keyFor(Song song) => keyForPath(song.filePath);

  /// Espera a que terminen todas las escrituras pendientes en disco.
  Future<void> flush() => _writeChain;

  /// Carga el estado desde `<directorio>/library_state.json`.
  ///
  /// Si el archivo no existe o está corrupto, deja el estado vacío y reporta
  /// el motivo con `debugPrint` sin lanzar excepciones.
  Future<void> load() async {
    await _writeChain;
    _isLoaded = true;
    _hasInMemoryMutations = false;
    _clearState();

    try {
      final dir = await _directoryProvider();
      final file = File('${dir.path}/library_state.json');
      if (!await file.exists()) {
        debugPrint(
          'library_state: archivo no encontrado (${file.path}), usando estado vacío',
        );
        return;
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        debugPrint(
          'library_state: formato JSON inválido (se esperaba un objeto), usando estado vacío',
        );
        return;
      }

      final version = decoded['version'];
      if (version != null && version != currentVersion) {
        debugPrint(
          'library_state: versión no soportada ($version), usando estado vacío',
        );
        return;
      }

      final rawFavorites = decoded['favorites'];
      if (rawFavorites is List) {
        for (final item in rawFavorites) {
          if (item is String && item.isNotEmpty) {
            _favorites.add(item);
          }
        }
      }

      final rawPlays = decoded['plays'];
      if (rawPlays is Map) {
        for (final entry in rawPlays.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is! String || key.isEmpty || value is! Map) continue;
          final count = value['count'];
          if (count is! int || count <= 0) continue;
          final lastRaw = value['last'];
          final last = lastRaw is String
              ? DateTime.tryParse(lastRaw)?.toUtc()
              : null;
          _plays[key] = _PlayEntry(
            count: count,
            last: last,
            sequence: ++_sequence,
          );
        }
      }

      final rawSearches = decoded['searches'];
      if (rawSearches is List) {
        for (final item in rawSearches) {
          if (item is! String) continue;
          final trimmed = item.trim();
          if (trimmed.isEmpty) continue;
          final exists = _searches.any(
            (existing) => existing.toLowerCase() == trimmed.toLowerCase(),
          );
          if (!exists) {
            _searches.add(trimmed);
            if (_searches.length >= maxRecentSearches) break;
          }
        }
      }
    } catch (e) {
      _clearState();
      debugPrint('library_state: error leyendo estado ($e), usando estado vacío');
    }
  }

  void _clearState() {
    _favorites.clear();
    _plays.clear();
    _searches.clear();
  }

  bool isFavorite(String key) => _favorites.contains(key);

  Future<void> setFavorite(String key, bool value) {
    if (key.isEmpty) return Future<void>.value();
    _hasInMemoryMutations = true;
    final changed = value ? _favorites.add(key) : _favorites.remove(key);
    if (!changed) return Future<void>.value();
    return _save();
  }

  Future<void> recordPlay(String key, {DateTime? at}) {
    if (key.isEmpty) return Future<void>.value();
    _hasInMemoryMutations = true;
    final timestamp = (at ?? DateTime.now()).toUtc();
    final previous = _plays[key];
    _plays[key] = _PlayEntry(
      count: (previous?.count ?? 0) + 1,
      last: timestamp,
      sequence: ++_sequence,
    );
    return _save();
  }

  int playCount(String key) => _plays[key]?.count ?? 0;

  DateTime? lastPlayed(String key) => _plays[key]?.last;

  /// Número de secuencia en memoria para desempatar marcas de tiempo iguales.
  int playSequence(String key) => _plays[key]?.sequence ?? 0;

  List<String> get recentSearches => List.unmodifiable(_searches);

  Future<void> addSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Future<void>.value();
    _hasInMemoryMutations = true;
    _searches.removeWhere(
      (item) => item.toLowerCase() == trimmed.toLowerCase(),
    );
    _searches.insert(0, trimmed);
    if (_searches.length > maxRecentSearches) {
      _searches.removeRange(maxRecentSearches, _searches.length);
    }
    return _save();
  }

  Future<void> removeSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Future<void>.value();
    _hasInMemoryMutations = true;
    final before = _searches.length;
    _searches.removeWhere(
      (item) => item.toLowerCase() == trimmed.toLowerCase(),
    );
    if (_searches.length == before) return Future<void>.value();
    return _save();
  }

  Future<void> clearSearches() {
    if (_searches.isEmpty) return Future<void>.value();
    _hasInMemoryMutations = true;
    _searches.clear();
    return _save();
  }

  Future<void> _save() {
    // Serializa cada escritura para que dos operaciones seguidas no compitan por
    // el mismo archivo temporal ni pierdan actualizaciones intermedias.
    final next = _writeChain.then((_) => _writeToDisk());
    _writeChain = next.catchError((Object e) {
      debugPrint('library_state: error en la cola de escritura: $e');
    });
    return next;
  }

  Future<void> _writeToDisk() async {
    File? tempFile;
    try {
      final dir = await _directoryProvider();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final targetFile = File('${dir.path}/library_state.json');
      tempFile = File('${dir.path}/library_state.json.tmp');

      final payload = <String, dynamic>{
        'version': currentVersion,
        'favorites': _favorites.toList(),
        'plays': {
          for (final entry in _plays.entries)
            entry.key: {
              'count': entry.value.count,
              if (entry.value.last != null)
                'last': entry.value.last!.toUtc().toIso8601String(),
            },
        },
        'searches': _searches.toList(),
      };

      await tempFile.writeAsString(jsonEncode(payload), flush: true);
      await tempFile.rename(targetFile.path);
    } catch (e) {
      debugPrint('library_state: error guardando estado en disco: $e');
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (cleanupError) {
          debugPrint(
            'library_state: error limpiando archivo temporal: $cleanupError',
          );
        }
      }
    }
  }
}
