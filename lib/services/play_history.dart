import 'package:flutter/foundation.dart';

import '../models/song_model.dart';

/// Escucha [source] y registra cada reproducción en [record] una sola vez por
/// cambio de canción (comparando por `id`).
void connectPlayHistory(
  Listenable source,
  Song? Function() current,
  void Function(Song) record,
) {
  var lastSongId = current()?.id;
  source.addListener(() {
    final song = current();
    if (song == null) {
      lastSongId = null;
      return;
    }
    if (song.id == lastSongId) return;
    lastSongId = song.id;
    record(song);
  });
}
