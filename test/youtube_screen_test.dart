import 'package:aura_music/models/playlist_model.dart';
import 'package:aura_music/screens/youtube_screen.dart';
import 'package:aura_music/services/playlist_fetcher.dart';
import 'package:aura_music/services/storage_service.dart';
import 'package:aura_music/services/youtube_service.dart';
import 'package:aura_music/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Youtube extends YoutubeDownloadService {
  YoutubePreview? result;
  bool downloading = false;
  String? analyzed;
  String? destination;
  bool cancelled = false;
  bool downloaded = false;
  List<DownloadJob> queueJobs = [];

  @override
  YoutubePreview? get preview => result;
  @override
  bool get isDownloading => downloading;
  @override
  bool get isPreviewDownloaded => downloaded;
  @override
  String get statusMessage =>
      downloading ? 'Descargando un título largo sin cortar el mensaje' : '';
  @override
  int get totalTracks => 16;
  @override
  int get completedTracks => 5;
  @override
  double get currentProgress => .31;
  @override
  String get currentTrackTitle => 'MORPHINE';

  @override
  List<DownloadJob> get jobs => List.unmodifiable(queueJobs);

  @override
  DownloadJob? get currentJob {
    if (downloading && result != null) {
      return DownloadJob(
        id: 1,
        preview: result!,
        tracks: [PlaylistTrack(videoId: result!.id, title: result!.title)],
        status: DownloadJobStatus.downloading,
        completed: 5,
      );
    }
    return queueJobs
        .where((j) => j.status == DownloadJobStatus.downloading)
        .firstOrNull;
  }

  @override
  int get waitingCount =>
      queueJobs.where((j) => j.status == DownloadJobStatus.waiting).length;

  @override
  DownloadJob? jobFor(String previewId) {
    if (downloading && result?.id == previewId) {
      return DownloadJob(
        id: 1,
        preview: result!,
        tracks: [PlaylistTrack(videoId: result!.id, title: result!.title)],
        status: DownloadJobStatus.downloading,
        completed: 5,
      );
    }
    return queueJobs.reversed
        .where((j) => j.preview.id == previewId)
        .firstOrNull;
  }

  @override
  Future<YoutubePreview?> analyzeUrl(String input) async {
    analyzed = input;
    result = const YoutubePreview(
      isPlaylist: false,
      id: 'AAAAAAAAAAA',
      title: 'Una canción con un título largo para comprobar el diseño',
      author: 'Artista',
      thumbnailUrl: '',
      duration: Duration(minutes: 3),
    );
    notifyListeners();
    return result;
  }

  @override
  DownloadJob? enqueue(
    MusicStorageService storageService, {
    String? targetSubfolder,
  }) {
    destination = targetSubfolder;
    downloading = true;
    if (result != null) {
      final job = DownloadJob(
        id: 1,
        preview: result!,
        tracks: [PlaylistTrack(videoId: result!.id, title: result!.title)],
        targetSubfolder: targetSubfolder,
        status: DownloadJobStatus.downloading,
        completed: 5,
      );
      queueJobs = [job];
      notifyListeners();
      return job;
    }
    notifyListeners();
    return null;
  }

  @override
  Future<bool> startDownload(
    MusicStorageService storageService, {
    String? targetSubfolder,
  }) async {
    enqueue(storageService, targetSubfolder: targetSubfolder);
    return true;
  }

  @override
  void cancel() {
    cancelled = true;
    downloading = false;
    queueJobs.clear();
    notifyListeners();
  }
}

class _Storage extends MusicStorageService {
  @override
  List<Playlist> get playlists => [
    Playlist(id: '1', name: 'Favoritas', folderPath: '/music', songs: []),
  ];
}

void main() {
  for (final width in [320.0, 850.0]) {
    testWidgets('YouTube mantiene sus acciones sin desbordes a $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Youtube();
      final storage = _Storage();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<YoutubeDownloadService>.value(
              value: service,
            ),
            ChangeNotifierProvider<MusicStorageService>.value(value: storage),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: YoutubeScreen()),
          ),
        ),
      );
      expect(find.text('Añadir música'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
      await tester.enterText(
        find.byType(TextField),
        'https://youtu.be/AAAAAAAAAAA',
      );
      await tester.pump();
      await tester.tap(find.text('Analizar enlace'));
      await tester.pumpAndSettle();
      expect(service.analyzed, 'https://youtu.be/AAAAAAAAAAA');
      expect(find.text('Guardar en'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favoritas').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Descargar canción'));
      await tester.tap(find.text('Descargar canción'));
      await tester.pumpAndSettle();
      expect(service.destination, 'Favoritas');
      expect(find.text('Descargando • 5/16'), findsOneWidget);
      expect(find.text('31%'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancelar esta descarga'));
      await tester.tap(find.text('Cancelar esta descarga'));
      await tester.pumpAndSettle();
      expect(service.cancelled, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      storage.dispose();
    });
  }

  testWidgets(
    'con downloading = true y un job waiting en jobs se ve Cola de descargas, En espera y Quitar de la cola',
    (tester) async {
      final service = _Youtube();
      final storage = _Storage();
      service.downloading = true;
      const waitingPreview = YoutubePreview(
        isPlaylist: false,
        id: 'BBBBBBBBBBB',
        title: 'Segunda canción en espera',
        author: 'Artista 2',
        thumbnailUrl: '',
        duration: Duration(minutes: 2),
      );
      final waitingJob = DownloadJob(
        id: 2,
        preview: waitingPreview,
        tracks: const [
          PlaylistTrack(
            videoId: 'BBBBBBBBBBB',
            title: 'Segunda canción en espera',
          ),
        ],
        status: DownloadJobStatus.waiting,
      );
      service.queueJobs = [waitingJob];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<YoutubeDownloadService>.value(
              value: service,
            ),
            ChangeNotifierProvider<MusicStorageService>.value(value: storage),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: YoutubeScreen()),
          ),
        ),
      );

      expect(find.text('Cola de descargas'), findsOneWidget);
      expect(find.text('En espera'), findsOneWidget);
      expect(find.byTooltip('Quitar de la cola'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      storage.dispose();
    },
  );

  testWidgets(
    'con preview y downloaded = true oculta el botón y muestra confirmación',
    (tester) async {
      final service = _Youtube();
      final storage = _Storage();
      service.result = const YoutubePreview(
        isPlaylist: false,
        id: 'AAAAAAAAAAA',
        title: 'Canción ya descargada',
        author: 'Artista',
        thumbnailUrl: '',
        duration: Duration(minutes: 3),
      );
      service.downloaded = true;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<YoutubeDownloadService>.value(
              value: service,
            ),
            ChangeNotifierProvider<MusicStorageService>.value(value: storage),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: YoutubeScreen()),
          ),
        ),
      );
      expect(find.text('Descargar canción'), findsNothing);
      expect(find.text('Descargada en tu biblioteca'), findsOneWidget);
      expect(find.text('Pega otro enlace para descargar más.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      storage.dispose();
    },
  );
}
