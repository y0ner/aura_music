import 'package:flutter/material.dart';

/// Sistema de diseño de Aura (rediseño de noviembre de 2026).
///
/// Referencia visual: `docs/rediseno/README.md` y los prototipos de
/// `docs/rediseno/prototipo/`. Ninguna pantalla debe escribir colores,
/// tamaños de letra ni radios sueltos: todo sale de aquí.
class AppTheme {
  AppTheme._();

  // ───────────────────────────── Colores base ─────────────────────────────

  /// Fondo OLED de todas las pantallas.
  static const Color bg = Color(0xFF030303);

  /// Barra de navegación inferior.
  static const Color navBar = Color(0xFF0F0F0F);

  /// Tarjetas de categorías y bloques de Añadir.
  static const Color surface = Color(0xFF181818);

  /// Mini reproductor, campos de texto, botones circulares y hojas inferiores.
  static const Color surfaceHigh = Color(0xFF1F1F1F);

  /// Chips sin seleccionar.
  static const Color chip = Color(0xFF272727);

  /// Bordes finos y pistas de progreso vacías.
  static const Color outline = Color(0xFF333333);

  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Subtítulos: artista, número de canciones, duración (8,9:1 sobre [bg]).
  static const Color textSecondary = Color(0xFFAAAAAA);

  /// Marcadores de posición y textos deshabilitados (5,9:1 sobre [bg]).
  static const Color textMuted = Color(0xFF8C8C8C);

  /// Acento de la interfaz (10 %): progreso, «sonando ahora», selección.
  static const Color accent = Color(0xFFFF3D7F);

  /// Errores y acciones destructivas.
  static const Color danger = Color(0xFFFF5A5A);

  // Colores de marca: solo en el logo y en «Música que te gustó».
  static const Color brandEmber = Color(0xFFFF8A3D);
  static const Color brandRose = Color(0xFFFF3D7F);
  static const Color brandViolet = Color(0xFF8B5CFF);

  /// Fondo del icono de la app.
  static const Color brandInk = Color(0xFF0E0B14);

  /// Degradado de marca (brasa → rosa → violeta, de arriba-izquierda a
  /// abajo-derecha).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandEmber, brandRose, brandViolet],
    stops: [0.0, 0.48, 1.0],
  );

  // Alias de los nombres anteriores (para no romper código existente).
  static const Color bgDark = bg;
  static const Color surfaceDark = Color(0xFF141414);
  static const Color cardDark = surfaceHigh;
  static const Color chipBackground = chip;
  static const Color chipActiveBackground = textPrimary;
  static const Color redAccent = accent;
  static const Color dividerColor = Color(0xFF2A2A2A);
  static const LinearGradient likedSongsGradient = brandGradient;

  // ───────────────────────────── Tipografía ─────────────────────────────
  // Máximo cuatro tamaños de texto en una pantalla: 24, 16, 14 y 12.
  // Poppins 600 solo para títulos y logotipo; Roboto para todo lo demás.

  static const String displayFont = 'Poppins';

  /// Título de pantalla o de sección («Biblioteca», «Escuchado hace poco»).
  static const TextStyle titleLarge = TextStyle(
    fontFamily: displayFont,
    fontWeight: FontWeight.w600,
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.3,
    color: textPrimary,
  );

  /// Logotipo «Aura» junto al icono en la barra superior.
  static const TextStyle wordmark = TextStyle(
    fontFamily: displayFont,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    letterSpacing: -0.3,
    color: textPrimary,
  );

  /// Título de fila (canción, playlist) y textos de botones grandes.
  static const TextStyle itemTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  /// Subtítulo de fila: artista, «Playlist · 12 canciones».
  static const TextStyle itemSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  /// Chips, botones y etiquetas de tarjetas.
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  /// Etiquetas de la barra inferior, tiempos del reproductor.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  // ───────────────────────────── Medidas ─────────────────────────────
  // Rejilla de 4/8 px.

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  /// Margen lateral de todas las pantallas.
  static const double pagePadding = 16;

  /// Área táctil mínima (Android: 48 dp).
  static const double minTouch = 48;

  static const double radiusSmall = 4; // miniaturas de canción
  static const double radiusMedium = 8; // chips y tarjetas de la cuadrícula
  static const double radiusLarge = 16; // tarjetas y bloques
  static const double radiusArtwork = 12; // carátula del reproductor

  static const double chipHeight = 40;
  static const double songThumb = 48;
  static const double playlistThumb = 56;
  static const double miniPlayerHeight = 64;
  static const double navBarHeight = 72;

  /// Botón de reproducir blanco de las cabeceras de playlist.
  static const double playButtonSize = 64;

  /// Botón de reproducir del reproductor completo.
  static const double playerPlayButtonSize = 76;

  // ───────────────────────────── Tema ─────────────────────────────

  static ThemeData get darkTheme {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: surfaceHigh,
      dividerColor: dividerColor,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: textPrimary,
        onPrimary: bg,
        secondary: accent,
        onSecondary: textPrimary,
        surface: bg,
        onSurface: textPrimary,
        error: danger,
      ),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: titleLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceHigh,
        modalBackgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBar,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: navBarHeight,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => caption.copyWith(
            color: textPrimary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: textPrimary, size: 24),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: outline,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: Color(0x40FFFFFF),
        thumbColor: textPrimary,
        overlayColor: Color(0x29FFFFFF),
        trackHeight: 4,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: Color(0x66FF3D7F),
        selectionHandleColor: accent,
      ),
    );
  }
}
