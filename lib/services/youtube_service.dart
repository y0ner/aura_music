import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import 'storage_service.dart';

class YoutubePreview {
  final bool isPlaylist;
  final String id;
  final String title;
  final String author;
  final Duration? duration;
  final String thumbnailUrl;
  final int trackCount;

  YoutubePreview({
    required this.isPlaylist,
    required this.id,
    required this.title,
    required this.author,
    this.duration,
    required this.thumbnailUrl,
    this.trackCount = 1,
  });

  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class YoutubeDownloadService extends ChangeNotifier {
  final yt_exp.YoutubeExplode _yt = yt_exp.YoutubeExplode();

  bool _isAnalyzing = false;
  bool _isDownloading = false;
  double _currentProgress = 0.0;
  String _statusMessage = '';
  YoutubePreview? _preview;
  bool _cancelRequested = false;

  bool get isAnalyzing => _isAnalyzing;
  bool get isDownloading => _isDownloading;
  double get currentProgress => _currentProgress;
  String get statusMessage => _statusMessage;
  YoutubePreview? get preview => _preview;

  void clearPreview() {
    _preview = null;
    _statusMessage = '';
    _currentProgress = 0.0;
    notifyListeners();
  }

  void cancel() {
    _cancelRequested = true;
    _isDownloading = false;
    _statusMessage = 'Descarga cancelada.';
    notifyListeners();
  }

  /// Analyze the pasted URL to detect if it's a song or a playlist
  Future<YoutubePreview?> analyzeUrl(String input) async {
    final url = input.trim();
    if (url.isEmpty) return null;

    _isAnalyzing = true;
    _statusMessage = 'Analizando enlace...';
    _preview = null;
    notifyListeners();

    try {
      // Check if it's a playlist URL
      if (url.contains('list=')) {
        final playlistId = _extractPlaylistId(url);
        if (playlistId != null) {
          final playlist = await _yt.playlists.get(playlistId);
          
          String thumb = 'https://img.youtube.com/vi/default/hqdefault.jpg';
          try {
            thumb = playlist.thumbnails.highResUrl;
          } catch (_) {}

          _preview = YoutubePreview(
            isPlaylist: true,
            id: playlistId,
            title: playlist.title,
            author: playlist.author,
            thumbnailUrl: thumb,
            trackCount: playlist.videoCount ?? 0,
          );
          _statusMessage = 'Playlist encontrada: ${playlist.title}';
          return _preview;
        }
      }

      // Single video
      final videoId = _extractVideoId(url);
      if (videoId != null) {
        final video = await _yt.videos.get(videoId);
        _preview = YoutubePreview(
          isPlaylist: false,
          id: videoId,
          title: video.title,
          author: video.author,
          duration: video.duration,
          thumbnailUrl: video.thumbnails.highResUrl,
          trackCount: 1,
        );
        _statusMessage = 'Canción encontrada: ${video.title}';
        return _preview;
      }

      _statusMessage = 'Enlace de YouTube no reconocido.';
      return null;
    } catch (e) {
      debugPrint('Error analyzing YouTube link: $e');
      _statusMessage = 'Error al analizar: $e';
      return null;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  String? _extractPlaylistId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.queryParameters.containsKey('list')) {
        return uri.queryParameters['list'];
      }
      return null;
    } catch (_) {
      final reg = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)');
      final match = reg.firstMatch(url);
      return match?.group(1);
    }
  }

  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }
      if (uri.pathSegments.contains('watch')) {
        return uri.queryParameters['v'];
      }
      return null;
    } catch (_) {
      final reg = RegExp(r'(?:v=|\/)([0-9A-Za-z_-]{11}).*');
      final match = reg.firstMatch(url);
      return match?.group(1);
    }
  }

  /// Download the analyzed track or playlist into the target directory
  Future<bool> startDownload(MusicStorageService storageService, {String? targetSubfolder}) async {
    if (_preview == null || storageService.rootMusicDirectory == null) return false;

    _isDownloading = true;
    _cancelRequested = false;
    _currentProgress = 0.0;
    notifyListeners();

    try {
      if (_preview!.isPlaylist) {
        return await _downloadPlaylist(storageService);
      } else {
        return await _downloadSingleTrack(storageService, targetSubfolder: targetSubfolder);
      }
    } catch (e) {
      debugPrint('Error during download: $e');
      _statusMessage = 'Error en la descarga: $e';
      return false;
    } finally {
      _isDownloading = false;
      notifyListeners();
      await storageService.scanLibrary();
    }
  }

  Future<bool> _downloadSingleTrack(MusicStorageService storageService, {String? targetSubfolder}) async {
    final videoId = _preview!.id;
    final title = _sanitizeFilename(_preview!.title);
    
    // Choose destination folder
    Directory destDir = storageService.rootMusicDirectory!;
    if (targetSubfolder != null && targetSubfolder.isNotEmpty) {
      destDir = Directory('${storageService.rootMusicDirectory!.path}/$targetSubfolder');
      if (!await destDir.exists()) await destDir.create(recursive: true);
    }

    _statusMessage = 'Obteniendo stream de mejor calidad...';
    notifyListeners();

    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final audioStreamInfo = manifest.audioOnly.withHighestBitrate();

    final filePath = '${destDir.path}/$title.m4a';
    final file = File(filePath);
    final output = file.openWrite();

    final stream = _yt.videos.streamsClient.get(audioStreamInfo);
    final totalBytes = audioStreamInfo.size.totalBytes;
    int receivedBytes = 0;

    await for (final chunk in stream) {
      if (_cancelRequested) {
        await output.close();
        if (await file.exists()) await file.delete();
        return false;
      }
      output.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        _currentProgress = receivedBytes / totalBytes;
        _statusMessage = 'Descargando: ${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB (${(_currentProgress * 100).toInt()}%)';
        notifyListeners();
      }
    }

    await output.flush();
    await output.close();

    // Download and save high-res artwork image alongside the track
    await _saveArtworkFile(destDir, title, _preview!.thumbnailUrl);

    _statusMessage = '¡Descarga completada con éxito!';
    _currentProgress = 1.0;
    notifyListeners();
    return true;
  }

  Future<bool> _downloadPlaylist(MusicStorageService storageService) async {
    final playlistId = _preview!.id;
    final folderName = _sanitizeFilename(_preview!.title);

    // Auto-create folder for the playlist! (The core mechanic)
    final playlistDir = Directory('${storageService.rootMusicDirectory!.path}/$folderName');
    if (!await playlistDir.exists()) {
      await playlistDir.create(recursive: true);
    }

    _statusMessage = 'Cargando pistas de la playlist...';
    notifyListeners();

    final videoList = <yt_exp.Video>[];
    await for (final video in _yt.playlists.getVideos(playlistId)) {
      videoList.add(video);
      _statusMessage = 'Encontradas ${videoList.length} canciones...';
      notifyListeners();
    }

    final totalCount = videoList.length;
    int completed = 0;

    for (int i = 0; i < totalCount; i++) {
      if (_cancelRequested) break;

      final video = videoList[i];
      final title = _sanitizeFilename(video.title);
      final filePath = '${playlistDir.path}/$title.m4a';
      final file = File(filePath);

      if (await file.exists()) {
        completed++;
        continue;
      }

      _statusMessage = '(${i + 1}/$totalCount) Descargando: ${video.title}';
      notifyListeners();

      try {
        final manifest = await _yt.videos.streamsClient.getManifest(video.id);
        final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
        final stream = _yt.videos.streamsClient.get(audioStreamInfo);

        final output = file.openWrite();
        final totalBytes = audioStreamInfo.size.totalBytes;
        int receivedBytes = 0;

        await for (final chunk in stream) {
          if (_cancelRequested) {
            await output.close();
            if (await file.exists()) await file.delete();
            return false;
          }
          output.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            final trackProgress = receivedBytes / totalBytes;
            _currentProgress = (i + trackProgress) / totalCount;
            notifyListeners();
          }
        }

        await output.flush();
        await output.close();

        // Download artwork
        await _saveArtworkFile(playlistDir, title, video.thumbnails.highResUrl);

        completed++;
        _currentProgress = completed / totalCount;
        notifyListeners();
      } catch (e) {
        debugPrint('Error downloading ${video.title}: $e');
      }
    }

    _statusMessage = '¡Playlist descargada! ($completed/$totalCount pistas)';
    _currentProgress = 1.0;
    notifyListeners();
    return true;
  }

  Future<void> _saveArtworkFile(Directory dir, String baseName, String thumbUrl) async {
    try {
      final res = await http.get(Uri.parse(thumbUrl));
      if (res.statusCode == 200) {
        final imgFile = File('${dir.path}/$baseName.jpg');
        await imgFile.writeAsBytes(res.bodyBytes);
      }
    } catch (_) {}
  }

  String _sanitizeFilename(String input) {
    return input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
