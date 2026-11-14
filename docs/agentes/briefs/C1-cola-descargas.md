# Brief C1 · Cola de descargas de YouTube

- **Rama:** `feat/cola-descargas` · **Worktree:** `../worktrees/aura-cola-descargas`
- **Objetivo:** que el usuario pueda pegar y analizar otro enlace **mientras** se descarga una playlist y mandarlo a una cola de espera. Las descargas corren una detrás de otra y la pestaña YOUTUBE muestra la cola.

## Contexto (por qué)

Hoy, en `lib/services/youtube_service.dart` (`YoutubeDownloadService`):
- `analyzeUrl()` devuelve `null` si `_isDownloading` (línea ~357): no se puede pegar otro enlace mientras se descarga.
- `clearPreview()` llama `_backend.cancel()`, que cierra **también** el cliente de audio de la descarga en curso.
- Hay un único estado de descarga (`_isDownloading`, `_completedTracks`, `_failedTracks`, `_totalTracks`, `_currentProgress`, `_currentTrackTitle`, `_previewDownloaded`).
- `startDownload(storage, {targetSubfolder})` descarga el preview actual y devuelve `true` solo si todo salió bien.

La UI está en `lib/screens/youtube_screen.dart`:
- `_mediaRow(preview)` muestra el preview.
- `_downloadProgress(service)` muestra la barra con "Cancelar descarga".
- Hay un bloque `isPreviewDownloaded` con "Descargada en tu biblioteca".
- El botón dice "Descargar playlist/canción", o "Reintentar N fallidas" si `failedTracks > 0`.

El servicio es global (`ChangeNotifierProvider` en `lib/main.dart`), así que la cola sigue viva aunque el usuario cambie de pestaña.

## Archivos permitidos

- `lib/services/youtube_service.dart` (`YoutubeBackend.cancel` y `YoutubeDownloadService`)
- `lib/models/download_job.dart` (**nuevo**)
- `lib/screens/youtube_screen.dart`
- `test/youtube_service_test.dart`
- `test/youtube_download_state_test.dart`
- `test/youtube_screen_test.dart`
- `test/download_queue_test.dart` (**nuevo**)

**No toques** `_downloadTrack`, `_artwork`, `YoutubeBackend.audio/_audioChunks/playlist/video` ni el constructor. Otro agente añadirá después una línea en `startDownload`/runner para las letras.

## Diseño decidido (no lo cambies)

1. **Modelo** `lib/models/download_job.dart`:
   ```dart
   enum DownloadJobStatus { waiting, downloading, done, failed, cancelled }
   class DownloadJob {
     final int id;                       // incremental
     final YoutubePreview preview;
     final List<PlaylistTrack> tracks;
     final String? targetSubfolder;
     DownloadJobStatus status;
     int completed, failed;
     String? error;                      // _lastDownloadError al terminar
     // + un Completer<bool> interno para que startDownload pueda esperar el resultado
   }
   ```
   (`YoutubePreview` y `PlaylistTrack` vienen de los servicios existentes; importa lo necesario.)
2. **Backend:** separa `cancel()` en `cancelAnalysis()` (cierra `_active` y `_playlistClient`) y
   `cancelAudio()` (cierra `_audioClient`). `cancel()` llama a ambos. Actualiza `FakeBackend` en
   las pruebas.
3. **Servicio:**
   - `analyzeUrl` **se permite durante una descarga**. Solo se bloquea si ya hay un análisis en curso.
     `clearPreview()` solo usa `cancelAnalysis()` y también funciona durante una descarga.
   - `DownloadJob? enqueue(MusicStorageService storage, {String? targetSubfolder})`: crea un job con
     el preview y los tracks actuales y lo agrega en `waiting`. Si no hay ninguno corriendo,
     arranca el *runner*. Devuelve `null` y deja un `statusMessage` claro si no hay preview, si
     falta la carpeta raíz, o si ese mismo `preview.id` ya está `waiting`/`downloading` ("Ya está en la cola").
   - **Runner:** procesa los jobs `waiting` en orden FIFO, uno a la vez. Reutiliza la lógica
     actual del bucle de `startDownload` (carpeta destino, `_downloadTrack`, `_artwork`,
     contadores, `scanLibrary` al terminar cada job) y marca `done`/`failed`/`cancelled`.
   - `Future<bool> startDownload(storage, {targetSubfolder})` se mantiene para compatibilidad:
     `enqueue(...)` y luego espera el resultado de **ese** job (`true` solo si quedó `done`).
     Devuelve `false` si `enqueue` devolvió `null`.
   - `cancel()` cancela **solo el job en curso** (como hoy, sin publicar audio incompleto), y el
     runner sigue con el siguiente. `removeJob(int id)` quita un job `waiting`.
     `clearFinished()` quita los `done`/`failed`/`cancelled`.
   - Getters nuevos: `List<DownloadJob> get jobs` (inmodificable, en orden),
     `DownloadJob? get currentJob`, `int get waitingCount`, `DownloadJob? jobFor(String previewId)`
     (el más reciente con ese id).
   - Los getters existentes (`isDownloading`, `currentProgress`, `completedTracks`,
     `failedTracks`, `totalTracks`, `currentTrackTitle`) se refieren al **job en curso** si lo hay.
     Si no, al job del preview actual (`jobFor(preview.id)`). Si tampoco, valen 0/null.
     `isPreviewDownloaded` es `jobFor(preview.id)?.status == done`.
4. **UI** (`youtube_screen.dart`). Usa solo colores de `AppTheme`.
   - Con preview, según `jobFor(preview.id)`:
     - `null`: botón `'Descargar playlist'`/`'Descargar canción'` si no hay nada corriendo, o
       `'Añadir a la cola'` (icono `Icons.queue_music`) si hay una descarga en curso. El botón llama `enqueue`.
     - `waiting`: fila informativa `'En cola · posición N'`, sin botón.
     - `downloading`: el `_downloadProgress` actual.
     - `done`: la fila actual "Descargada en tu biblioteca".
     - `failed`: botón `'Reintentar N fallidas'`, que vuelve a llamar `enqueue` (crea un job nuevo).
   - **Sección "Cola de descargas"** (solo si `jobs` no está vacío), debajo del preview: una fila
     por job con miniatura pequeña (`preview.thumbnailUrl`), título, y el estado
     (`Descargando 3/17`, `En espera`, `Descargada`, `N fallidas`, `Cancelada`).
     - Los `waiting` tienen un `IconButton` con `Icons.close` (tooltip `'Quitar de la cola'`) → `removeJob`.
     - Si hay terminados, un `TextButton` `'Limpiar terminadas'` → `clearFinished`.
   - El campo de enlace y "Analizar enlace"/"Pegar" quedan **habilitados durante la descarga**.
     Solo se deshabilitan mientras `isAnalyzing`.
   - El texto del botón de `_downloadProgress` pasa a `'Cancelar esta descarga'`.

## Pruebas

- `test/youtube_service_test.dart`: la prueba "cancelar no publica audio ni acepta otro análisis
  durante la descarga" choca con la función nueva. **Autorizo** cambiar solo sus líneas
  `expect(await service.analyzeUrl('https://youtu.be/BBBBBBBBBBB'), isNull);` y
  `service.clearPreview(); expect(service.preview!.id, 'AAAAAAAAAAA');`. Deben pasar a afirmar
  que el análisis **sí** funciona durante la descarga y que `clearPreview` no la cancela.
  Renombra la prueba a "cancelar no publica audio incompleto". El resto de sus `expect` se
  mantienen. Ninguna otra prueba se relaja.
- `test/download_queue_test.dart` (**nuevo**). Copia los fakes (`FakeStorage`, `FakeBackend` con
  `blocked`) en el archivo; no importes otros archivos de prueba. Debe cubrir:
  1. Mientras el job 1 está bloqueado (`backend.blocked`), se analiza y encola otro enlace: queda
     `waiting` y `waitingCount == 1`. Al liberar, ambos terminan `done` **en orden**: en
     `backend.calls`, todas las pistas del primero van antes que las del segundo.
  2. `removeJob` de un job `waiting`: nunca se descarga (no aparece en `backend.calls`).
  3. `cancel()` durante el job 1: queda `cancelled` y el job 2 arranca y termina `done`.
  4. Encolar dos veces el mismo `preview.id` mientras espera: devuelve `null` y no duplica.
  5. `clearPreview()` durante una descarga no la cancela: termina `done`.
- `test/youtube_screen_test.dart`: el doble `_Youtube` sobrescribe getters. Agrégale lo necesario
  (`jobs`, `jobFor`, `currentJob`, `waitingCount`) para que compile. Agrega una prueba de widget:
  con `downloading = true` y un job `waiting` en `jobs`, se ve `'Cola de descargas'`, `'En espera'`
  y el tooltip `'Quitar de la cola'`. Las pruebas de desbordes existentes deben seguir pasando.

## Criterios de aceptación

- [ ] Las 5 pruebas de cola, la de widget y todas las existentes pasan. Ninguna se relaja salvo
      las 2 líneas autorizadas arriba.
- [ ] `grep -n "if (_isDownloading || _isAnalyzing) return null" lib/services/youtube_service.dart` no devuelve nada.
- [ ] `flutter analyze --no-pub` sin problemas.
- [ ] Sin `catch (_) {}`, sin `TODO` y sin colores fuera de `AppTheme`.
- [ ] Diff limitado a los archivos permitidos, sin reformatear código ajeno.

## Qué se probará en el entorno real

En el celular:
1. Descargar una playlist y, mientras baja, pegar otro enlace y tocar "Añadir a la cola".
2. Ver la cola con "En espera" y quitar un elemento.
3. Comprobar que al terminar la primera arranca sola la siguiente.
