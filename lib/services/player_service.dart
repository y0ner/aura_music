import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/song_model.dart';
import 'aura_audio_handler.dart';

enum AudioRepeatMode { off, all, one }

class PlayerService extends ChangeNotifier {
  /// Handler de la notificación/MediaSession (solo Android/iOS).
  final AuraAudioHandler? _audioHandler;
  ja.AudioPlayer? _jaPlayer;
  Process? _linuxProcess;
  Timer? _positionTimer;
  StreamSubscription<List<ja.IndexedAudioSource>>? _currentIndexStreamSub;

  Song? _currentSong;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  List<Song> _queue = [];
  int _currentIndex = -1;

  bool _isShuffle = false;
  AudioRepeatMode _repeatMode = AudioRepeatMode.off;
  bool _isLyricsMode = false;
  bool _notificationPermissionRequested = false;

  /// Arranque del reproductor de escritorio. Es un campo inyectable (por
  /// defecto `Process.start`) para poder probar los cambios rápidos de
  /// canción en tests sin depender de gst-play ni de hardware de audio.
  @visibleForTesting
  Future<Process> Function(String executable, List<String> arguments)
  linuxProcessStarter = _startDesktopProcess;

  static Future<Process> _startDesktopProcess(
    String executable,
    List<String> arguments,
  ) async {
    // Local codec setup leaves system packages untouched. Also support a
    // plugin directory shipped alongside a desktop bundle.
    final candidates = [
      Directory('${Directory.current.path}/.dart_tool/linux-codecs/usr/lib'),
      Directory(
        '${File(Platform.resolvedExecutable).parent.path}/lib/gstreamer-1.0',
      ),
    ];
    final plugins = <String>[];
    for (final directory in candidates) {
      if (!await directory.exists()) continue;
      await for (final file in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (file is File && file.uri.pathSegments.last == 'libgstlibav.so') {
          plugins.add(file.parent.path);
        }
      }
    }
    final previous = Platform.environment['GST_PLUGIN_PATH'];
    if (previous != null && previous.isNotEmpty) plugins.add(previous);
    final environment = plugins.isEmpty
        ? null
        : {'GST_PLUGIN_PATH': plugins.join(':')};
    // gst-play debe morir junto con la app. Si el proceso Dart termina, un hijo
    // normal queda huérfano y sigue sonando; setpriv --pdeathsig lo evita.
    if (Platform.isLinux &&
        (File('/usr/bin/setpriv').existsSync() ||
            File('/bin/setpriv').existsSync())) {
      return Process.start(
        'setpriv',
        ['--pdeathsig', 'KILL', '--', executable, ...arguments],
        environment: environment,
      );
    }
    return Process.start(executable, arguments, environment: environment);
  }

  String? _playbackError;
  String? get playbackError => _playbackError;

  void _desktopFailure(String message) {
    _positionTimer?.cancel();
    _isPlaying = false;
    _playbackError = message;
    notifyListeners();
  }

  void _observeDesktopProcess(Process process) {
    unawaited(process.stdout.drain<void>());
    var error = '';
    final errorsDone = Completer<void>();
    process.stderr.transform(const SystemEncoding().decoder).listen((text) {
      if (error.length < 4096) error += text;
    }, onDone: errorsDone.complete);
    unawaited(
      process.exitCode.then((code) async {
        // exitCode can arrive before the pipe has delivered its last bytes.
        await errorsDone.future;
        if (!identical(_linuxProcess, process)) return;
        _linuxProcess = null;
        if (code != 0 || error.contains('ERROR')) {
          _desktopFailure(
            error.contains('plug-in') || error.contains('plugins')
                ? 'Falta el decodificador de audio. Ejecuta bash tool/setup_linux_audio.sh.'
                : 'No se pudo reproducir la canción: ${error.trim()}',
          );
        } else {
          _positionTimer?.cancel();
          _isPlaying = false;
          notifyListeners();
        }
      }),
    );
  }

  /// Generación del cambio de pista en curso. Cada llamada a
  /// `_playCurrentFromQueue` toma `++_playGeneration`; si mientras un cambio
  /// sigue cargando llega otro (toques rápidos), el anterior queda obsoleto
  /// y debe abortar SIN tocar el reproductor nativo. Sin esto, dos cambios
  /// solapados dejaban sonando la primera canción: proceso gst-play huérfano
  /// en escritorio o cola nativa pisada en Android/iOS.
  int _playGeneration = 0;

  /// Mutex chapucero pero suficiente (Dart es single-thread) para que la
  /// sección que muta el reproductor nativo (stop + set + play / matar +
  /// arrancar gst-play) nunca se ejecute en dos cambios a la vez.
  Completer<void>? _switchLock;

  /// Carátulas ya resueltas (id de canción -> ruta o null): evita repetir
  /// getTemporaryDirectory + stat + escritura en cada cambio de pista, lo
  /// que además achica la ventana en que dos cambios pueden solaparse.
  final Map<String, String?> _artworkPathCache = {};

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isShuffle => _isShuffle;
  AudioRepeatMode get repeatMode => _repeatMode;
  bool get isLyricsMode => _isLyricsMode;

  double get progressRatio {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  PlayerService([this._audioHandler]) {
    _initPlayer();
  }

  void _initPlayer() {
    if (Platform.isAndroid || Platform.isIOS) {
      final handler = _audioHandler!;
      final player = handler.player;
      _jaPlayer = player;
      // Botones de la notificación: usan la misma lógica de cola que la UI.
      handler.onSkipToNext = () async => await next();
      handler.onSkipToPrevious = previous;
      handler.onToggleRepeat = toggleRepeat;

      player.playbackEventStream.listen(
        (_) {},
        onError: (Object e) {
          debugPrint('Error de playback: $e');
        },
      );

      // Sincroniza el índice Dart con la pista activa de la cola nativa: los
      // botones siguiente/anterior de la notificación cambian la pista a
      // través del servicio en segundo plano y así la app se entera.
      _currentIndexStreamSub = player.sequenceStream.listen((sequence) {
        if (sequence.isEmpty) return;
        final nativeIndex = player.currentIndex;
        if (nativeIndex != null &&
            nativeIndex != _currentIndex &&
            nativeIndex < _queue.length) {
          _currentIndex = nativeIndex;
          _currentSong = _queue[nativeIndex];
          _position = Duration.zero;
          notifyListeners();
        }
      });

      player.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        // Fin natural de la pista: just_audio emite completed y aquí se
        // decide si repetir la misma canción o avanzar automáticamente a la
        // siguiente de la cola. Toques de usuario (pause/stop) NO pasan por
        // completed, así que este bloque solo corre al terminar el audio.
        if (state.processingState == ja.ProcessingState.completed) {
          if (_repeatMode == AudioRepeatMode.one) {
            player.seek(Duration.zero);
            player.play();
          } else {
            _goToNextIndex();
            _playCurrentFromQueue();
          }
        }
        notifyListeners();
      });

      player.positionStream.listen((pos) {
        _position = pos;
        notifyListeners();
      });

      player.durationStream.listen((dur) {
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

    await _playCurrentFromQueue();
  }

  /// Inserts into both the local queue and the native notification queue.
  Future<void> enqueue(Song song, {bool next = false}) async {
    if (_queue.isEmpty) {
      await playSong(song);
      return;
    }
    final index = next ? _currentIndex + 1 : _queue.length;
    final generation = _playGeneration;
    await _acquireSwitchLock();
    try {
      if (generation != _playGeneration) return;
      if (_jaPlayer != null) {
        final artPath = await _resolveArtworkPath(song);
        if (generation != _playGeneration) return;
        await _jaPlayer!.insertAudioSource(
          index,
          ja.AudioSource.uri(
            Uri.file(song.filePath),
            tag: MediaItem(
              id: song.id,
              title: song.title,
              artist: song.artist,
              album: song.album,
              duration: song.duration,
              artUri: artPath == null ? null : Uri.file(artPath),
            ),
          ),
        );
      }
      _queue.insert(index, song);
      notifyListeners();
    } finally {
      _releaseSwitchLock();
    }
  }

  Future<void> _acquireSwitchLock() async {
    while (_switchLock != null) {
      await _switchLock!.future;
    }
    _switchLock = Completer<void>();
  }

  void _releaseSwitchLock() {
    _switchLock?.complete();
    _switchLock = null;
  }

  /// Reproduce la canción en _currentIndex. En Android/iOS la fuente lleva
  /// un MediaItem como tag: es lo que AuraAudioHandler convierte en la
  /// notificación persistente estilo YouTube Music (carátula, título y
  /// controles play/pausa/siguiente/anterior).
  ///
  /// Los cambios rápidos seguidos (tocar A y enseguida B) se serializan con
  /// [_playGeneration] + [_switchLock]: solo el ÚLTIMO pedido toca el
  /// reproductor nativo; los anteriores abortan. Sin esto, el cambio viejo
  /// pisaba al nuevo y se quedaba sonando siempre la primera canción.
  Future<void> _playCurrentFromQueue() async {
    if (_queue.isEmpty || _currentIndex < 0 || _currentIndex >= _queue.length) {
      _currentSong = null;
      notifyListeners();
      return;
    }

    final song = _queue[_currentIndex];
    // Foto del pedido: la parte asíncrona usa estos valores aunque otro
    // toque cambie _queue/_currentIndex mientras tanto.
    final targetQueue = List<Song>.from(_queue);
    final targetIndex = _currentIndex;
    final myGeneration = ++_playGeneration;

    _currentSong = song;
    _playbackError = null;
    _position = Duration.zero;
    _duration = song.duration;
    _isPlaying = true;
    notifyListeners();

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final player = _jaPlayer!;

        // Android 13+ suprime la notificación de reproducción sin el permiso
        // POST_NOTIFICATIONS. Se pide solo en la primera reproducción y SIN
        // bloquear el audio: pedirlo al arrancar la app congela el diálogo de
        // MIUI/HyperOS como activity invisible y la pantalla queda en negro.
        if (Platform.isAndroid && !_notificationPermissionRequested) {
          _notificationPermissionRequested = true;
          unawaited(() async {
            try {
              final status = await Permission.notification.request();
              debugPrint('Permiso de notificaciones: $status');
            } catch (e) {
              debugPrint('Error pidiendo permiso de notificaciones: $e');
            }
          }());
        }

        // Cola nativa completa: la notificación estilo YouTube Music muestra
        // anterior/siguiente y saltar entre pistas funciona desde la sombra
        // sin reabrir la app. Se arma FUERA del lock (es lo lento); si
        // mientras tanto llega otro toque, este pedido ya es obsoleto y se
        // descarta sin tocar el reproductor.
        final children = <ja.AudioSource>[];
        for (final item in targetQueue) {
          if (myGeneration != _playGeneration) return;
          final artPath = await _resolveArtworkPath(item);
          children.add(
            ja.AudioSource.uri(
              Uri.file(item.filePath),
              tag: MediaItem(
                id: item.id,
                album: item.album,
                title: item.title,
                artist: item.artist,
                duration: item.duration,
                artUri: artPath == null ? null : Uri.file(artPath),
              ),
            ),
          );
        }
        if (myGeneration != _playGeneration) return;

        // El lock cubre solo stop + setAudioSources. NO se espera play(): su
        // Future completa cuando la canción termina o se pausa, así que tenerlo
        // dentro del lock dejaba bloqueado el cambio de pista mientras sonaba.
        await _acquireSwitchLock();
        try {
          if (myGeneration != _playGeneration) return;
          await player.stop();
          await player.setAudioSources(children, initialIndex: targetIndex);
        } finally {
          _releaseSwitchLock();
        }
        // Sin await entre esta comprobación y play(): ningún pedido nuevo puede
        // colarse y el último pedido siempre es el que suena.
        if (myGeneration != _playGeneration) return;
        unawaited(
          player.play().catchError(
            (Object e) => debugPrint('Error al reproducir: $e'),
          ),
        );
      } catch (e) {
        debugPrint('Error playing via just_audio: $e');
        // Respaldo sin tag: suena igual, solo sin notificación enriquecida.
        // Solo si nadie pidió otra canción mientras tanto.
        if (myGeneration != _playGeneration) return;
        await _acquireSwitchLock();
        try {
          if (myGeneration != _playGeneration) return;
          await _jaPlayer?.setFilePath(song.filePath);
        } catch (e2) {
          debugPrint('Error con el respaldo de reproducción: $e2');
        } finally {
          _releaseSwitchLock();
        }
        if (myGeneration != _playGeneration) return;
        unawaited(
          _jaPlayer?.play().catchError(
            (Object e) => debugPrint('Error con el respaldo de reproducción: $e'),
          ),
        );
      }
    } else {
      // Linux y demás escritorio: gst-play-1.0 (serializado + generación).
      await _acquireSwitchLock();
      try {
        if (myGeneration != _playGeneration) return;
        await _switchLinuxTrack(song.filePath, myGeneration);
      } finally {
        _releaseSwitchLock();
      }
    }
  }

  /// Cambio de pista en escritorio. Debe llamarse con [_switchLock] tomado:
  /// mata el proceso anterior ANTES de arrancar el nuevo (así nunca quedan
  /// dos gst-play sonando) y si al terminar de arrancar el pedido ya es
  /// obsoleto, mata el recién nacido para no dejarlo huérfano.
  Future<void> _switchLinuxTrack(String path, int myGeneration) async {
    _stopLinuxAudio();
    try {
      final proc = await linuxProcessStarter('gst-play-1.0', [
        '--no-interactive',
        '--quiet',
        path,
      ]);
      if (myGeneration != _playGeneration) {
        try {
          proc.kill();
        } catch (_) {}
        return;
      }
      _linuxProcess = proc;
      _observeDesktopProcess(proc);
      _startPositionTimer();
    } catch (e) {
      debugPrint('Error iniciando gst-play-1.0: $e');
      if (myGeneration == _playGeneration) {
        _desktopFailure('No se pudo iniciar el reproductor: $e');
      }
    }
  }

  /// Ruta del cache de carátula para la notificación: MediaItem.artUri solo
  /// acepta URIs, no bytes en memoria, así que se escribe una vez a archivo.
  /// Debe ser un directorio privado de la app (getTemporaryDirectory): en
  /// Android 10+ el servicio en segundo plano no puede leer rutas externas
  /// como Directory.systemTemp y la carátula saldría vacía.
  Future<String?> _resolveArtworkPath(Song song) async {
    if (song.artworkBytes == null || song.artworkBytes!.isEmpty) return null;
    if (_artworkPathCache.containsKey(song.id)) {
      return _artworkPathCache[song.id];
    }
    String? result;
    try {
      final safeName = song.id
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
          .hashCode
          .toRadixString(36);
      final cacheDir = await getTemporaryDirectory();
      final file = File('${cacheDir.path}/aura_art_$safeName.jpg');
      if (!file.existsSync() ||
          file.lengthSync() != song.artworkBytes!.length) {
        await file.writeAsBytes(song.artworkBytes!);
      }
      result = file.path;
    } catch (e) {
      debugPrint('Error cacheando carátula: $e');
      result = null;
    }
    _artworkPathCache[song.id] = result;
    return result;
  }

  Future<void> _playOnLinux(String path, {int startSeconds = 0}) async {
    _stopLinuxAudio();
    try {
      final args = <String>['--no-interactive', '--quiet'];
      if (startSeconds > 0) {
        args.addAll(['-s', '$startSeconds']);
      }
      args.add(path);

      _linuxProcess = await linuxProcessStarter('gst-play-1.0', args);
      _observeDesktopProcess(_linuxProcess!);
      _startPositionTimer();
    } catch (e) {
      debugPrint('Error iniciando gst-play-1.0: $e');
      _desktopFailure('No se pudo iniciar el reproductor: $e');
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
      if (_duration.inSeconds > 0 && nextSec >= _duration.inSeconds) {
        // Fin por reloj en escritorio: repite o pasa a la siguiente.
        if (_repeatMode == AudioRepeatMode.one) {
          _position = Duration.zero;
          notifyListeners();
          if (_currentSong != null) {
            _playOnLinux(_currentSong!.filePath);
          }
        } else {
          _goToNextIndex();
          _playCurrentFromQueue();
        }
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
        _stopLinuxAudio();
      }
    } else {
      _isPlaying = true;
      if (Platform.isAndroid || Platform.isIOS) {
        await _jaPlayer?.play();
      } else {
        if (_currentSong != null) {
          await _playOnLinux(
            _currentSong!.filePath,
            startSeconds: _position.inSeconds,
          );
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
        await _playOnLinux(
          _currentSong!.filePath,
          startSeconds: target.inSeconds,
        );
      }
    }
  }

  Future<bool> next() async {
    if (_queue.isEmpty) return false;
    if (_queue.length == 1 && _repeatMode == AudioRepeatMode.off) {
      // Única canción de la cola: vuelve a empezar en lugar de reiniciar la
      // misma pista sin sentido.
      await seek(Duration.zero);
      return false;
    }

    _goToNextIndex();
    await _playCurrentFromQueue();
    return true;
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;

    // Comportamiento estándar de música: si ya pasaron más de 3 segundos,
    // «anterior» reinicia la canción actual.
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_isShuffle) {
      _goToNextIndex();
    } else if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = _queue.length - 1;
    }

    await _playCurrentFromQueue();
  }

  /// Avanza el índice respetando shuffle. Repeat.one se maneja aparte por
  /// quien llama (no debe mover el índice).
  void _goToNextIndex() {
    if (_queue.isEmpty) return;

    if (_isShuffle) {
      final random = Random();
      _currentIndex = random.nextInt(_queue.length);
    } else {
      _currentIndex = (_currentIndex + 1) % _queue.length;
    }
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
    _audioHandler?.setRepeatState(
      enabled: _repeatMode != AudioRepeatMode.off,
      one: _repeatMode == AudioRepeatMode.one,
    );
    notifyListeners();
  }

  /// Alterna la vista de Letra del reproductor fullscreen (píldora
  /// Canción | Letra). Es solo estado de UI: no toca la reproducción.
  void toggleLyricsMode() {
    _isLyricsMode = !_isLyricsMode;
    notifyListeners();
  }

  /// Quita una canción de la cola sin cortar la reproducción (se usa cuando
  /// el usuario borra un archivo desde la app). Ajusta el índice actual para
  /// que el auto-avance siga correcto. Devuelve true si estaba en la cola.
  bool removeSongFromQueue(String songId) {
    if (_queue.isEmpty) return false;

    final removedIndex = _queue.indexWhere((s) => s.id == songId);
    if (removedIndex == -1) return false;

    _queue.removeAt(removedIndex);

    if (removedIndex < _currentIndex) {
      _currentIndex--;
    } else if (removedIndex == _currentIndex) {
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.isEmpty ? -1 : 0;
      } else {
        _currentIndex--;
      }
    }

    if (_queue.isEmpty) {
      stopAndClear();
      return true;
    }

    notifyListeners();
    return true;
  }

  /// Detiene la reproducción y limpia la cola.
  Future<void> stopAndClear() async {
    // Invalida cualquier cambio de pista que siga cargando: no debe
    // arrancar audio después de limpiar.
    _playGeneration++;
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _jaPlayer?.stop();
      } catch (_) {}
    } else {
      _stopLinuxAudio();
    }
    _queue = [];
    _currentIndex = -1;
    _currentSong = null;
    _isPlaying = false;
    _position = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _currentIndexStreamSub?.cancel();
    _stopLinuxAudio();
    _jaPlayer?.dispose();
    super.dispose();
  }
}
