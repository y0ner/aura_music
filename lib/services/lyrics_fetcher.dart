import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LyricsFetchException implements Exception {
  final String message;
  final Object? cause;

  LyricsFetchException(this.message, [this.cause]);

  @override
  String toString() =>
      'LyricsFetchException: $message${cause != null ? ' ($cause)' : ''}';
}

abstract class LyricsFetcher {
  Future<String?> fetch({
    required String title,
    String? artist,
    Duration? duration,
  });
}

class LrclibFetcher implements LyricsFetcher {
  final http.Client _client;

  LrclibFetcher({http.Client? client}) : _client = client ?? http.Client();

  static final _groupRegex = RegExp(r'\([^)]*\)|\[[^\]]*\]');
  static const _cleanupKeywords = [
    'video',
    'official',
    'oficial',
    'audio',
    'visualizer',
    'lyric',
    'letra',
    'clip',
    'hd',
    '4k',
  ];

  /// Separa `artista - título` (si el artista no se conoce) y limpia el
  /// título de grupos tipo "(Video Official)" y del sufijo "ft ...".
  static ({String artist, String title}) _splitArtistTitle({
    required String title,
    String? artist,
  }) {
    var effectiveArtist = (artist == null ||
            artist.trim().isEmpty ||
            artist.trim() == 'Artista desconocido')
        ? ''
        : artist.trim();
    var cleanTitle = title.trim();

    if (effectiveArtist.isEmpty && cleanTitle.contains(' - ')) {
      final firstDash = cleanTitle.indexOf(' - ');
      effectiveArtist = cleanTitle.substring(0, firstDash).trim();
      cleanTitle = cleanTitle.substring(firstDash + 3).trim();
    }

    // Quita grupos (...) o [...] que contengan palabras clave como video,
    // official, lyric, etc. Conserva (Remix), (feat. X), etc.
    cleanTitle = cleanTitle.replaceAllMapped(_groupRegex, (match) {
      final group = match.group(0)!;
      final lower = group.toLowerCase();
      final hasKeyword = _cleanupKeywords.any((kw) {
        if (kw == 'hd' || kw == '4k') {
          return RegExp(r'\b' + kw + r'\b').hasMatch(lower);
        }
        return lower.contains(kw);
      });
      return hasKeyword ? ' ' : group;
    });

    // Quita sufijo ft / feat fuera de paréntesis solo para la consulta.
    cleanTitle = cleanTitle.replaceAll(
      RegExp(
        r'\s+(?:ft|feat)\.?\s+[^()\[\]]+(?=\s*(?:\(|$))',
        caseSensitive: false,
      ),
      ' ',
    );
    return (
      artist: effectiveArtist,
      title: cleanTitle.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
  }

  @visibleForTesting
  static String buildSearchQuery({required String title, String? artist}) {
    final parts = _splitArtistTitle(title: title, artist: artist);
    return [parts.artist, parts.title]
        .where((s) => s.isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Núcleo comparable de un título: sin grupos (...)/[...], sin "ft ...",
  /// sin tildes ni signos, en minúsculas y con espacios colapsados.
  static String _coreTitle(String input) {
    var s = input.toLowerCase();
    s = s.replaceAll(_groupRegex, ' ');
    s = s.replaceAll(RegExp(r'\s(?:ft|feat)\.?\s.*$'), ' ');
    const accents = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    };
    s = s.split('').map((c) => accents[c] ?? c).join();
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// true si el título de LRCLIB corresponde a la canción buscada. Evita
  /// mostrar la letra de otra canción que solo coincide en duración.
  @visibleForTesting
  static bool titlesMatch(String wanted, String? candidate) {
    final a = _coreTitle(wanted);
    if (a.isEmpty) return true;
    final b = _coreTitle(candidate ?? '');
    if (b.isEmpty) return false;
    return a == b || b.contains(a) || a.contains(b);
  }

  @override
  Future<String?> fetch({
    required String title,
    String? artist,
    Duration? duration,
  }) async {
    final q = buildSearchQuery(title: title, artist: artist);
    if (q.isEmpty) return null;

    final uri = Uri.https('lrclib.net', '/api/search', {'q': q});
    http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const {'User-Agent': 'AuraMusic/1.0'},
      ).timeout(const Duration(seconds: 10));
    } on http.ClientException catch (e) {
      throw LyricsFetchException('Error de conexión con LRCLIB: $e', e);
    } catch (e) {
      if (e is LyricsFetchException) rethrow;
      throw LyricsFetchException('Error de red al consultar LRCLIB: $e', e);
    }

    if (response.statusCode != 200) {
      throw LyricsFetchException(
        'Respuesta HTTP no exitosa (${response.statusCode})',
      );
    }

    // Una respuesta 200 que no es una lista JSON (p. ej. la página HTML de un
    // portal cautivo de WiFi) no significa "no existe": es un error de red y
    // no debe dejar el marcador .none de 7 días.
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      throw LyricsFetchException('Respuesta de LRCLIB no es JSON', e);
    }
    if (decoded is! List) {
      throw LyricsFetchException('Respuesta de LRCLIB inesperada');
    }

    final wantedTitle = _splitArtistTitle(title: title, artist: artist).title;
    return _pickLyrics(decoded, duration, wantedTitle);
  }

  static String? _pickLyrics(
    List<dynamic> items,
    Duration? targetDuration,
    String wantedTitle,
  ) {
    if (items.isEmpty) return null;

    final candidates = <_LrclibItem>[];
    for (final item in items) {
      if (item is Map) {
        final trackName = item['trackName'];
        if (!titlesMatch(wantedTitle, trackName is String ? trackName : null)) {
          continue;
        }
        final durationVal = item['duration'];
        final double? d = durationVal is num ? durationVal.toDouble() : null;
        final synced = item['syncedLyrics'] as String?;
        final plain = item['plainLyrics'] as String?;
        candidates.add(
          _LrclibItem(
            duration: d,
            syncedLyrics: (synced != null && synced.trim().isNotEmpty)
                ? synced
                : null,
            plainLyrics: (plain != null && plain.trim().isNotEmpty)
                ? plain
                : null,
          ),
        );
      }
    }

    if (targetDuration != null) {
      final targetSeconds = targetDuration.inMilliseconds / 1000.0;
      final valid = candidates.where((c) {
        if (c.duration == null) return false;
        return (targetSeconds - c.duration!).abs() <= 3.0;
      }).toList();

      if (valid.isEmpty) return null;

      valid.sort((a, b) {
        final aSynced = a.syncedLyrics != null;
        final bSynced = b.syncedLyrics != null;
        if (aSynced && !bSynced) return -1;
        if (!aSynced && bSynced) return 1;
        final aDiff = (targetSeconds - a.duration!).abs();
        final bDiff = (targetSeconds - b.duration!).abs();
        return aDiff.compareTo(bDiff);
      });

      final best = valid.first;
      return best.syncedLyrics ?? best.plainLyrics;
    } else {
      for (final c in candidates) {
        if (c.syncedLyrics != null) return c.syncedLyrics;
      }
      for (final c in candidates) {
        if (c.plainLyrics != null) return c.plainLyrics;
      }
      return null;
    }
  }
}

class _LrclibItem {
  final double? duration;
  final String? syncedLyrics;
  final String? plainLyrics;

  const _LrclibItem({
    required this.duration,
    required this.syncedLyrics,
    required this.plainLyrics,
  });
}
