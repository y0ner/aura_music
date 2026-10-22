import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

/// Handler de audio para Android/iOS. Reemplaza al de just_audio_background
/// para controlar la MediaSession: notificación con carátula grande, barra de
/// progreso con tiempos y los botones extra de repetir y «me gusta».
///
/// La cola y el modo de repetición viven en PlayerService; este handler solo
/// refleja el estado del reproductor y delega las acciones en callbacks.
class AuraAudioHandler extends BaseAudioHandler with SeekHandler {
  final ja.AudioPlayer player = ja.AudioPlayer();

  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;
  void Function()? onToggleRepeat;

  bool _repeatEnabled = false;
  bool _repeatOne = false;
  final Set<String> _favorites = {};

  AuraAudioHandler() {
    player.playbackEventStream.listen(
      (_) => _broadcast(),
      onError: (Object e) => debugPrint('Error de playback: $e'),
    );
    player.playerStateStream.listen((_) => _broadcast());
    player.positionStream.listen((_) => _broadcast());
    player.durationStream.listen((_) => _updateMediaItem());
    player.sequenceStateStream.listen((_) => _updateMediaItem());
  }

  /// PlayerService llama esto cada vez que cambia el modo de repetición.
  void setRepeatState({required bool enabled, required bool one}) {
    _repeatEnabled = enabled;
    _repeatOne = one;
    _broadcast();
  }

  void _updateMediaItem() {
    final index = player.currentIndex;
    final sequence = player.sequence;
    if (index == null || index < 0 || index >= sequence.length) return;
    final tag = sequence[index].tag;
    if (tag is! MediaItem) return;
    mediaItem.add(tag.copyWith(duration: player.duration ?? tag.duration));
    _broadcast();
  }

  void _toggleFavorite() {
    final id = mediaItem.value?.id;
    if (id == null) return;
    if (!_favorites.add(id)) _favorites.remove(id);
    _broadcast();
  }

  void _broadcast() {
    final id = mediaItem.value?.id;
    final favorite = id != null && _favorites.contains(id);

    final repeatIcon = !_repeatEnabled
        ? 'drawable/ic_aura_repeat_off'
        : _repeatOne
        ? 'drawable/ic_aura_repeat_one'
        : 'drawable/ic_aura_repeat';

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.custom(
            androidIcon: repeatIcon,
            label: 'Repetir',
            name: 'repeat',
          ),
          MediaControl.skipToPrevious,
          player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.custom(
            androidIcon: favorite
                ? 'drawable/ic_aura_favorite'
                : 'drawable/ic_aura_favorite_border',
            label: favorite ? 'Quitar de me gusta' : 'Me gusta',
            name: 'favorite',
          ),
        ],
        androidCompactActionIndices: const [1, 2, 3],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: AudioProcessingState.values.byName(
          player.processingState.name,
        ),
        playing: player.playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: player.currentIndex,
      ),
    );
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async => onSkipToNext?.call();

  @override
  Future<void> skipToPrevious() async => onSkipToPrevious?.call();

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    switch (name) {
      case 'repeat':
        onToggleRepeat?.call();
      case 'favorite':
        _toggleFavorite();
    }
  }

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }
}
