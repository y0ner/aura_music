import 'dart:typed_data';

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final Duration duration;
  final Uint8List? artworkBytes;
  final bool isExplicit;
  bool isFavorite;
  final String category;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    required this.duration,
    this.artworkBytes,
    this.isExplicit = false,
    this.isFavorite = false,
    this.category = 'General',
  });

  /// Texto que se guarda cuando el archivo no trae artista.
  static const String unknownArtist = 'Artista desconocido';

  /// `false` si el artista es desconocido: la interfaz no debe mostrar
  /// «Artista desconocido», solo la duración u otro dato real.
  bool get hasKnownArtist =>
      artist.trim().isNotEmpty && artist.trim() != unknownArtist;

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
