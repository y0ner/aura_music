import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/lyrics_model.dart';
import '../models/song_model.dart';
import 'artwork_store.dart';
import 'lyrics_fetcher.dart';

Future<Directory> defaultLyricsDirectory() async =>
    Directory('${(await getApplicationSupportDirectory()).path}/lyrics');

/// Carga y cachea las letras (.lrc) de las canciones.
///
/// Convención de archivos (la misma que usa el borrado en
/// [MusicStorageService.deleteSongFile]): junto al audio `Foo.mp3` se busca
/// `Foo.lrc` y `Foo_private.lrc` (los descargadores guardan la letra con
/// cualquiera de los dos nombres).
///
/// Como en la práctica hay letras huérfanas por pequeñas diferencias de
/// nombre (`APAGA EL CEL(MP3_320K)_private.lrc` sin su mp3 gemelo exacto),
/// si no hay coincidencia exacta se intenta una búsqueda tolerante dentro de
/// la misma carpeta: se normalizan los nombres (minúsculas, sin sufijos como
/// `(MP3_320K)` / `[Audio Oficial]` / `(Official Video)`, sin emojis ni
/// puntuación) y se acepta igualdad o contenido.
///
/// Si no hay archivo local, consulta el [LyricsFetcher] configurado (por
/// defecto LRCLIB) y guarda el resultado en la caché privada de la app.
class LyricsService {
  final LyricsFetcher _fetcher;
  final DirectoryProvider _lyricsDirectory;

  /// Instancia compartida que usa [LyricsView] por defecto: cachea por
  /// canción y evita releer el disco al reconstruir la vista.
  static final LyricsService shared = LyricsService();

  final Map<String, ParsedLyrics?> _cache = {};

  LyricsService({
    LyricsFetcher? fetcher,
    DirectoryProvider? lyricsDirectory,
  })  : _fetcher = fetcher ?? LrclibFetcher(),
        _lyricsDirectory = lyricsDirectory ?? defaultLyricsDirectory;

  /// Clave de caché para guardar o recuperar la letra descargada.
  /// Reutiliza el videoId de 11 caracteres si existe; si no, sanitiza
  /// el nombre del archivo sin extensión a un máximo de 100 caracteres.
  static String cacheKeyForPath(String filePath) {
    final vid = videoIdFromPath(filePath);
    if (vid != null && vid.isNotEmpty) {
      return vid;
    }
    final fileName = filePath.split(RegExp(r'[/\\]')).last;
    final dot = fileName.lastIndexOf('.');
    final baseName = dot > 0 ? fileName.substring(0, dot) : fileName;
    final sanitized = baseName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return sanitized.length > 100 ? sanitized.substring(0, 100) : sanitized;
  }

  /// Letra de [song] o null si no hay archivo. El resultado se cachea por
  /// id de canción (se invalida con [invalidate]).
  Future<ParsedLyrics?> loadLyrics(Song song) async {
    if (_cache.containsKey(song.id)) return _cache[song.id];
    final (result, shouldCacheInMemory) = await _findAndParse(song);
    if (shouldCacheInMemory) {
      _cache[song.id] = result;
    }
    return result;
  }

  void invalidate(String songId) => _cache.remove(songId);
  void clearCache() => _cache.clear();

  Future<Directory?> _resolveLyricsDir() async {
    try {
      final dir = await _lyricsDirectory();
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e) {
      debugPrint('Error resolviendo directorio de letras: $e');
      return null;
    }
  }

  Future<(ParsedLyrics?, bool)> _findAndParse(Song song) async {
    try {
      final audioFile = File(song.filePath);
      final dir = audioFile.parent;
      if (dir.existsSync()) {
        final dot = song.filePath.lastIndexOf('.');
        final base = dot < 0 ? song.filePath : song.filePath.substring(0, dot);

        // 1) Coincidencia exacta: Foo.lrc y Foo_private.lrc. Si hay varias, se
        // prefiere la sincronizada (con marcas de tiempo).
        ParsedLyrics? fallback;
        for (final path in ['$base.lrc', '${base}_private.lrc']) {
          final file = File(path);
          if (!file.existsSync()) continue;
          final parsed = parseLrc(await file.readAsString());
          if (parsed.isEmpty) continue;
          if (parsed.isSynced) return (parsed, true);
          fallback ??= parsed;
        }

        // 2) Búsqueda tolerante entre los .lrc hermanos de la carpeta.
        final fuzzyPath = _fuzzyMatch(dir, base);
        if (fuzzyPath != null) {
          final parsed = parseLrc(await File(fuzzyPath).readAsString());
          if (parsed.isSynced) return (parsed, true);
          if (!parsed.isEmpty) fallback ??= parsed;
        }

        if (fallback != null) return (fallback, true);
      }
    } catch (e) {
      debugPrint('Error buscando letra local para ${song.filePath}: $e');
    }

    // 3) <lyricsDir>/<clave>.lrc
    final key = cacheKeyForPath(song.filePath);
    final lyricsDir = await _resolveLyricsDir();

    if (lyricsDir != null) {
      try {
        final cachedFile = File('${lyricsDir.path}/$key.lrc');
        if (cachedFile.existsSync()) {
          final parsed = parseLrc(await cachedFile.readAsString());
          if (!parsed.isEmpty) return (parsed, true);
        }
      } catch (e) {
        debugPrint('Error leyendo letra en caché para ${song.filePath}: $e');
      }

      // 4) Si existe <clave>.none con menos de 7 días, devuelve null.
      try {
        final noneFile = File('${lyricsDir.path}/$key.none');
        if (noneFile.existsSync()) {
          final age = DateTime.now().difference(noneFile.lastModifiedSync());
          if (age < const Duration(days: 7)) {
            return (null, true);
          }
        }
      } catch (e) {
        debugPrint('Error verificando marcador .none para ${song.filePath}: $e');
      }
    }

    // 5) fetcher.fetch
    try {
      final text = await _fetcher.fetch(
        title: song.title,
        artist: song.artist,
        duration: song.duration,
      );

      if (text != null && text.trim().isNotEmpty) {
        if (lyricsDir != null) {
          try {
            final lrcFile = File('${lyricsDir.path}/$key.lrc');
            await lrcFile.writeAsString(text);
            final noneFile = File('${lyricsDir.path}/$key.none');
            if (noneFile.existsSync()) {
              await noneFile.delete();
            }
          } catch (e) {
            debugPrint('Error guardando letra en caché: $e');
          }
        }
        final parsed = parseLrc(text);
        return (parsed, true);
      } else {
        if (lyricsDir != null) {
          try {
            final noneFile = File('${lyricsDir.path}/$key.none');
            await noneFile.writeAsString('');
          } catch (e) {
            debugPrint('Error guardando marcador .none: $e');
          }
        }
        return (null, true);
      }
    } on LyricsFetchException catch (e) {
      debugPrint('Error de red descargando letra para ${song.title}: $e');
      return (null, false);
    } catch (e) {
      debugPrint('Error inesperado descargando letra para ${song.title}: $e');
      return (null, false);
    }
  }

  /// Método público para precargar la letra al descargar una canción.
  /// Si ya existe un `.lrc` o `.none` vigente, no hace nada; si no,
  /// consulta el fetcher y guarda el resultado. Nunca lanza.
  Future<void> prefetch({
    required String cacheKey,
    required String title,
    String? artist,
    Duration? duration,
  }) async {
    try {
      final lyricsDir = await _resolveLyricsDir();
      if (lyricsDir == null) return;

      final lrcFile = File('${lyricsDir.path}/$cacheKey.lrc');
      if (lrcFile.existsSync()) return;

      final noneFile = File('${lyricsDir.path}/$cacheKey.none');
      if (noneFile.existsSync()) {
        try {
          final age = DateTime.now().difference(noneFile.lastModifiedSync());
          if (age < const Duration(days: 7)) {
            return;
          }
        } catch (e) {
          debugPrint('Error leyendo fecha de marcador .none en prefetch: $e');
        }
      }

      try {
        final text = await _fetcher.fetch(
          title: title,
          artist: artist,
          duration: duration,
        );

        if (text != null && text.trim().isNotEmpty) {
          await lrcFile.writeAsString(text);
          if (noneFile.existsSync()) {
            await noneFile.delete();
          }
        } else {
          await noneFile.writeAsString('');
        }
      } on LyricsFetchException catch (e) {
        debugPrint('Error de red en prefetch para $title: $e');
      } catch (e) {
        debugPrint('Error inesperado en prefetch para $title: $e');
      }
    } catch (e) {
      debugPrint('Error general en prefetch: $e');
    }
  }

  /// Elimina los archivos de caché (`<clave>.lrc` y `<clave>.none`) asociados
  /// a la ruta de audio dada. Nunca lanza.
  Future<void> deleteCachedFor(String audioPath) async {
    try {
      final key = cacheKeyForPath(audioPath);
      final lyricsDir = await _resolveLyricsDir();
      if (lyricsDir == null) return;

      final lrcFile = File('${lyricsDir.path}/$key.lrc');
      if (lrcFile.existsSync()) {
        try {
          await lrcFile.delete();
        } catch (e) {
          debugPrint('Error eliminando $lrcFile: $e');
        }
      }

      final noneFile = File('${lyricsDir.path}/$key.none');
      if (noneFile.existsSync()) {
        try {
          await noneFile.delete();
        } catch (e) {
          debugPrint('Error eliminando $noneFile: $e');
        }
      }
    } catch (e) {
      debugPrint('Error borrando letra en caché para $audioPath: $e');
    }
  }

  /// Busca el `.lrc` hermano cuyo nombre normalizado iguale o contenga al
  /// del audio. Devuelve la ruta o null. Prefiere candidatos sincronizados.
  String? _fuzzyMatch(Directory dir, String audioBase) {
    List<FileSystemEntity> siblings;
    try {
      siblings = dir.listSync();
    } catch (e) {
      debugPrint('Error listando directorio para fuzzy match: $e');
      return null;
    }
    final want = _normalize(_basename(audioBase));
    if (want.isEmpty) return null;

    String? plainCandidate;
    for (final entity in siblings) {
      if (entity is! File) continue;
      final name = entity.path.toLowerCase();
      if (!name.endsWith('.lrc')) continue;
      var key = _basename(entity.path);
      if (key.toLowerCase().endsWith('_private')) {
        key = key.substring(0, key.length - '_private'.length);
      }
      final norm = _normalize(key);
      if (norm.isEmpty) continue;
      if (norm == want || norm.contains(want) || want.contains(norm)) {
        // Lee el archivo para preferir el sincronizado sin cargar todo dos
        // veces: basta con buscar una marca al inicio.
        if (_looksSynced(entity)) return entity.path;
        plainCandidate ??= entity.path;
      }
    }
    return plainCandidate;
  }

  /// true si el archivo contiene marcas `[mm:ss` (revisando solo el inicio:
  /// los .lrc son pequeños y esto evita parsear cada candidato dos veces).
  bool _looksSynced(File file) {
    try {
      final bytes = file.readAsBytesSync();
      final head = String.fromCharCodes(
        bytes.length > 8192 ? bytes.sublist(0, 8192) : bytes,
      );
      return RegExp(r'\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\]').hasMatch(head);
    } catch (e) {
      debugPrint('Error revisando si $file tiene marcas de tiempo: $e');
      return false;
    }
  }

  String _basename(String path) {
    final slash = path.lastIndexOf(RegExp(r'[/\\]'));
    var name = slash < 0 ? path : path.substring(slash + 1);
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name;
  }

  /// Normaliza para comparar: minúsculas, sin contenido entre paréntesis o
  /// corchetes (sufijos de descarga como `(MP3_320K)`, `[Audio Oficial]`),
  /// sin emojis/puntuación y con espacios colapsados.
  @visibleForTesting
  static String normalizeForMatch(String input) => _normalize(input);

  static String _normalize(String input) {
    var s = input.toLowerCase();
    s = s.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    s = s.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    s = s.replaceAll(RegExp(r'[^a-z0-9áéíóúüñ\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }
}
