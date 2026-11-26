import 'package:aura_music/models/song_model.dart';
import 'package:aura_music/services/play_history.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song(String id, String title) => Song(
  id: id,
  title: title,
  artist: 'Artista',
  album: 'Álbum',
  filePath: '/music/$id.m4a',
  duration: const Duration(minutes: 3),
);

void main() {
  test(
    'tres notificaciones de la misma canción registran 1; al cambiar de canción, 2',
    () {
      final current = ValueNotifier<Song?>(null);
      final recorded = <Song>[];

      connectPlayHistory(current, () => current.value, recorded.add);

      current.value = _song('song-a', 'Primera (1)');
      current.value = _song('song-a', 'Primera (2)');
      current.value = _song('song-a', 'Primera (3)');
      expect(recorded.map((s) => s.id).toList(), ['song-a']);

      current.value = _song('song-b', 'Segunda');
      expect(recorded.map((s) => s.id).toList(), ['song-a', 'song-b']);
    },
  );

  test('ignora null y vuelve a registrar si cambia después de limpiar', () {
    final current = ValueNotifier<Song?>(null);
    final recorded = <Song>[];

    connectPlayHistory(current, () => current.value, recorded.add);

    current.value = _song('song-a', 'Primera');
    current.value = null;
    expect(recorded, hasLength(1));

    current.value = _song('song-a', 'Primera de nuevo');
    expect(recorded, hasLength(2));
  });
}
