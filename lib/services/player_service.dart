import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import '../models/song_model.dart';

enum AudioRepeatMode { off, all, one }

class PlayerService extends ChangeNotifier {
  ja.AudioPlayer? _jaPlayer;
  Process? _linuxProcess;
  Timer? _positionTimer;

  Song? _currentSong;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  List<Song> _queue = [];
  int _currentIndex = -1;

  bool _isShuffle = false;
  AudioRepeatMode _repeatMode = AudioRepeatMode.off;
  bool _isVideoMode = false;

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isShuffle => _isShuffle;
  AudioRepeatMode get repeatMode => _repeatMode;
  bool get isVideoMode => _isVideoMode;

  double get progressRatio {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  PlayerService() {
    _initPlayer();
  }

  void _initPlayer() {
    if (Platform.isAndroid || Platform.isIOS) {
      _jaPlayer = ja.AudioPlayer();
      _jaPlayer!.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        if (state.processingState == ja.ProcessingState.completed) {
          _onTrackFinished();
        }
        notifyListeners();
      });

      _jaPlayer!.positionStream.listen((pos) {
        _position = pos;
        notifyListeners();
      });

      _jaPlayer!.durationStream.listen((dur) {
        if (dur != null) {
          _duration = dur;
          notifyListeners();
        }
      });
    }
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    if (playlist != null && playlist.isNotEmpty) {
      _queue = List.from(playlist);
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) {
        _queue.insert(0, song);
        _currentIndex = 0;
      }
    } else {
      if (!_queue.any((s) => s.id == song.id)) {
        _queue.add(song);
      }
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    }

    _currentSong = song;
    _position = Duration.zero;
    _duration = song.duration;
    _isPlaying = true;
    notifyListeners();

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _jaPlayer?.stop();
        await _jaPlayer?.setFilePath(song.filePath);
        await _jaPlayer?.play();
      } catch (e) {
        debugPrint('Error playing via just_audio: $e');
      }
    } else {
      // Native Linux audio playback using gst-play-1.0
      await _playOnLinux(song.filePath);
    }
  }

  Future<void> _playOnLinux(String path, {int startSeconds = 0}) async {
    _stopLinuxAudio();
    try {
      final args = <String>['--no-interactive', '--quiet'];
      if (startSeconds > 0) {
        args.addAll(['-s', '$startSeconds']);
      }
      args.add(path);

      _linuxProcess = await Process.start('gst-play-1.0', args);
      _startPositionTimer();
    } catch (e) {
      debugPrint('Error starting gst-play-1.0: $e');
      // Fallback timer simulation for UI demonstration
      _startPositionTimer();
    }
  }

  void _stopLinuxAudio() {
    _positionTimer?.cancel();
    if (_linuxProcess != null) {
      _linuxProcess!.kill();
      _linuxProcess = null;
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPlaying) return;
      final nextSec = _position.inSeconds + 1;
      if (nextSec >= _duration.inSeconds && _duration.inSeconds > 0) {
        _onTrackFinished();
      } else {
        _position = Duration(seconds: nextSec);
        notifyListeners();
      }
    });
  }

  Future<void> togglePlayPause() async {
    if (_currentSong == null && _queue.isNotEmpty) {
      await playSong(_queue.first);
      return;
    }

    if (_isPlaying) {
      _isPlaying = false;
      if (Platform.isAndroid || Platform.isIOS) {
        await _jaPlayer?.pause();
      } else {
        _positionTimer?.cancel();
        _stopLinuxAudio();
      }
    } else {
      _isPlaying = true;
      if (Platform.isAndroid || Platform.isIOS) {
        await _jaPlayer?.play();
      } else {
        if (_currentSong != null) {
          await _playOnLinux(_currentSong!.filePath, startSeconds: _position.inSeconds);
        }
      }
    }
    notifyListeners();
  }

  Future<void> seek(Duration target) async {
    _position = target;
    notifyListeners();

    if (Platform.isAndroid || Platform.isIOS) {
      await _jaPlayer?.seek(target);
    } else {
      if (_isPlaying && _currentSong != null) {
        await _playOnLinux(_currentSong!.filePath, startSeconds: target.inSeconds);
      }
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;

    if (_isShuffle) {
      final random = Random();
      _currentIndex = random.nextInt(_queue.length);
    } else {
      _currentIndex = (_currentIndex + 1) % _queue.length;
    }

    await playSong(_queue[_currentIndex]);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = _queue.length - 1;
    }

    await playSong(_queue[_currentIndex]);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    switch (_repeatMode) {
      case AudioRepeatMode.off:
        _repeatMode = AudioRepeatMode.all;
        break;
      case AudioRepeatMode.all:
        _repeatMode = AudioRepeatMode.one;
        break;
      case AudioRepeatMode.one:
        _repeatMode = AudioRepeatMode.off;
        break;
    }
    notifyListeners();
  }

  void toggleVideoSongMode() {
    _isVideoMode = !_isVideoMode;
    notifyListeners();
  }

  Future<void> _onTrackFinished() async {
    if (_repeatMode == AudioRepeatMode.one && _currentSong != null) {
      await seek(Duration.zero);
      if (Platform.isAndroid || Platform.isIOS) {
        await _jaPlayer?.play();
      } else {
        await _playOnLinux(_currentSong!.filePath);
      }
    } else {
      await next();
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _stopLinuxAudio();
    _jaPlayer?.dispose();
    super.dispose();
  }
}
