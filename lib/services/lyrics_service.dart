import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/lyrics_model.dart';
import '../models/song_model.dart';

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
class LyricsService {
  /// Instancia compartida que usa [LyricsView] por defecto: cachea por
  /// canción y evita releer el disco al reconstruir la vista.
  static final LyricsService shared = LyricsService();

  final Map<String, ParsedLyrics?> _cache = {};

  /// Letra de [song] o null si no hay archivo. El resultado se cachea por
  /// id de canción (se invalida con [invalidate]).
  Future<ParsedLyrics?> loadLyrics(Song song) async {
    if (_cache.containsKey(song.id)) return _cache[song.id];
    final result = await _findAndParse(song);
    _cache[song.id] = result;
    return result;
  }

  void invalidate(String songId) => _cache.remove(songId);
  void clearCache() => _cache.clear();

  Future<ParsedLyrics?> _findAndParse(Song song) async {
    try {
      final audioFile = File(song.filePath);
      final dir = audioFile.parent;
      if (!dir.existsSync()) return null;

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
        if (parsed.isSynced) return parsed;
        fallback ??= parsed;
      }
      // 2) Búsqueda tolerante entre los .lrc hermanos de la carpeta.
      final fuzzyPath = _fuzzyMatch(dir, base);
      if (fuzzyPath != null) {
        final parsed = parseLrc(await File(fuzzyPath).readAsString());
        if (parsed.isSynced) return parsed;
        if (!parsed.isEmpty) fallback ??= parsed;
      }
      return fallback;
    } catch (e) {
      debugPrint('Error cargando letra de ${song.filePath}: $e');
      return null;
    }
  }

  /// Busca el `.lrc` hermano cuyo nombre normalizado iguale o contenga al
  /// del audio. Devuelve la ruta o null. Prefiere candidatos sincronizados.
  String? _fuzzyMatch(Directory dir, String audioBase) {
    List<FileSystemEntity> siblings;
    try {
      siblings = dir.listSync();
    } catch (_) {
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
    } catch (_) {
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
