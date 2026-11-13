import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

import '../models/download_job.dart';
import '../utils/metadata_text_fixer.dart';
import 'artwork_store.dart';
import 'playlist_fetcher.dart';
import 'storage_service.dart';

export '../models/download_job.dart';

class YoutubePreview {
  final bool isPlaylist;
  final String id;
  final String title;
  final String author;
  final Duration? duration;
  final String thumbnailUrl;
  final int trackCount;

  const YoutubePreview({
    required this.isPlaylist,
    required this.id,
    required this.title,
    required this.author,
    this.duration,
    required this.thumbnailUrl,
    this.trackCount = 1,
  });

  String get formattedDuration => duration == null
      ? ''
      : '${duration!.inMinutes}:${duration!.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

/// Network boundary: tests exercise the same queue without contacting YouTube.
class YoutubeAudio {
  final Stream<List<int>> bytes;
  final int size;
  final String extension;
  final void Function() close;
  const YoutubeAudio({
    required this.bytes,
    required this.size,
    required this.extension,
    required this.close,
  });
}

class YoutubeBackend {
  yt.YoutubeExplode? _active;

  http.Client? _playlistClient;
  http.Client? _audioClient;

  Future<PlaylistOverview> playlist(String id) async {
    final client = http.Client();
    _playlistClient = client;
    try {
      return await PlaylistFetcher.fetchOverview(id, client: client);
    } finally {
      client.close();
      if (identical(_playlistClient, client)) _playlistClient = null;
    }
  }

  yt.YoutubeExplode _client() => yt.YoutubeExplode(
    httpClient: yt.YoutubeHttpClient(
      IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 15)),
    ),
  );

  Future<YoutubePreview> video(String id) async {
    final client = _client();
    _active = client;
    try {
      final video = await client.videos
          .get(id)
          .timeout(const Duration(seconds: 25));
      return YoutubePreview(
        isPlaylist: false,
        id: id,
        title: video.title,
        author: video.author,
        duration: video.duration,
        thumbnailUrl: video.thumbnails.highResUrl,
      );
    } finally {
      client.close();
      if (identical(_active, client)) _active = null;
    }
  }

  Future<YoutubeAudio> audio(String id, int attempt) async {
    final client = IOClient(
      HttpClient()..connectionTimeout = const Duration(seconds: 15),
    );
    _audioClient = client;
    const agent =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15';
    try {
      final page = await client
          .get(
            Uri.https('www.youtube.com', '/watch', {'v': id}),
            headers: {'user-agent': agent},
          )
          .timeout(const Duration(seconds: 20));
      if (page.statusCode != 200) {
        throw HttpException('YouTube: HTTP ${page.statusCode}');
      }
      final visitor = RegExp(r'"VISITOR_DATA"\s*:\s*"([^"]+)"')
          .firstMatch(page.body)
          ?.group(1);
      if (visitor == null) {
        throw StateError('No se encontró el contexto de visitante de YouTube.');
      }
      final headers = <String, String>{
        'user-agent': agent,
        'content-type': 'application/json',
        'x-youtube-client-name': '101',
        'x-youtube-client-version': '1.02',
        'x-goog-visitor-id': visitor,
        'origin': 'https://www.youtube.com',
      };
      final cookies = page.headers['set-cookie'];
      if (cookies != null) {
        headers['cookie'] = cookies
            .split(RegExp(r',(?=\s*[^;,= ]+=)'))
            .map((cookie) => cookie.split(';').first.trim())
            .join('; ');
      }
      final response = await client
          .post(
            Uri.https('www.youtube.com', '/youtubei/v1/player', {
              'prettyPrint': 'false',
            }),
            headers: headers,
            body: jsonEncode({
              'context': {
                'client': {
                  'clientName': 'VISIONOS',
                  'clientVersion': '1.02',
                  'deviceMake': 'Apple',
                  'deviceModel': 'RealityDevice17,1',
                  'userAgent': agent,
                  'osName': 'visionOS',
                  'osVersion': '26.5.23O471',
                  'hl': 'en',
                  'gl': 'US',
                  'visitorData': visitor,
                },
              },
              'videoId': id,
              'contentCheckOk': true,
              'racyCheckOk': true,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw HttpException('YouTube player: HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['playabilityStatus'] as Map<String, dynamic>?;
      if (status?['status'] != 'OK') {
        throw StateError(status?['reason'] ?? 'Audio no disponible');
      }
      final streaming = data['streamingData'] as Map<String, dynamic>?;
      final formats = (streaming?['adaptiveFormats'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .where(
            (f) =>
                f['url'] is String &&
                (f['mimeType'].toString().startsWith('audio/mp4') ||
                    f['mimeType'].toString().startsWith('audio/webm')),
          )
          .toList();
      if (formats.isEmpty) {
        throw StateError('YouTube no proporcionó audio directo.');
      }
      formats.sort((a, b) {
        final aacA = a['mimeType'].toString().startsWith('audio/mp4');
        final aacB = b['mimeType'].toString().startsWith('audio/mp4');
        if (aacA != aacB) return aacA ? -1 : 1;
        return ((b['bitrate'] as num?) ?? 0).compareTo(
          (a['bitrate'] as num?) ?? 0,
        );
      });
      final audio = formats.first;
      final size = int.tryParse(audio['contentLength'].toString()) ?? 0;
      if (size <= 0) throw StateError('No se conoce el tamaño del audio.');
      return YoutubeAudio(
        bytes: _audioChunks(
          client,
          Uri.parse(audio['url'] as String),
          size,
          agent,
        ),
        size: size,
        extension: audio['mimeType'].toString().startsWith('audio/mp4')
            ? 'm4a'
            : 'webm',
        close: () {
          client.close();
          if (identical(_audioClient, client)) _audioClient = null;
        },
      );
    } catch (_) {
      client.close();
      if (identical(_audioClient, client)) _audioClient = null;
      rethrow;
    }
  }

  // Bounded requests avoid throttled full-file streams and validate every chunk.
  Stream<List<int>> _audioChunks(
    http.Client client,
    Uri url,
    int size,
    String agent,
  ) async* {
    const chunkSize = 1024 * 1024;
    for (var start = 0; start < size; start += chunkSize) {
      final end = (start + chunkSize - 1).clamp(0, size - 1);
      final ranged = url.replace(
        queryParameters: {...url.queryParameters, 'range': '$start-$end'},
      );
      final response = await client
          .send(http.Request('GET', ranged)..headers['user-agent'] = agent)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('Audio HTTP ${response.statusCode}');
      }
      var received = 0;
      await for (final bytes in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        received += bytes.length;
        if (received > end - start + 1) {
          throw StateError('YouTube ignoró el rango solicitado.');
        }
        yield bytes;
      }
      if (received != end - start + 1) {
        throw StateError('Fragmento de audio incompleto.');
      }
    }
  }

  void cancelAnalysis() {
    _active?.close();
    _playlistClient?.close();
  }

  void cancelAudio() {
    _audioClient?.close();
  }

  void cancel() {
    cancelAnalysis();
    cancelAudio();
  }
}

class YoutubeDownloadService extends ChangeNotifier {
  final YoutubeBackend _backend;
  final Future<Directory> Function() _tempDirectory;
  final DirectoryProvider _artworkDirectory;
  YoutubeDownloadService({
    YoutubeBackend? backend,
    Future<Directory> Function()? tempDirectory,
    DirectoryProvider? artworkDirectory,
  }) : _backend = backend ?? YoutubeBackend(),
       _tempDirectory = tempDirectory ?? getTemporaryDirectory,
       _artworkDirectory = artworkDirectory ?? defaultArtworkDirectory;

  bool _isAnalyzing = false, _cancelRequested = false;
  bool _disposed = false;
  int _generation = 0;
  double _currentProgress = 0;
  String _statusMessage = '';
  String? _lastDownloadError;
  YoutubePreview? _preview;
  List<PlaylistTrack> _tracks = [];
  int _totalTracks = 0;
  String? _currentTrackTitle;

  final List<DownloadJob> _jobs = [];
  int _nextJobId = 0;
  DownloadJob? _currentJob;
  bool _isRunnerActive = false;

  bool get isAnalyzing => _isAnalyzing;
  bool get isDownloading => _currentJob != null;
  DownloadJob? get currentJob => _currentJob;
  List<DownloadJob> get jobs => List.unmodifiable(_jobs);
  int get waitingCount =>
      _jobs.where((j) => j.status == DownloadJobStatus.waiting).length;
  DownloadJob? jobFor(String previewId) =>
      _jobs.reversed.where((j) => j.preview.id == previewId).firstOrNull;
  bool get isPreviewDownloaded =>
      _preview != null &&
      jobFor(_preview!.id)?.status == DownloadJobStatus.done;
  double get currentProgress {
    if (_currentJob != null) return _currentProgress;
    if (_preview != null) {
      final job = jobFor(_preview!.id);
      if (job != null) {
        if (job.status == DownloadJobStatus.done) return 1.0;
        if (job.tracks.isNotEmpty) {
          return (job.completed / job.tracks.length).clamp(0.0, 1.0);
        }
      }
    }
    return 0.0;
  }

  String get statusMessage => _statusMessage;
  YoutubePreview? get preview => _preview;
  int get completedTracks {
    if (_currentJob != null) return _currentJob!.completed;
    if (_preview != null) return jobFor(_preview!.id)?.completed ?? 0;
    return 0;
  }

  int get totalTracks {
    if (_currentJob != null) return _currentJob!.tracks.length;
    if (_preview != null) return jobFor(_preview!.id)?.tracks.length ?? 0;
    return 0;
  }

  int get failedTracks {
    if (_currentJob != null) return _currentJob!.failed;
    if (_preview != null) return jobFor(_preview!.id)?.failed ?? 0;
    return 0;
  }

  String? get currentTrackTitle =>
      _currentJob != null ? _currentTrackTitle : null;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void clearPreview() {
    _generation++;
    _backend.cancelAnalysis();
    _isAnalyzing = false;
    _preview = null;
    _tracks = [];
    _statusMessage = '';
    _emit();
  }

  void cancel() {
    if (_currentJob == null) return;
    _cancelRequested = true;
    _backend.cancelAudio();
    _statusMessage = 'Cancelando descarga…';
    _emit();
  }

  void removeJob(int id) {
    final index = _jobs.indexWhere(
      (j) => j.id == id && j.status == DownloadJobStatus.waiting,
    );
    if (index != -1) {
      final removed = _jobs.removeAt(index);
      if (!removed.completer.isCompleted) {
        removed.completer.complete(false);
      }
      _emit();
    }
  }

  void clearFinished() {
    _jobs.removeWhere(
      (j) =>
          j.status == DownloadJobStatus.done ||
          j.status == DownloadJobStatus.failed ||
          j.status == DownloadJobStatus.cancelled,
    );
    _emit();
  }

  /// A watch URL containing list= always means the entire playlist.
  static ({String id, bool isPlaylist}) parseLink(String input) {
    var text = input.trim();
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.parse(text);
    final host = uri.host.toLowerCase();
    if (![
          'youtube.com',
          'www.youtube.com',
          'm.youtube.com',
          'music.youtube.com',
          'youtu.be',
          'www.youtu.be',
        ].contains(host) ||
        !['http', 'https'].contains(uri.scheme)) {
      throw const FormatException('Introduce un enlace de YouTube válido.');
    }
    final list = uri.queryParameters['list'];
    if (list != null && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(list)) {
      return (id: list, isPlaylist: true);
    }
    final parts = uri.pathSegments;
    final video = host.endsWith('youtu.be')
        ? (parts.isEmpty ? null : parts.first)
        : uri.queryParameters['v'] ??
              (parts.length == 2 &&
                      ['shorts', 'embed', 'live'].contains(parts.first)
                  ? parts.last
                  : null);
    if (video == null || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(video)) {
      throw const FormatException(
        'No se encontró una canción o playlist en el enlace.',
      );
    }
    return (id: video, isPlaylist: false);
  }

  Future<YoutubePreview?> analyzeUrl(String input) async {
    if (_isAnalyzing) return null;
    final generation = ++_generation;
    _isAnalyzing = true;
    _preview = null;
    _tracks = [];
    _statusMessage = 'Leyendo enlace…';
    _emit();
    try {
      final link = parseLink(input);
      late final YoutubePreview preview;
      late final List<PlaylistTrack> tracks;
      if (link.isPlaylist) {
        final list = await _backend
            .playlist(link.id)
            .timeout(const Duration(minutes: 3));
        if (list.tracks.isEmpty) {
          throw StateError(
            'La playlist no tiene canciones públicas disponibles.',
          );
        }
        tracks = list.tracks;
        preview = YoutubePreview(
          isPlaylist: true,
          id: link.id,
          title: list.title,
          author: 'Playlist de YouTube',
          thumbnailUrl: tracks.first.thumbnailUrl,
          trackCount: tracks.length,
        );
      } else {
        preview = await _backend.video(link.id);
        tracks = [PlaylistTrack(videoId: preview.id, title: preview.title)];
      }
      if (generation != _generation || _disposed) return null;
      _preview = preview;
      _tracks = List.unmodifiable(tracks);
      _statusMessage = '${tracks.length} canción(es) listas para descargar.';
      return preview;
    } catch (e) {
      if (generation == _generation) {
        _statusMessage = 'Error al leer el enlace: $e';
      }
      return null;
    } finally {
      if (generation == _generation) {
        _isAnalyzing = false;
        _emit();
      }
    }
  }

  DownloadJob? enqueue(
    MusicStorageService storage, {
    String? targetSubfolder,
  }) {
    final preview = _preview;
    if (preview == null) {
      _statusMessage = 'No hay ninguna canción o playlist para descargar.';
      _emit();
      return null;
    }
    final root = storage.rootMusicDirectory;
    if (root == null) {
      _statusMessage = 'Selecciona una carpeta de música antes de descargar.';
      _emit();
      return null;
    }
    final existing = jobFor(preview.id);
    if (existing != null &&
        (existing.status == DownloadJobStatus.waiting ||
            existing.status == DownloadJobStatus.downloading)) {
      _statusMessage = 'Ya está en la cola.';
      _emit();
      return null;
    }

    final job = DownloadJob(
      id: ++_nextJobId,
      preview: preview,
      tracks: _tracks,
      targetSubfolder: targetSubfolder,
      storage: storage,
    );
    _jobs.add(job);
    _emit();
    _runQueue();
    return job;
  }

  Future<void> _runQueue() async {
    if (_isRunnerActive) return;
    _isRunnerActive = true;
    try {
      while (!_disposed) {
        DownloadJob? nextJob;
        for (final job in _jobs) {
          if (job.status == DownloadJobStatus.waiting) {
            nextJob = job;
            break;
          }
        }
        if (nextJob == null) break;
        await _executeJob(nextJob);
      }
    } finally {
      _isRunnerActive = false;
      _currentJob = null;
      _emit();
    }
  }

  Future<void> _executeJob(DownloadJob job) async {
    _currentJob = job;
    job.status = DownloadJobStatus.downloading;
    _cancelRequested = false;
    _lastDownloadError = null;
    _currentProgress = 0;
    _totalTracks = job.tracks.length;
    _emit();

    final storage = job.storage;
    final root = storage?.rootMusicDirectory;
    if (storage == null || root == null) {
      job.status = DownloadJobStatus.failed;
      job.error = 'Selecciona una carpeta de música antes de descargar.';
      _statusMessage = 'Selecciona una carpeta de música antes de descargar.';
      if (!job.completer.isCompleted) job.completer.complete(false);
      _emit();
      return;
    }

    try {
      final folder = job.preview.isPlaylist
          ? job.preview.title
          : job.targetSubfolder;
      final directory = folder == null || folder.trim().isEmpty
          ? root
          : Directory('${root.path}/${_safeName(folder)}');
      await directory.create(recursive: true);

      for (var i = 0; i < job.tracks.length && !_cancelRequested; i++) {
        final track = job.tracks[i];
        _currentTrackTitle = track.title;
        final base =
            '${directory.path}/${_safeName(track.title)} [${track.videoId}]';
        _statusMessage = '(${i + 1}/${job.tracks.length}) ${track.title}';
        _emit();

        final ok = await _downloadTrack(track.videoId, base, i);
        if (_cancelRequested) break;
        if (ok) {
          job.completed++;
          await _artwork(track.videoId, track.thumbnailUrl);
        } else {
          job.failed++;
        }
        _currentProgress = (i + 1) / job.tracks.length;
        _emit();
      }

      if (_cancelRequested) {
        job.status = DownloadJobStatus.cancelled;
        job.error = _lastDownloadError;
        _statusMessage =
            'Descarga cancelada. ${job.completed} pistas guardadas.';
      } else if (job.failed > 0 || job.completed < job.tracks.length) {
        job.status = DownloadJobStatus.failed;
        job.error = _lastDownloadError;
        _statusMessage =
            'Descarga incompleta: ${job.completed}/${job.tracks.length} guardadas, ${job.failed} fallidas. ${_lastDownloadError ?? 'Puedes reintentar.'}';
      } else {
        job.status = DownloadJobStatus.done;
        job.error = null;
        _statusMessage =
            'Descarga completada: ${job.completed}/${job.tracks.length} canciones.';
      }

      final success = job.status == DownloadJobStatus.done;
      if (!job.completer.isCompleted) {
        job.completer.complete(success);
      }
    } catch (e) {
      job.status = DownloadJobStatus.failed;
      job.error = e.toString();
      _statusMessage = 'Error en la descarga: $e';
      if (!job.completer.isCompleted) {
        job.completer.complete(false);
      }
    } finally {
      try {
        await storage.scanLibrary();
      } catch (e) {
        debugPrint('scanLibrary error: $e');
      } finally {
        _currentJob = null;
        _currentTrackTitle = null;
        _emit();
      }
    }
  }

  Future<bool> startDownload(
    MusicStorageService storageService, {
    String? targetSubfolder,
  }) async {
    final job = enqueue(storageService, targetSubfolder: targetSubfolder);
    if (job == null) return false;
    return await job.completer.future;
  }

  Future<bool> _downloadTrack(String id, String base, int index) async {
    for (final extension in ['m4a', 'webm']) {
      final file = File('$base.$extension');
      if (await file.exists() && await file.length() > 0) return true;
    }
    for (var attempt = 0; attempt < 3 && !_cancelRequested; attempt++) {
      YoutubeAudio? audio;
      RandomAccessFile? raf;
      File? partial;
      try {
        _statusMessage =
            '(${index + 1}/$_totalTracks) $_currentTrackTitle · intento ${attempt + 1}/3';
        _emit();
        audio = await _backend.audio(id, attempt);
        if (_cancelRequested) return false;
        if (!['m4a', 'webm'].contains(audio.extension)) {
          throw StateError('Formato de audio no compatible');
        }
        final tempDir = await _tempDirectory();
        final partFile = File('${tempDir.path}/aura_$id.part');
        partial = partFile;
        raf = await partFile.open(mode: FileMode.write);
        var received = 0;
        final stopwatch = Stopwatch()..start();
        var lastUpdate = 0;
        await for (final chunk in audio.bytes.timeout(
          const Duration(seconds: 20),
        )) {
          if (_cancelRequested) return false;
          await raf.writeFrom(chunk);
          received += chunk.length;
          if (stopwatch.elapsed > const Duration(minutes: 5)) {
            throw TimeoutException('Tiempo máximo por pista');
          }
          if (stopwatch.elapsedMilliseconds - lastUpdate > 150) {
            lastUpdate = stopwatch.elapsedMilliseconds;
            _currentProgress =
                (index +
                    (audio.size > 0
                        ? (received / audio.size).clamp(0.0, 1.0)
                        : 0)) /
                _totalTracks;
            _emit();
          }
        }
        await raf.close();
        raf = null;
        if (_cancelRequested) return false;
        if (received == 0 || (audio.size > 0 && received != audio.size)) {
          throw StateError('Audio incompleto: $received/${audio.size} bytes');
        }
        final target = File('$base.${audio.extension}');
        try {
          await partFile.rename(target.path);
        } on FileSystemException {
          try {
            await partFile.copy(target.path);
          } catch (copyError) {
            if (await target.exists()) {
              await target.delete();
            }
            rethrow;
          }
        }
        return true;
      } catch (e) {
        if (e is FileSystemException) {
          final osMsg = e.osError?.message;
          final msg = (osMsg != null && osMsg.isNotEmpty) ? osMsg : e.message;
          _lastDownloadError =
              'No se pudo guardar el audio en la carpeta de música: $msg';
          debugPrint('YouTube $id, intento ${attempt + 1}: $e');
          return false;
        }
        final detail = e.toString();
        _lastDownloadError =
            detail.contains('403') || detail.contains('not a bot')
            ? 'YouTube rechazó el acceso al audio (403/verificación). No se guardaron archivos incompletos.'
            : e is TimeoutException
            ? 'YouTube no respondió a tiempo. Revisa tu conexión y reintenta.'
            : 'No se pudo obtener el audio. Puedes reintentar.';
        debugPrint('YouTube $id, intento ${attempt + 1}: $e');
      } finally {
        audio?.close();
        await raf?.close();
        if (partial != null && await partial.exists()) {
          await partial.delete();
        }
      }
    }
    return false;
  }

  Future<void> _artwork(String videoId, String url) async {
    if (_cancelRequested || _disposed) return;
    try {
      final dir = await _artworkDirectory();
      await dir.create(recursive: true);
      final file = artworkFileFor(dir, videoId);
      if (await file.exists() && await file.length() > 0) return;
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
      }
    } catch (e) {
      debugPrint('Carátula opcional no disponible: $e');
    }
  }

  String _safeName(String input) {
    var name = (MetadataTextFixer.cleanTagText(input) ?? input)
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (name.isEmpty || name == '.' || name == '..') name = 'YouTube';
    return String.fromCharCodes(name.runes.take(100));
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelRequested = true;
    _backend.cancel();
    super.dispose();
  }
}
