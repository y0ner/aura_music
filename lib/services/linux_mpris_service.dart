import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import '../models/song_model.dart';
import 'player_service.dart';

/// Control de medios MPRIS (org.mpris.MediaPlayer2) para Linux. Es el
/// equivalente de escritorio a la notificación de Android: GNOME/KDE muestran
/// el widget de medios con la canción actual y sus botones, aunque la ventana
/// esté minimizada.
class LinuxMprisService {
  static const _busName = 'org.mpris.MediaPlayer2.aura_music';
  static const _path = '/org/mpris/MediaPlayer2';
  static const _rootInterface = 'org.mpris.MediaPlayer2';
  static const _playerInterface = 'org.mpris.MediaPlayer2.Player';

  final PlayerService _player;
  DBusClient? _client;
  _MprisObject? _object;
  String? _lastStatus;
  String? _lastSongId;
  bool? _lastCanGoNext;

  LinuxMprisService(this._player);

  Future<void> start() async {
    final client = DBusClient.session();
    final reply = await client.requestName(_busName);
    if (reply != DBusRequestNameReply.primaryOwner) {
      await client.close();
      throw StateError('El nombre $_busName ya está en uso: $reply');
    }
    final object = _MprisObject(this);
    await client.registerObject(object);
    _client = client;
    _object = object;
    _player.addListener(_onPlayerChanged);
    _onPlayerChanged();
  }

  Future<void> dispose() async {
    _player.removeListener(_onPlayerChanged);
    final client = _client;
    _client = null;
    await client?.close();
  }

  String get _status {
    if (_player.currentSong == null) return 'Stopped';
    return _player.isPlaying ? 'Playing' : 'Paused';
  }

  bool get _canGoNext => _player.queue.isNotEmpty;

  String _trackPath(Song song) =>
      '/org/mpris/MediaPlayer2/track/${song.id.hashCode.toUnsigned(32)}';

  Map<String, DBusValue> _metadata() {
    final song = _player.currentSong;
    if (song == null) {
      return {
        'mpris:trackid': DBusObjectPath('/org/mpris/MediaPlayer2/TrackList/NoTrack'),
      };
    }
    return {
      'mpris:trackid': DBusObjectPath(_trackPath(song)),
      'mpris:length': DBusInt64(song.duration.inMicroseconds),
      'xesam:title': DBusString(song.title),
      'xesam:artist': DBusArray(DBusSignature('s'), [DBusString(song.artist)]),
      'xesam:album': DBusString(song.album),
    };
  }

  /// Valor de una propiedad MPRIS, o null si no existe.
  DBusValue? property(String interface, String name) {
    final all = allProperties(interface);
    return all[name];
  }

  Map<String, DBusValue> allProperties(String interface) {
    if (interface == _rootInterface) {
      return {
        'CanQuit': DBusBoolean(true),
        'CanRaise': DBusBoolean(false),
        'HasTrackList': DBusBoolean(false),
        'Identity': DBusString('Aura Music'),
        'SupportedUriSchemes': DBusArray(DBusSignature('s')),
        'SupportedMimeTypes': DBusArray(DBusSignature('s')),
      };
    }
    if (interface == _playerInterface) {
      return {
        'PlaybackStatus': DBusString(_status),
        'LoopStatus': DBusString('None'),
        'Rate': DBusDouble(1.0),
        'MinimumRate': DBusDouble(1.0),
        'MaximumRate': DBusDouble(1.0),
        'Shuffle': DBusBoolean(_player.isShuffle),
        'Metadata': DBusDict.stringVariant(_metadata()),
        'Volume': DBusDouble(1.0),
        'Position': DBusInt64(_player.position.inMicroseconds),
        'CanGoNext': DBusBoolean(_canGoNext),
        'CanGoPrevious': DBusBoolean(_canGoNext),
        'CanPlay': DBusBoolean(_player.currentSong != null || _canGoNext),
        'CanPause': DBusBoolean(_player.currentSong != null),
        'CanSeek': DBusBoolean(_player.currentSong != null),
        'CanControl': DBusBoolean(true),
      };
    }
    return {};
  }

  /// Emite PropertiesChanged solo cuando cambia algo que los clientes usan
  /// (estado, canción, siguiente). La posición la consultan por su cuenta.
  void _onPlayerChanged() {
    final object = _object;
    if (object == null) return;
    final status = _status;
    final songId = _player.currentSong?.id;
    final canGoNext = _canGoNext;

    final changed = <String, DBusValue>{};
    if (status != _lastStatus) {
      changed['PlaybackStatus'] = DBusString(status);
    }
    if (songId != _lastSongId) {
      changed['Metadata'] = DBusDict.stringVariant(_metadata());
    }
    if (canGoNext != _lastCanGoNext) {
      changed['CanGoNext'] = DBusBoolean(canGoNext);
      changed['CanGoPrevious'] = DBusBoolean(canGoNext);
    }
    _lastStatus = status;
    _lastSongId = songId;
    _lastCanGoNext = canGoNext;
    if (changed.isEmpty) return;
    unawaited(
      object
          .emitPropertiesChanged(_playerInterface, changedProperties: changed)
          .catchError((Object e) => debugPrint('MPRIS: error emitiendo $e')),
    );
  }

  Future<void> handleSeek(Duration target) => _player.seek(target);
}

class _MprisObject extends DBusObject {
  final LinuxMprisService _service;

  _MprisObject(this._service) : super(DBusObjectPath(LinuxMprisService._path));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    final player = _service._player;
    if (call.interface == LinuxMprisService._rootInterface) {
      switch (call.name) {
        case 'Raise':
          return DBusMethodSuccessResponse();
        case 'Quit':
          await player.stopAndClear();
          exit(0);
        default:
          return DBusMethodErrorResponse.unknownMethod();
      }
    }
    if (call.interface == LinuxMprisService._playerInterface) {
      switch (call.name) {
        case 'Next':
          await player.next();
        case 'Previous':
          await player.previous();
        case 'Play':
          if (!player.isPlaying) await player.togglePlayPause();
        case 'Pause':
          if (player.isPlaying) await player.togglePlayPause();
        case 'PlayPause':
          await player.togglePlayPause();
        case 'Stop':
          await player.stopAndClear();
        case 'Seek':
          final offset = call.values.first as DBusInt64;
          final target = player.position + Duration(microseconds: offset.value);
          await _service.handleSeek(target.isNegative ? Duration.zero : target);
        case 'SetPosition':
          final position = call.values[1] as DBusInt64;
          await _service.handleSeek(Duration(microseconds: position.value));
        default:
          return DBusMethodErrorResponse.unknownMethod();
      }
      return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownInterface();
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = _service.property(interface, name);
    if (value == null) return DBusMethodErrorResponse.unknownProperty();
    return DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    return DBusGetAllPropertiesResponse(_service.allProperties(interface));
  }
}
