import 'dart:async';

import '../services/playlist_fetcher.dart';
import '../services/storage_service.dart';
import '../services/youtube_service.dart';

enum DownloadJobStatus { waiting, downloading, done, failed, cancelled }

class DownloadJob {
  final int id;
  final YoutubePreview preview;
  final List<PlaylistTrack> tracks;
  final String? targetSubfolder;
  final MusicStorageService? storage;
  DownloadJobStatus status;
  int completed;
  int failed;
  String? error;
  final Completer<bool> completer;

  DownloadJob({
    required this.id,
    required this.preview,
    required List<PlaylistTrack> tracks,
    this.targetSubfolder,
    this.storage,
    this.status = DownloadJobStatus.waiting,
    this.completed = 0,
    this.failed = 0,
    this.error,
    Completer<bool>? completer,
  })  : tracks = List.unmodifiable(tracks),
        completer = completer ?? Completer<bool>();
}
