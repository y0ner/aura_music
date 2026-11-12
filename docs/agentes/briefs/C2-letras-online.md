# Brief C2 · Letras sincronizadas descargadas de internet (LRCLIB)

- **Rama:** `feat/letras-online` · **Worktree:** `../worktrees/aura-letras-online`
- **Objetivo:** que la vista "Letra" muestre la letra de cualquier canción. Si no hay `.lrc` local, se busca en LRCLIB (gratis, sin API key), se prefiere la **sincronizada** y se guarda en caché privada para que luego funcione sin conexión.

## Contexto (por qué)

- La app **ya** sabe mostrar letras sincronizadas: `lib/models/lyrics_model.dart` (`parseLrc`,
  `activeIndexAt`) y `lib/widgets/lyrics_view.dart` (resalta la línea activa con la posición del
  reproductor y hace auto-scroll). Pero `lib/services/lyrics_service.dart` solo lee `.lrc` junto al
  audio (`Foo.lrc`, `Foo_private.lrc` o una búsqueda tolerante en la carpeta). Las canciones
  descargadas de YouTube no traen `.lrc`, así que la vista dice "Letra no disponible".
- En Android no se pueden crear `.lrc` dentro de `Music/` (scoped storage: solo audio). Como las
  carátulas, las letras van a un directorio **privado** de la app.
- Ya existe `lib/services/artwork_store.dart` con `DirectoryProvider` y
  `videoIdFromPath(path)`, que saca el id de 11 caracteres de `Título [id].m4a`. Reutilízalos.
- `Song` (`lib/models/song_model.dart`) trae `title` (ya sin el `[id]`), `artist` (a veces
  `'Artista desconocido'`), `duration` y `filePath`.
- `http` ya es dependencia. Para pruebas usa `MockClient` de `package:http/testing.dart`
  (`~/.pub-cache/hosted/pub.dev/http-1.6.0/lib/testing.dart`).

**API de LRCLIB (comprobada por el jefe):**
`GET https://lrclib.net/api/search?q=<texto>` devuelve una lista JSON de objetos con
`trackName`, `artistName`, `duration` (segundos, double), `syncedLyrics` (String LRC con
`[mm:ss.xx]` o null) y `plainLyrics` (String o null). Envía el header
`User-Agent: AuraMusic/1.0`; no envíes ningún dato del usuario. Ejemplo real:
`q=FloyyMenor Banshee` → `FloyyMenor - BANSHEE ft J Balvin (188.0s)` con `syncedLyrics`.

## Archivos permitidos

- `lib/services/lyrics_fetcher.dart` (**nuevo**)
- `lib/services/lyrics_service.dart`
- `lib/widgets/lyrics_view.dart` (solo los textos de estado: cargando y no disponible)
- `lib/services/storage_service.dart` (solo `deleteSongFile`)
- `test/lyrics_fetcher_test.dart` (**nuevo**)
- `test/lyrics_service_test.dart`
- `test/lyrics_view_test.dart` (solo si hace falta inyectar un fetcher falso)

**No toques** `lib/services/youtube_service.dart` ni `lib/screens/youtube_screen.dart`: otro agente
trabaja ahí. El jefe conectará después la precarga al descargar.

## Qué hacer

1. **`lib/services/lyrics_fetcher.dart`**:
   - `abstract class LyricsFetcher { Future<String?> fetch({required String title, String? artist, Duration? duration}); }`.
     Devuelve el texto LRC (o la letra plana) o `null` si **no existe**. Lanza
     `LyricsFetchException` si hubo un **error de red o HTTP** (≠ 200), para no confundir
     "sin conexión" con "no existe".
   - `class LrclibFetcher implements LyricsFetcher`, con constructor `({http.Client? client})`
     y timeout de 10 s:
     - **Consulta:** si `artist` es null o `'Artista desconocido'` y el título tiene `' - '`,
       separa `artista - título` por el primer `' - '`. Limpia el título: quita los grupos
       `(...)`/`[...]` que contengan (sin distinguir mayúsculas) `video`, `official`, `oficial`,
       `audio`, `visualizer`, `lyric`, `letra`, `clip`, `hd` o `4k`. **Conserva** `(Remix)` y
       `(feat. X)`. Quita también un sufijo ` ft ...`/` feat. ...` fuera de paréntesis, solo para
       la consulta. `q = '$artista $titulo'` con espacios colapsados.
     - **Elección:** si `duration` es conocida, solo valen resultados con
       `|duration - resultado.duration| <= 3 s`. Entre ellos, primero los que tienen
       `syncedLyrics` no vacío y luego el de duración más cercana. Si ninguno cae en la
       tolerancia, devuelve `null` (mejor sin letra que con la equivocada). Si `duration` es null,
       toma el primero con `syncedLyrics`, y si no hay, el primero con `plainLyrics`.
       Devuelve `syncedLyrics ?? plainLyrics`.
2. **`LyricsService`**: constructor `LyricsService({LyricsFetcher? fetcher, DirectoryProvider? lyricsDirectory})`.
   Por defecto `LrclibFetcher()` y `<getApplicationSupportDirectory()>/lyrics`. Ese directorio se
   resuelve **al usarlo** (con try/catch: si falla, no hay caché pero se sigue). `shared` sigue existiendo.
   - **Clave de caché:** `videoIdFromPath(song.filePath)`. Si no hay id, usa el nombre del archivo
     sin extensión con todo lo que no sea `[A-Za-z0-9_-]` cambiado por `_`, cortado a 100 caracteres.
   - **Orden en `_findAndParse`:**
     1. `.lrc` local exacto.
     2. Búsqueda tolerante (como hoy).
     3. `<lyricsDir>/<clave>.lrc`.
     4. Si existe `<clave>.none` con menos de 7 días, devuelve `null`.
     5. `fetcher.fetch(title: song.title, artist: song.artist, duration: song.duration)`: si
        devuelve texto, guárdalo en `<clave>.lrc` y parsea; si devuelve `null`, crea `<clave>.none`
        y devuelve `null`; si lanza `LyricsFetchException`, devuelve `null` **sin** crear marcador y
        **sin** guardar el `null` en la caché en memoria (así se reintenta con conexión).
   - **Método público para la precarga del jefe:**
     `Future<void> prefetch({required String cacheKey, required String title, String? artist, Duration? duration})`.
     Si ya hay `.lrc` o `.none` vigente no hace nada; si no, hace el paso 5 con esa clave. Nunca lanza.
   - **Método público:** `Future<void> deleteCachedFor(String audioPath)`, que borra `<clave>.lrc` y `<clave>.none`. Nunca lanza.
3. **`storage_service.dart` · `deleteSongFile`:** tras borrar el audio, llama
   `await LyricsService.shared.deleteCachedFor(file.path)` dentro de try/catch con `debugPrint`.
4. **`lyrics_view.dart`:** mientras el future está pendiente, el texto de carga es
   `'Buscando letra…'` (si ya hay un estado de carga, cambia solo su texto). El mensaje de
   no disponible pasa a `'Letra no disponible para esta canción.'`. No toques la lógica de
   sincronización ni el scroll.

## Pruebas (ninguna puede usar la red real)

- `test/lyrics_fetcher_test.dart` con `MockClient`:
  1. Título `'FloyyMenor - BANSHEE Ft J Balvin (Video Official)'` con artista `'Artista desconocido'`:
     el `q` enviado contiene `FloyyMenor` y `BANSHEE`, y **no** `Video Official`.
  2. Con dos resultados (uno sincronizado a 188 s y otro con el mismo título a 208 s) y una
     duración de 189 s, elige el de 188 s.
  3. Si ninguno está dentro de ±3 s, devuelve `null`.
  4. Si la respuesta es HTTP 500 o el cliente lanza una excepción, sale `LyricsFetchException`.
- `test/lyrics_service_test.dart` (agrega; **no** relajes las existentes). Usa un fetcher falso que
  cuenta llamadas y un `lyricsDirectory` temporal. Las pruebas existentes deben recibir un fetcher
  falso que devuelva null, para que nunca salgan a la red.
  1. Sin `.lrc` local: llama al fetcher una vez, guarda `<id>.lrc` y devuelve letra sincronizada.
     Una **segunda instancia** de `LyricsService` con el mismo directorio la lee de caché sin
     llamar al fetcher.
  2. Si el fetcher devuelve `null`: se crea `<id>.none` y otra instancia no vuelve a llamar al fetcher.
  3. Si el fetcher lanza `LyricsFetchException`: no se crea `.none`, y una segunda llamada a
     `loadLyrics` en la **misma** instancia sí vuelve a llamar al fetcher.
  4. Con un `.lrc` junto al audio, el fetcher no se llama.
  5. `deleteCachedFor` borra `<id>.lrc`.

## Criterios de aceptación

- [ ] `grep -rn "lrclib.net" test` no devuelve nada (sin red real en pruebas).
- [ ] `grep -n "Agrega un archivo .lrc" lib` no devuelve nada.
- [ ] Las pruebas nuevas existen y las anteriores pasan sin relajarse.
- [ ] `flutter analyze --no-pub` sin problemas.
- [ ] Sin `catch (_) {}` nuevos (usa `debugPrint`) y sin `TODO`.
- [ ] Diff limitado a los archivos permitidos, sin reformatear código ajeno.

## Qué se probará en el entorno real

En el celular, con internet:
1. Reproducir una canción descargada de YouTube y abrir "Letra": aparece sincronizada y avanza con la música.
2. Activar el modo avión y volver a abrirla: sigue apareciendo (caché).
