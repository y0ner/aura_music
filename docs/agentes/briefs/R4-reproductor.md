# Brief R4 · Reproductor completo y mini reproductor

- **Rama:** `feat/rediseno-reproductor` · **Worktree:** `~/Desktop/Projects/worktrees/aura-rediseno-reproductor`
- **Lee primero:** `AGENTS.md` (reglas obligatorias), `docs/rediseno/README.md` y el prototipo `docs/rediseno/prototipo/Reproductor.dc.html`. En `Main.dc.html` está el mini reproductor: es el `<a>` con `bottom: 72px`.
- **Objetivo:** que el reproductor completo y el mini reproductor se vean como el prototipo: fondo tomado del color de la carátula, carátula grande, botones en píldora, barra de progreso con el acento y controles con el botón de reproducir blanco, sin perder ninguna función que ya existe.

## Contexto (por qué)

- `lib/widgets/fullscreen_player.dart` (~1050 líneas):
  - Arriba, la píldora `Canción | Letra`.
  - Al centro, la carátula, el título y los controles. Shuffle y repeat están en la línea ~420.
  - Abajo, 4 pestañas (línea ~470): «A continuación», «Letra», «Comentarios» y «Similares». **«Comentarios» y «Similares» solo muestran texto de relleno** («Comentarios no disponibles sin conexión.», «Reproduciendo desde tu carpeta local.»): se eliminan.
  - El menú `more_vert_rounded` (línea ~900) abre las opciones (Me gusta, Reproducir a continuación, Guardar en una playlist, Compartir, Agregar a la fila, Detalles de la pista, Descartar fila). **Esa lógica se conserva.**
  - Hoy usa colores sueltos y `AppTheme.redAccent`.
- `lib/widgets/mini_player.dart`: alto 62, progreso blanco de 2 px y colores sueltos.
- `lib/widgets/lyrics_view.dart`: la vista de letra sincronizada. Aquí solo se cambian estilos (colores y tipografía desde `AppTheme`).
- `test/lyrics_view_test.dart` prueba el reproductor y espera:
  - `find.text('Canción')` una vez y `find.text('Letra')` **dos veces** (píldora + pestaña inferior);
  - el icono `Icons.more_vert_rounded`, y en las opciones `'Guardar en una\nplaylist'`, `'Agregar a la fila'` e `Icons.playlist_play`;
  - al tocar `find.text('Letra').first`, la vista de letra con `'Compartir'` (una sola vez), el tooltip `'Cerrar letra'` y los versos.
  
  Conserva esos textos, iconos y tooltips. **No** pongas otro botón con el texto «Compartir» a la vista mientras se ve la letra.
- Para el color de fondo está la dependencia `image` (`~/.pub-cache/hosted/pub.dev/image-4.13.1/lib/`). El usuario y el artista vienen de `Song` (`title`, `artist`, `hasKnownArtist`, `category`, `artworkBytes`).
- El Me gusta llama a `context.read<MusicStorageService>().toggleFavorite(song)`, como hoy. Otro agente hace que persista: aquí no se cambia esa API.

## Archivos permitidos

- `lib/widgets/fullscreen_player.dart`
- `lib/widgets/mini_player.dart`
- `lib/widgets/lyrics_view.dart` (solo estilos)
- `lib/utils/artwork_palette.dart` (**nuevo**)
- `test/artwork_palette_test.dart` (**nuevo**)
- `test/mini_player_test.dart` (**nuevo**)
- `test/lyrics_view_test.dart` (solo si un cambio de diseño **obliga** a ajustar una búsqueda; explícalo en tu respuesta)

## Qué hacer

1. **`lib/utils/artwork_palette.dart`**: `Future<Color> artworkBackgroundColor(Uint8List? bytes)`.
   - Decodifica la imagen en `Isolate.run`, la reduce a 24 × 24 y promedia los píxeles, ponderando por saturación (los grises pesan poco).
   - Convierte el resultado a HSL y ajusta la luminosidad a 0,22–0,30 y la saturación a un máximo de 0,6, para que el texto blanco siempre se lea.
   - Sin bytes o si falla la decodificación, devuelve `AppTheme.surfaceHigh` (con `debugPrint` del error).
   - Guarda en caché los últimos 32 resultados, con clave `Object.hash(longitud, primeros 64 bytes)`.
2. **Reproductor completo** (seguir `Reproductor.dc.html`):
   - **Fondo:** degradado vertical del color de `artworkBackgroundColor` (arriba) a `AppTheme.bg` (al 100 %), animado con `AnimatedContainer` o `TweenAnimationBuilder` (300 ms) al cambiar de canción.
   - **Barra superior:** chevron hacia abajo (tooltip «Minimizar», llama `onCollapse`), la píldora `Canción | Letra` (fondo negro al 35 %, segmento activo blanco al 20 %, alto 36) y `more_vert_rounded`.
   - **Carátula:** cuadrada, ancho de pantalla − 48, radio `AppTheme.radiusArtwork`, sombra suave. Sin carátula, un cuadro `surfaceHigh` con el icono de nota.
   - **Título y artista:** título con `AppTheme.titleLarge` (una línea, con elipsis); artista con `itemTitle` en blanco al 75 %. Si `!song.hasKnownArtist`, muestra `song.category`.
   - **Píldoras** (alto 40, radio 20, fondo blanco al 12 %):
     - «Me gusta», con `thumb_up_outlined`/`thumb_up` según `song.isFavorite`, que llama `toggleFavorite`;
     - «Guardar», que abre el mismo flujo que «Guardar en una playlist» de las opciones.
   - **Progreso:** `Slider` con los colores del tema (pista activa `AppTheme.accent`), y debajo los tiempos con `AppTheme.caption`.
   - **Controles:**
     - aleatorio (48), anterior (56), reproducir/pausar en un **círculo blanco de 76 con icono negro**, siguiente (56) y repetir (48);
     - aleatorio y repetir activos se pintan en `AppTheme.accent`, inactivos en blanco al 60 %, y conservan `repeat_one`;
     - cada botón de solo icono lleva `tooltip`.
   - **Pestañas inferiores:** solo «A continuación» y «Letra», con su comportamiento actual (fila y hoja de letra). Elimina «Comentarios», «Similares» y sus textos de relleno.
   - Reemplaza cada color, tamaño de letra y radio suelto por tokens de `AppTheme`.
3. **Mini reproductor** (mismo API: `MiniPlayer({required onExpand})`):
   - Alto `AppTheme.miniPlayerHeight` (64), fondo `surfaceHigh`.
   - Línea de progreso de 2 px arriba: pista `outline`, avance `accent`.
   - Miniatura de 44 con radio 4, título `itemTitle` y subtítulo `itemSubtitle`: artista, o la duración si `!hasKnownArtist`.
   - Reproducir/pausar y siguiente en áreas de 48, con tooltips «Reproducir»/«Pausar» y «Siguiente».
   - Conserva lo que hace hoy (insignia E, tocar para expandir).
4. **`test/mini_player_test.dart`**: con un `PlayerService` y una canción cargada como en `test/lyrics_view_test.dart` (`linuxProcessStarter` falso):
   - muestra el título y los tooltips;
   - con una canción de artista desconocido, **no** aparece «Artista desconocido» y sí la duración.
5. **`test/artwork_palette_test.dart`**:
   - una imagen roja sólida da un color con tono ≈ 0° y luminosidad entre 0,22 y 0,30;
   - `null` y bytes corruptos dan `AppTheme.surfaceHigh`.

## Criterios de aceptación

- [ ] `grep -n "Comentarios\|Similares\|sin conexión" lib/widgets/fullscreen_player.dart` no devuelve nada.
- [ ] `grep -n "Color(0x\|fontSize:" lib/widgets/fullscreen_player.dart lib/widgets/mini_player.dart` no devuelve nada (todo desde `AppTheme`).
- [ ] `grep -rn "Artista desconocido" lib/widgets/` no devuelve nada.
- [ ] Las expectativas de `test/lyrics_view_test.dart` (líneas 88–110) siguen siendo ciertas con el diseño nuevo.
- [ ] Las pruebas nuevas existen y cubren los pasos 4 y 5.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el entorno real (lo hace el humano)

Reproducir «Coronamos»: el fondo del reproductor toma un tono dorado oscuro y al pasar a la siguiente canción cambia con suavidad. Me gusta, Guardar, aleatorio, repetir, letra y fila funcionan como antes. El mini reproductor muestra la barra rosa de progreso.
