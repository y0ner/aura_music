# Brief B1 · Carátulas de las canciones descargadas en Android

- **Rama:** `fix/caratulas-android` · **Worktree:** `../worktrees/aura-caratulas`
- **Objetivo:** que las canciones descargadas de YouTube muestren su carátula en Android (y sigan mostrándola en Linux).

## Contexto (por qué). Diagnóstico ya hecho por el jefe en el celular real

Android 10+ (scoped storage) **prohíbe crear `.jpg` dentro de `/storage/emulated/0/Music/`**.
Solo deja crear archivos de audio (`.m4a`, `.wav`). Log real del teléfono:

```
Carátula opcional no disponible: PathAccessException: Cannot open file,
path = '/storage/emulated/0/Music/AuraMusic/#1 Urbano/... [SqAGWRpccm0].jpg'
(OS Error: Operation not permitted, errno = 1)
```

- `lib/services/youtube_service.dart`, `_artwork(String base, String url)` (~línea 563), escribe
  `'$base.jpg'` junto al audio. Se llama desde `startDownload` (~línea 441) como
  `await _artwork(base, track.thumbnailUrl);` cuando `ok` es true. `ok` también es
  true si el audio ya existía, así que una nueva descarga de la playlist pasa por cada pista.
- `lib/services/storage_service.dart`:
  - `_parseAudioFile` (~línea 293): usa la imagen embebida y, si no hay
    (`if (artwork == null)`, ~línea 335), busca el sidecar `<base>.jpg`.
  - `deleteSongFile` (~línea 171): borra los sidecars `.jpg/.lrc`.
  - `scanLibrary` (~línea 201): recorre las carpetas.
- Los archivos descargados se llaman `Título [<videoId de 11 chars>].m4a` (o `.webm`).
- `PlaylistTrack.thumbnailUrl` (`lib/services/playlist_fetcher.dart`) ya existe:
  `https://i.ytimg.com/vi/$videoId/hqdefault.jpg`.
- `path_provider` ya está en `pubspec.yaml` (API: `~/.pub-cache/hosted/pub.dev/path_provider-2.1.6/lib/path_provider.dart`).

## Diseño decidido (no lo cambies)

Las carátulas se guardan en un **directorio privado de la app**:
`<getApplicationSupportDirectory()>/covers/<videoId>.jpg`. Se asocian al audio por el
`videoId` que lleva el nombre del archivo.

## Archivos permitidos

- `lib/services/artwork_store.dart` (**nuevo**)
- `lib/services/youtube_service.dart`: **solo** el constructor y el método `_artwork` con su llamada. No toques `analyzeUrl`, `clearPreview` ni los getters (otro agente trabaja ahí en paralelo).
- `lib/services/storage_service.dart`
- `test/artwork_store_test.dart` (**nuevo**)
- `test/youtube_service_test.dart` (solo el `setUp` y una prueba nueva al final)

## Qué hacer

1. **`lib/services/artwork_store.dart`** con:
   - `typedef DirectoryProvider = Future<Directory> Function();`
   - `Future<Directory> defaultArtworkDirectory() async => Directory('${(await getApplicationSupportDirectory()).path}/covers');`
   - `String? videoIdFromPath(String path)`: devuelve el id del patrón `\[([A-Za-z0-9_-]{11})\]\.[A-Za-z0-9]+$` aplicado al nombre del archivo, o `null`.
   - `File artworkFileFor(Directory dir, String videoId) => File('${dir.path}/$videoId.jpg');`
2. **`YoutubeDownloadService`**: agrega el parámetro opcional `DirectoryProvider? artworkDirectory`
   (por defecto `defaultArtworkDirectory`), que se resuelve **solo al usarlo**, nunca en el
   constructor. Cambia `_artwork` a `_artwork(String videoId, String url)`:
   - resuelve el directorio, lo crea con `recursive: true` y calcula el archivo con `artworkFileFor`;
   - **si el archivo ya existe y no está vacío, retorna sin red**;
   - descarga y escribe ahí. Mantén el `try/catch` con `debugPrint` (la carátula es opcional).
   - Llámalo como `await _artwork(track.videoId, track.thumbnailUrl);`.

   Así, volver a descargar una playlist ya bajada rellena las carátulas que faltan sin bajar otra vez el audio.
3. **`MusicStorageService`**: agrega el constructor `MusicStorageService({DirectoryProvider? artworkDirectory})`
   (por defecto `defaultArtworkDirectory`).
   - En `scanLibrary`, resuelve el directorio **una vez** por escaneo (con `try/catch`: si falla, queda `null`) y pásalo a `_scanSongsInDirectory`/`_parseAudioFile`.
   - En `_parseAudioFile`, si después de la imagen embebida y del sidecar `<base>.jpg` todavía no hay carátula, y el nombre tiene `videoId`, lee `artworkFileFor(dir, id)` si existe.
   - En `deleteSongFile`, si el nombre tiene `videoId`, borra también la carátula privada (resuelve el directorio con `try/catch`).
   - Las subclases existentes (`FakeStorage` en las pruebas, `MusicStorageService()` en `lib/main.dart` y en `test/widget_test.dart`) deben seguir compilando sin cambios: el parámetro es opcional.
4. **Pruebas**:
   - `test/artwork_store_test.dart`:
     - `videoIdFromPath` con un nombre con corchetes, otro sin id y otro con espacios y emojis.
     - Una prueba de `MusicStorageService(artworkDirectory: () async => tmpCovers)`. Crea en una carpeta temporal `Música/Mi lista/Canción [AAAAAAAAAAA].m4a` (bytes cualquiera) y `tmpCovers/AAAAAAAAAAA.jpg` con unos bytes. Llama `setCustomRootDirectory(root.path)` y verifica que esa canción tenga `artworkBytes` igual a esos bytes.
     - Otra prueba: `deleteSongFile` borra también `tmpCovers/AAAAAAAAAAA.jpg`.
   - `test/youtube_service_test.dart`: inyecta en el `setUp` un `artworkDirectory` temporal y bórralo en `tearDown`. Agrega una prueba que verifique que, tras una descarga exitosa, **no** hay ningún `.jpg` en la carpeta de música. La red de la carátula fallará en las pruebas, y eso está bien: es opcional.

## Criterios de aceptación

- [ ] `grep -n "\$base.jpg" lib/services/youtube_service.dart` no devuelve nada.
- [ ] Las pruebas nuevas existen. Ninguna prueba previa se borró ni se relajó.
- [ ] `flutter analyze --no-pub` sin problemas.
- [ ] Sin `catch (_) {}` vacíos nuevos (usa `debugPrint`) y sin `TODO`.
- [ ] Diff limitado a los archivos permitidos, sin reformatear código ajeno.

## Qué se probará en el entorno real

En el Xiaomi: volver a descargar "#1 Urbano 😏🔥💯" (ya bajada). Las 47 canciones deben
mostrar carátula en Biblioteca y en el reproductor, sin volver a bajar el audio.
