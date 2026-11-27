# Brief L1 · README profesional (inglés + español), CONTRIBUTING, CHANGELOG y textos de tienda

- **Rama:** `docs/readme` · **Worktree:** `~/Desktop/Projects/worktrees/aura-docs-readme` · **Base:** `release/v1.0.0`
- **Lee primero:** `AGENTS.md`, `docs/rediseno/README.md` (guía visual y logo), `run.sh`, `pubspec.yaml`, `lib/` (para comprobar cada función que menciones).
- **Objetivo:** que el GitHub de Aura Music quede al nivel de proyectos como NewPipe: README claro, visual y completo, en inglés (`README.md`) y español (`README.es.md`).
- **Ejemplo terminado para imitar la calidad (no copiar el contenido):** https://github.com/y0ner/folio (README.md, README.es.md, CONTRIBUTING.md, CHANGELOG.md, fastlane/). No tienes red: guíate por esta descripción.

## Datos del proyecto (el agente NO inventa nada fuera de esto o del código)

- **Nombre / paquete / versión:** Aura Music · `com.yoner.auramusic.aura_music` · **1.0.0** (`pubspec.yaml`, versionCode 1).
- **Repo:** `https://github.com/y0ner/aura_music` · **Licencia:** GPLv3 (archivo `LICENSE`).
- **Qué es:** reproductor de música offline para Android con una interfaz inspirada en YouTube Music. Cada subcarpeta de `Music/AuraMusic` es una playlist, y la música se puede añadir pegando enlaces de YouTube.
- **Funciones verificadas en un celular real** (Xiaomi, Android 16):
  - **Biblioteca por carpetas:** `Music/AuraMusic` en Android (`~/Music/AuraMusic` en Linux). Cada subcarpeta es una playlist, con emojis en el nombre. Se puede crear una playlist (carpeta) desde la app, elegir otra carpeta raíz y volver a escanear.
  - **Inicio:**
    - cuadrícula 3 × 3 de accesos rápidos: «Música que te gustó», playlists, «Recién añadidas», «Más escuchadas» y mixes por artista;
    - «Escuchado hace poco»;
    - chips por playlist.
  - **Buscar:** búsqueda en canciones, artistas, carpetas y playlists sin distinguir tildes ni mayúsculas, con búsquedas recientes guardadas y accesos a las listas automáticas.
  - **Biblioteca:** playlists en lista o cuadrícula, orden por nombre o por número de canciones, y vista «Canciones» con filtros por carpeta y orden por título, artista o duración.
  - **Playlist:** collage 2 × 2 de carátulas a todo el ancho, reproducir, aleatorio, añadir a la fila y eliminar la carpeta.
  - **«Música que te gustó»:** los Me gusta se guardan en el dispositivo y sobreviven al reinicio; filtros por carpeta.
  - **Reproductor:**
    - fondo tomado del color de la carátula;
    - Me gusta y Guardar en playlist;
    - aleatorio, repetir y repetir una;
    - barra de progreso para adelantar;
    - fila «A continuación» (reproducir a continuación, agregar a la fila, quitar);
    - vista de letra.
  - **Letras sincronizadas:**
    - lee los `.lrc` junto al audio;
    - si no hay, las busca en LRCLIB (lrclib.net, sin cuenta), prefiere la versión sincronizada y la guarda en caché para usarla sin conexión;
    - resalta el verso actual, y tocar un verso lleva a ese punto.
  - **Añadir desde YouTube:**
    - se pega el enlace de una canción o de una playlist pública o no listada;
    - se analiza, se elige la carpeta destino y se descarga el audio (`.m4a`) a la biblioteca;
    - hay cola de descargas con progreso, cancelar, reintentar las fallidas y limpiar las terminadas;
    - las carátulas se guardan sin las franjas negras de YouTube y la letra se precarga.
  - **Artista desde el nombre del archivo:** «Artista - Título (Official Video) ft. X» → artista «Artista, X» y título «Título», cuando el archivo no trae etiquetas.
  - **Reproducción en segundo plano** con notificación multimedia (MediaSession: carátula, progreso, repetir y Me gusta). En Linux de escritorio, control MPRIS (widget de medios del escritorio).
  - **Privacidad:** sin cuenta, sin anuncios, sin rastreo ni analíticas. Solo usa la red para descargar desde YouTube (cuando el usuario pega un enlace) y para pedir letras a LRCLIB.
  - **Logo propio «A·Play»:** icono adaptativo y temático de Android 13+, e icono de notificación.
- **Requisitos:** Android 7.0+ (minSdk 24) · **Tamaño de la APK:** ~22 MB (arm64). También compila y corre en Linux de escritorio (reproducción con GStreamer `gst-play-1.0`).
- **Permisos y por qué:**
  - `INTERNET`: descargas de YouTube y letras de LRCLIB.
  - `READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE`: leer la música.
  - `WRITE_EXTERNAL_STORAGE`: guardar descargas en Android antiguo.
  - `MANAGE_EXTERNAL_STORAGE`: declarado para carpetas fuera de Música; **no** se pide automáticamente.
  - `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` / `WAKE_LOCK`: seguir sonando en segundo plano.
  - `POST_NOTIFICATIONS`: notificación de reproducción.
- **Stack** (versiones reales de `pubspec.lock`):
  - Flutter 3.47 / Dart 3.13;
  - `just_audio` 0.10.6, `audio_service` 0.18.19, `youtube_explode_dart` 3.1.0, `audio_metadata_reader` 1.8.0, `provider` 6.1.5, `http` 1.6.0, `image` 4.x, `file_picker` 13.1.0, `permission_handler` 13.0.2, `path_provider` 2.1.6, `dbus` 0.7.15 (MPRIS en Linux);
  - fuente Poppins SemiBold (OFL, `assets/fonts/OFL-Poppins.txt`).

  Comprueba cada número en `pubspec.lock` antes de escribirlo; si no coincide, usa el del lock.
- **Arquitectura:**
  - servicios con `ChangeNotifier` + `provider`: `MusicStorageService` (biblioteca, escaneo en un isolate, listas derivadas en caché), `PlayerService` (cola; la posición va por un `ValueListenable` aparte para no redibujar pantallas), `YoutubeDownloadService` (cola FIFO), `LyricsService` + `LrclibFetcher`, `LibraryStateStore` (favoritos, historial y búsquedas en JSON), `AuraAudioHandler` (MediaSession);
  - tokens de diseño en `lib/theme/app_theme.dart`.
- **Firma de la APK:** SHA-256 `A7:79:B5:5E:1E:05:3B:A6:13:A0:A2:24:A6:18:EF:61:9D:BD:A0:62:76:26:5B:3A:CB:88:78:54:0E:F4:39:D8` (certificado `CN=Aura Music, OU=y0ner, C=CO`).
- **Descarga:** `https://github.com/y0ner/aura_music/releases/latest` (archivo `aura-music-v1.0.0-arm64.apk`; enlace directo `https://github.com/y0ner/aura_music/releases/latest/download/aura-music-v1.0.0-arm64.apk`).
- **Sitio web:** `https://aura-musica.vercel.app`.
- **Compilar** (`run.sh`): `./run.sh linux`, `./run.sh android`, `./run.sh build-apk`, `./run.sh test`, `./run.sh analyze`. Alternativa con Flutter puro: `flutter pub get` y `flutter build apk --release --target-platform android-arm64`.
- **Cómo se hizo:**
  - el diseño salió de un prototipo navegable;
  - un agente jefe (Claude Code) escribió briefs cerrados y repartió el trabajo en 7 tareas, entre ellas datos, logo, reproductor, biblioteca, «Añadir» y navegación, entre agentes Gemini (CLI Antigravity `agy`), cada uno en su worktree y rama;
  - el jefe revisó cada diff, corrió análisis y pruebas (128 pruebas) y fusionó por PR;
  - las pruebas se hicieron en un celular real por adb;
  - una pasada de rendimiento bajó la CPU con música sonando de 86 % a ~13–24 %.
- **Aviso:** Aura no está afiliada a YouTube ni a Google. Descargar contenido de YouTube puede ir contra sus Términos de servicio: el usuario es responsable de descargar solo contenido que tenga derecho a guardar. Inclúyelo, sobrio, en «Download & installation» o en una sección «Disclaimer».

## Imágenes (rutas fijas; el jefe las genera en paralelo)

- `fastlane/metadata/android/en-US/images/icon.png` (512 px) y `featureGraphic.png` (1024 × 500).
- `fastlane/metadata/android/en-US/images/phoneScreenshots/1.png … 8.png`, en este orden:
  1. Inicio
  2. Reproductor
  3. Biblioteca
  4. Playlist
  5. Música que te gustó
  6. Buscar
  7. Añadir desde YouTube
  8. Canciones con filtros

Úsalas en el README con esas rutas, aunque aún no existan en tu worktree.

## Archivos permitidos

- `README.md` (se reescribe entero: el actual dice «100 % idéntica a YouTube Music», tiene rutas personales y capturas que no existen)
- `README.es.md` (**nuevo**), `CONTRIBUTING.md` (**nuevo**), `CHANGELOG.md` (**nuevo**, formato Keep a Changelog)
- `fastlane/metadata/android/{en-US,es-ES}/{title.txt,short_description.txt,full_description.txt,changelogs/1.txt}` (**nuevos**)

## Qué hacer

1. **README** (estructura tipo NewPipe, estilo propio y sobrio):
   - **Encabezado** HTML centrado: ícono (ancho 120), `<h2>` «Aura Music», `<h4>` frase corta.
   - **Botones e insignias:**
     - botón shields.io grande «Download APK» (`style=for-the-badge`) a releases/latest;
     - insignias de release (`github/v/release/y0ner/aura_music`), licencia GPLv3, Android 7.0+ y Flutter;
     - solo atributos reales: «offline», «no ads», «no tracking»;
     - **nada** de F-Droid, Weblate, chat ni servicios que no se usan.
   - **Navegación:**
     - selector `English · [Español](README.es.md)`;
     - barra de anclas separada por `&bull;` (Screenshots · Description · Features · Download · Privacy · Building · Tech stack · Contributing · License);
     - segunda barra: Website · Releases · Changelog.
   - Línea visible: «Current version: **1.0.0** — [release notes](CHANGELOG.md)».
   - **Secciones, en este orden:**
     - `## Screenshots`: gráfico destacado y capturas de ancho 200 en filas de 4;
     - `## Description` y `## Features` agrupadas (Library · Home & search · Player & lyrics · YouTube downloads · Background playback);
     - `## Download & installation`, con `### APK signing certificate` (huella en bloque de código) y el aviso de YouTube;
     - `## Privacy`, `## Building from source`, `## Tech stack & architecture`;
     - `## How it was built` (con los datos de arriba), `## Contributing`;
     - `## Third-party` (paquetes, LRCLIB, Poppins OFL), `## License`.
   - **Nada de rutas `/home/...`.**
2. **`README.es.md`:** misma estructura, traducción natural.
3. **Resto de archivos:**
   - `CONTRIBUTING.md`: cómo compilar, `./run.sh analyze` y `./run.sh test` antes del PR, estilo (tokens de `AppTheme`, sin colores sueltos, textos de la interfaz en español) y cómo reportar errores;
   - `CHANGELOG.md`: `## [1.0.0] - 2026-11-26` con Added (todas las funciones) y Fixed. En Fixed van: las franjas negras de las carátulas; los Me gusta que se perdían al reiniciar; «Artista desconocido»; el rendimiento al reproducir; las canciones repetidas en las listas automáticas;
   - textos fastlane: `title.txt` «Aura Music»; `short_description` ≤ 80 caracteres; `full_description` ≤ 4000; `changelogs/1.txt` ≤ 500. En en-US y es-ES.
4. Verifica que las anclas coincidan con los encabezados reales (GitHub: minúsculas, espacios → `-`, quita `&`).

## Criterios de aceptación

- [ ] `git diff --stat release/v1.0.0` solo muestra archivos permitidos.
- [ ] `wc -m fastlane/metadata/android/*/short_description.txt` ≤ 80; `full_description.txt` ≤ 4000; `changelogs/1.txt` ≤ 500.
- [ ] Ningún dato inventado: cada función y número sale de este brief o del código.
- [ ] `grep -rn "TODO\|lorem\|example.com\|/home/\|idéntica\|identical" README*.md CONTRIBUTING.md CHANGELOG.md fastlane/` sin resultados.
