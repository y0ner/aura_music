import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Una pista de una playlist de YouTube obtenida por el fetcher propio.
class PlaylistTrack {
  final String videoId;
  final String title;
  final String? durationText;

  const PlaylistTrack({
    required this.videoId,
    required this.title,
    this.durationText,
  });

  String get thumbnailUrl => 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
}

/// Vista previa completa de una playlist: título y pistas.
class PlaylistOverview {
  final String title;
  final List<PlaylistTrack> tracks;

  const PlaylistOverview({required this.title, required this.tracks});
}

/// Listador de pistas de playlists de YouTube.
///
/// El paquete youtube_explode_dart 3.1.0 dejó de encontrar videos en las
/// playlists: YouTube migró el listado del viejo `playlistVideoRenderer` al
/// nuevo `lockupViewModel`, y el parser del paquete falla en silencio
/// devolviendo 0 pistas (bug: "Playlist descargada! (0/0 pistas)").
///
/// Este fetcher propio soporta AMBOS formatos y pagina mediante la API
/// interna (youtubei/v1/browse) para playlists de más de 100 pistas.
class PlaylistFetcher {
  PlaylistFetcher._();

  static const Map<String, String> _headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'accept-language': 'es-ES,es;q=0.9,en;q=0.8',
  };

  /// Límite de páginas de continuación (30 * ~100 pistas = 3000).
  static const int _maxPages = 30;

  /// Descarga y procesa TODAS las pistas de una playlist.
  ///
  /// Lanza excepción si no se pudo leer la página inicial (con reintentos,
  /// porque YouTube a veces sirve una página de consentimiento/bot). Si
  /// falla una página de continuación, se informa el error; nunca se presenta
  /// una lista parcial como si fuera la playlist completa.
  static Future<List<PlaylistTrack>> fetchTracks(
    String playlistId, {
    void Function(int found)? onProgress,
  }) async => (await _fetchTracksRaw(playlistId, onProgress: onProgress)).$1;

  /// Devuelve título y pistas en una sola pasada de red (2-3 peticiones).
  ///
  /// Lo usa el análisis del enlace: así la app no depende de
  /// youtube_explode para las playlists y muestra el recuento real.
  static Future<PlaylistOverview> fetchOverview(
    String playlistId, {
    void Function(int found)? onProgress,
    http.Client? client,
  }) async {
    final (tracks, title) = await _fetchTracksRaw(
      playlistId,
      onProgress: onProgress,
      client: client,
    );
    return PlaylistOverview(
      title: title.isEmpty ? 'Playlist $playlistId' : title,
      tracks: tracks,
    );
  }

  /// Motor común: recorre la página inicial + continuaciones.
  /// Devuelve (pistas, título extraído del HTML, '' si no se encontró).
  static Future<(List<PlaylistTrack>, String)> _fetchTracksRaw(
    String playlistId, {
    void Function(int found)? onProgress,
    http.Client? client,
  }) async {
    const maxRetries = 3;
    Object? lastError;

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final res = await (client?.get ?? http.get)(
          Uri.parse('https://www.youtube.com/playlist?list=$playlistId&hl=en'),
          headers: _headers,
        ).timeout(const Duration(seconds: 30));

        if (res.statusCode != 200) {
          throw Exception(
            'YouTube respondió ${res.statusCode} al leer la playlist.',
          );
        }

        final data = extractYtInitialData(res.body);
        if (data == null) {
          throw Exception(
            'No se pudieron leer los datos de la playlist (formato inesperado).',
          );
        }

        // Restrict extraction to playlist contents, not recommended videos.
        final contents = _playlistContents(data);
        final tracks = parseTracks(contents);
        final seen = tracks.map((track) => track.videoId).toSet();
        final title = _extractPlaylistTitle(data) ?? '';
        onProgress?.call(tracks.length);

        final version = RegExp(r'"INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)"')
            .firstMatch(res.body)
            ?.group(1);
        if (version == null) {
          throw StateError('No se encontró el contexto de YouTube.');
        }
        String? token = _findContinuationToken(contents);
        final tokens = <String>{};
        int pages = 1;
        while (token != null) {
          if (pages >= _maxPages || !tokens.add(token)) {
            throw StateError(
              'No se pudo completar la paginación de la playlist.',
            );
          }
          final pageData = await _fetchContinuation(token, version, client);
          if (pageData == null) {
            throw StateError(
              'Falló una página de la playlist. Reintenta el análisis.',
            );
          }
          _collectTracks(pageData, tracks, seen);
          onProgress?.call(tracks.length);
          final next = _findContinuationToken(pageData);
          pages++;
          token = next;
        }

        return (tracks, title);
      } catch (e) {
        lastError = e;
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    throw Exception(
      'No se pudo leer la playlist tras $maxRetries intentos: $lastError',
    );
  }

  static dynamic _playlistContents(dynamic node) {
    if (node is Map) {
      if (node['playlistVideoListRenderer'] is Map) {
        return node['playlistVideoListRenderer'];
      }
      final tab = node['tabRenderer'];
      if (tab is Map && tab['selected'] == true && tab['content'] is Map) {
        return tab['content'];
      }
      for (final child in node.values) {
        final found = _playlistContents(child);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final child in node) {
        final found = _playlistContents(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Busca el título de la playlist en el JSON de la página (soporta la
  /// cabecera nueva pageHeaderRenderer y la legada playlistHeaderRenderer).
  static String? _extractPlaylistTitle(dynamic node) {
    if (node is Map) {
      final phr = node['pageHeaderRenderer'];
      if (phr is Map) {
        final t = phr['pageTitle'];
        if (t is String && t.trim().isNotEmpty) return t.trim();
        final tm = phr['title'];
        if (tm is Map && tm['content'] is String) {
          final s = tm['content'] as String;
          if (s.trim().isNotEmpty) return s.trim();
        }
      }
      final hdr = node['playlistHeaderRenderer'];
      if (hdr is Map) {
        final t = hdr['title'];
        if (t is Map) {
          if (t['simpleText'] is String) return t['simpleText'] as String;
          final runs = t['runs'];
          if (runs is List && runs.isNotEmpty && runs.first is Map) {
            final s = runs.first['text'];
            if (s is String && s.trim().isNotEmpty) return s.trim();
          }
        }
      }
      for (final child in node.values) {
        final r = _extractPlaylistTitle(child);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final e in node) {
        final r = _extractPlaylistTitle(e);
        if (r != null) return r;
      }
    }
    return null;
  }

  /// Extrae el objeto `ytInitialData` del HTML de YouTube balanceando llaves
  /// (no se puede usar una regex simple porque el JSON es gigante y anidado).
  static Map<String, dynamic>? extractYtInitialData(String html) {
    // YouTube usa dos variantes de asignación según la página.
    final m = RegExp(r'ytInitialData"?\]?\s*=\s*').firstMatch(html);
    if (m == null) return null;
    final start = html.indexOf('{', m.end);
    if (start < 0) return null;

    var depth = 0;
    var inStr = false;
    var esc = false;
    var end = start;

    for (var i = start; i < html.length; i++) {
      final c = html[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == '\\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
        }
      } else {
        if (c == '"') {
          inStr = true;
        } else if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
      }
    }

    if (depth != 0) return null;
    try {
      return jsonDecode(html.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Convierte un objeto `ytInitialData` en pistas. Se mantiene público para
  /// poder probar el parser sin depender de una petición real a YouTube.
  static List<PlaylistTrack> parseTracks(dynamic data) {
    final tracks = <PlaylistTrack>[];
    final seen = <String>{};
    _collectTracks(data, tracks, seen);
    return tracks;
  }

  /// Recorre el JSON recursivamente y agrega pistas en cualquiera de los
  /// dos formatos conocidos (nuevo lockupViewModel o legacy renderer).
  static void _collectTracks(
    dynamic node,
    List<PlaylistTrack> out,
    Set<String> seen,
  ) {
    if (node is Map) {
      final lockup = node['lockupViewModel'];
      if (lockup is Map) {
        final track = _fromLockup(lockup);
        if (track != null && seen.add(track.videoId)) out.add(track);
      }
      final legacy = node['playlistVideoRenderer'];
      if (legacy is Map) {
        final track = _fromLegacyRenderer(legacy);
        if (track != null && seen.add(track.videoId)) out.add(track);
      }
      for (final child in node.values) {
        _collectTracks(child, out, seen);
      }
    } else if (node is List) {
      for (final e in node) {
        _collectTracks(e, out, seen);
      }
    }
  }

  /// Formato NUEVO de YouTube (2025+): lockupViewModel.
  static PlaylistTrack? _fromLockup(Map lockup) {
    final videoId = lockup['contentId'];
    if (videoId is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
      return null;
    }

    // Solo pistas de video; ignora playlists anidadas.
    final type = lockup['contentType'];
    if (type is String && type.contains('PLAYLIST')) return null;

    String title = '';
    final meta = lockup['metadata'];
    if (meta is Map) {
      final lm = meta['lockupMetadataViewModel'];
      if (lm is Map) {
        final t = lm['title'];
        if (t is Map && t['content'] is String) title = t['content'] as String;
      }
    }
    if (title.isEmpty) return null;

    String? duration;
    try {
      final img = lockup['contentImage'];
      if (img is Map) {
        final thumb = img['thumbnailViewModel'];
        if (thumb is Map) {
          final overlays = thumb['overlays'];
          if (overlays is List) {
            for (final o in overlays) {
              if (o is Map && o['thumbnailBottomOverlayViewModel'] is Map) {
                final badges = o['thumbnailBottomOverlayViewModel']['badges'];
                if (badges is List) {
                  for (final b in badges) {
                    if (b is Map && b['thumbnailBadgeViewModel'] is Map) {
                      final txt = b['thumbnailBadgeViewModel']['text'];
                      if (txt is String && txt.contains(':')) {
                        duration = txt;
                        break;
                      }
                    }
                  }
                }
              }
              if (duration != null) break;
            }
          }
        }
      }
    } catch (_) {
      // La duración es cosmética: nunca debe romper la extracción.
    }

    return PlaylistTrack(
      videoId: videoId,
      title: title,
      durationText: duration,
    );
  }

  /// Formato LEGADO (por compatibilidad si YouTube revierte el cambio).
  static PlaylistTrack? _fromLegacyRenderer(Map r) {
    if (r['isPlayable'] == false) return null;
    final videoId = r['videoId'];
    if (videoId is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
      return null;
    }

    String title = '';
    final t = r['title'];
    if (t is Map) {
      final runs = t['runs'];
      if (runs is List && runs.isNotEmpty && runs.first is Map) {
        title = runs.first['text']?.toString() ?? '';
      }
    }

    String? duration;
    final lt = r['lengthText'];
    if (lt is Map && lt['simpleText'] is String) {
      duration = lt['simpleText'] as String;
    }

    return PlaylistTrack(
      videoId: videoId,
      title: title.isEmpty ? 'Video $videoId' : title,
      durationText: duration,
    );
  }

  /// Busca el primer token de continuación dentro del JSON.
  static String? _findContinuationToken(dynamic node) {
    String? result;
    void walk(dynamic n) {
      if (result != null) return;
      if (n is Map) {
        for (final e in n.entries) {
          if (result != null) return;
          if ((e.key == 'continuationItemRenderer' ||
                  e.key == 'continuationItemViewModel') &&
              e.value is Map) {
            result = _digToken(e.value);
            if (result != null) return;
          } else {
            walk(e.value);
          }
        }
      } else if (n is List) {
        for (final e in n) {
          if (result != null) return;
          walk(e);
        }
      }
    }

    walk(node);
    return result;
  }

  static String? _digToken(dynamic node) {
    if (node is Map) {
      for (final e in node.entries) {
        if (e.key == 'token' &&
            e.value is String &&
            (e.value as String).isNotEmpty) {
          return e.value as String;
        }
        final r = _digToken(e.value);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final e in node) {
        final r = _digToken(e);
        if (r != null) return r;
      }
    }
    return null;
  }

  /// Página siguiente mediante la API interna de YouTube (cliente WEB).
  static Future<Map<String, dynamic>?> _fetchContinuation(
    String token,
    String version,
    http.Client? client,
  ) async {
    try {
      final res = await (client?.post ?? http.post)(
        Uri.parse(
          'https://www.youtube.com/youtubei/v1/browse?prettyPrint=false',
        ),
        headers: {..._headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': version,
              'hl': 'en',
            },
          },
          'continuation': token,
        }),
      ).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
