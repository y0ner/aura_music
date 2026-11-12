import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef DirectoryProvider = Future<Directory> Function();

Future<Directory> defaultArtworkDirectory() async =>
    Directory('${(await getApplicationSupportDirectory()).path}/covers');

final _videoIdRegExp = RegExp(r'\[([A-Za-z0-9_-]{11})\]\.[A-Za-z0-9]+$');

String? videoIdFromPath(String path) {
  final fileName = path.split(RegExp(r'[/\\]')).last;
  final match = _videoIdRegExp.firstMatch(fileName);
  return match?.group(1);
}

File artworkFileFor(Directory dir, String videoId) =>
    File('${dir.path}/$videoId.jpg');
