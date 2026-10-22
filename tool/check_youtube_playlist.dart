import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:aura_music/services/playlist_fetcher.dart';

Future<void> main() async {
  final timer = Stopwatch()..start();
  final playlist = await PlaylistFetcher.fetchOverview(
    'PL0oNlHO4mZfCHBGwxoOfCNHNeJnPDYRHU',
    onProgress: (count) => stdout.writeln('Pistas encontradas: $count'),
  );
  if (playlist.tracks.isEmpty) {
    final response = await http.get(
      Uri.parse(
        'https://www.youtube.com/playlist?list=PL0oNlHO4mZfCHBGwxoOfCNHNeJnPDYRHU&hl=en',
      ),
    );
    final data = PlaylistFetcher.extractYtInitialData(response.body);
    await File('/tmp/aura-playlist-debug.json').writeAsString(jsonEncode(data));
    throw StateError(
      'Playlist vacía; diagnóstico en /tmp/aura-playlist-debug.json',
    );
  }
  stdout.writeln(
    '${playlist.title}: ${playlist.tracks.length} pistas en ${timer.elapsed}',
  );
  for (final track in playlist.tracks.take(3)) {
    stdout.writeln('${track.videoId}: ${track.title}');
  }
}
