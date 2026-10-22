import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/aura_audio_handler.dart';
import 'services/linux_mpris_service.dart';
import 'services/storage_service.dart';
import 'services/player_service.dart';
import 'services/youtube_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  debugPrint('aura: main iniciando');
  WidgetsFlutterBinding.ensureInitialized();

  // Necesario para que los toques en la notificación lleguen al reproductor.
  // Debe completarse ANTES de crear cualquier AudioPlayer: si el plugin no
  // terminó de inicializar, el jugador reproduce audio pero el motor nunca
  // monta el servicio de notificación (era la causa de «suena sin aviso»).
  // Handler propio con la MediaSession (carátula, barra de progreso, repetir
  // y me gusta). Solo en móvil: en escritorio la reproducción usa gst-play.
  // Debe completarse ANTES de crear el AudioPlayer, por eso va aquí.
  AuraAudioHandler? audioHandler;
  if (Platform.isAndroid || Platform.isIOS) {
    audioHandler = await AudioService.init(
      builder: () => AuraAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.yoner.auramusic.aura_music.playback',
        androidNotificationChannelName: 'Aura Music — Reproducción',
        androidNotificationIcon: 'mipmap/ic_launcher',
        // Sin deslizar mientras suena (igual que YouTube Music). En pausa sí se
        // puede cerrar: audio_service exige stopForegroundOnPause con ongoing.
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }
  debugPrint('aura: AudioService.init completado');

  // Set immersive dark status bar and navigation bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF030303),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = MusicStorageService();
  final playerService = PlayerService(audioHandler);

  if (Platform.isLinux) {
    // Widget de medios del escritorio (MPRIS): permite ver y controlar la
    // reproducción en segundo plano, como la notificación de Android.
    unawaited(
      LinuxMprisService(playerService).start().catchError(
        (Object e) => debugPrint('aura: MPRIS no disponible: $e'),
      ),
    );
  }
  final youtubeService = YoutubeDownloadService();

  debugPrint('aura: lanzando runApp');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: storageService),
        ChangeNotifierProvider.value(value: playerService),
        ChangeNotifierProvider.value(value: youtubeService),
      ],
      child: const AuraMusicApp(),
    ),
  );

  // La biblioteca (permisos + escaneo) se inicializa DESPUÉS del primer
  // frame: pedir permisos o escanear antes de runApp congela el arranque en
  // MIUI/HyperOS (el diálogo de permiso queda pegado como activity invisible
  // y la pantalla se ve negra). La UI pinta el tema oscuro de inmediato y la
  // biblioteca aparece cuando el escaneo termina.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('aura: inicializando biblioteca (post-frame)');
    storageService.initialize().then((_) {
      debugPrint('aura: biblioteca lista');
    }).catchError((Object e) {
      debugPrint('aura: error inicializando biblioteca: $e');
    });
  });
}

class AuraMusicApp extends StatelessWidget {
  const AuraMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('aura: AuraMusicApp.build ejecutandose');
    return MaterialApp(
      title: 'Aura Music',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
