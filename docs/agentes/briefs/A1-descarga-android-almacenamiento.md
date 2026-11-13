# Brief A1 · La descarga de YouTube no guarda nada en Android

- **Rama:** `fix/android-almacenamiento-descarga` · **Worktree:** `../worktrees/aura-fix-android-storage`
- **Objetivo:** que la descarga de YouTube guarde el `.m4a` en `Music/AuraMusic/...` en Android (scoped storage), y que un error de disco falle rápido con un mensaje claro en vez de colgarse.

## Contexto (por qué). Diagnóstico ya hecho por el jefe en el celular real

Android 16 (Xiaomi HyperOS), `targetSdk 36`. La raíz de música es
`/storage/emulated/0/Music/AuraMusic` (`lib/services/storage_service.dart`).
En Android 10+ esa carpeta pertenece a MediaStore, y **solo admite crear archivos
con extensión de audio**. Lo medimos en el teléfono con `dart:io`:

| Archivo creado en `Music/AuraMusic/...` | Resultado |
| :--- | :--- |
| `.m4a`, `.wav` | OK |
| `.part`, `.webm`, `.jpg` | `PathAccessException ... Operation not permitted, errno = 1` |

La red **sí funciona** en Android: `YoutubeBackend.audio()` y el stream de bytes
descargan el audio completo en unos 2 s. El fallo está en
`YoutubeDownloadService._downloadTrack` (`lib/services/youtube_service.dart`,
~líneas 470-545):

1. Escribe primero `File('$base.part')` **dentro de la carpeta de música**, y Android lo rechaza.
2. Lo abre con `partial.openWrite()` (`IOSink`). El `IOSink` abre el archivo de forma
   perezosa, así que el error de apertura no salta en `add()`: los chunks se
   acumulan y `await sink.flush()` se queda colgado. En el celular la UI queda
   eternamente en "(1/17) ... · intento 1/3". No sale ningún log ni ningún timeout.
3. Si llegara a saltar, el `catch` lo disfraza de "No se pudo obtener el audio",
   que es un mensaje engañoso.

En Linux no hay scoped storage, por eso allí funciona.

## Archivos permitidos

- `lib/services/youtube_service.dart`
- `test/youtube_service_test.dart`

No toques ningún otro archivo. No agregues dependencias: `path_provider` ya está
en `pubspec.yaml` (API en `~/.pub-cache/hosted/pub.dev/path_provider-2.1.6/lib/path_provider.dart`,
solo lectura).

## Qué hacer

1. **Directorio temporal inyectable.** Agrega al constructor de `YoutubeDownloadService`
   un parámetro opcional con nombre `Future<Directory> Function()? tempDirectory`.
   Por defecto usa `getTemporaryDirectory` de `package:path_provider/path_provider.dart`.
   Resuélvelo **solo al descargar** (dentro de `startDownload`/`_downloadTrack`),
   nunca en el constructor: `widget_test.dart` y `main.dart` construyen el
   servicio sin plugins y no deben romperse.
2. **El archivo parcial vive fuera de la carpeta de música.** En `_downloadTrack`,
   el parcial va en `<tempDir>/aura_<videoId>.part`. La carpeta de destino nunca
   debe contener un `.part`.
3. **Escritura que falla rápido.** Reemplaza `openWrite()`/`IOSink` por
   `RandomAccessFile`: `await partial.open(mode: FileMode.write)` y `await raf.writeFrom(chunk)`
   por cada chunk, cerrándolo en `finally`. Así un error de apertura o escritura
   lanza la excepción de inmediato. Elimina `openWrite` del archivo.
4. **Publicar el audio terminado.** Cuando el tamaño es correcto, mueve el parcial a
   `'$base.${audio.extension}'`. Intenta `rename`. Si lanza `FileSystemException`
   (en Android el temporal está en otro sistema de archivos: EXDEV), haz `copy` al
   destino. Si `copy` falla, borra el destino si quedó a medias (nunca dejes un
   archivo de audio truncado, porque el siguiente intento lo daría por descargado)
   y relanza el error. Al final borra siempre el parcial (en `finally`, como hoy).
5. **Errores de almacenamiento: mensaje claro y sin reintentos.** Si la excepción es
   `FileSystemException` (incluye `PathAccessException`), no reintentes: no es
   transitorio. Pon en `_lastDownloadError` algo como
   `'No se pudo guardar el audio en la carpeta de música: <osError.message o message>'`
   y devuelve `false`. Conserva los mensajes actuales para los errores de red y 403.
   Mantén el `debugPrint` del error real.
6. **Pruebas** en `test/youtube_service_test.dart`:
   - Actualiza el `setUp` para inyectar un directorio temporal propio de la prueba
     (`Directory.systemTemp.createTemp(...)`) en `tempDirectory`, y bórralo en `tearDown`.
     Las pruebas existentes deben seguir pasando sin debilitarlas.
   - Nueva prueba: *"el parcial nunca se escribe en la carpeta de música"*. Con el
     `FakeBackend`, emite al menos dos chunks y, entre uno y otro, lista
     recursivamente la carpeta de destino. Afirma que no hay ningún `.part` y que el
     parcial existe en el temporal inyectado. Al terminar, el `.m4a` final existe con
     el tamaño correcto y el temporal no tiene `.part`.
   - Nueva prueba: *"un error de disco falla rápido, sin reintentos y con mensaje
     claro"*. Inyecta como `tempDirectory` una ruta que sea un **archivo** existente
     (así `open` falla). `startDownload` debe devolver `false` en menos de 5 s
     (usa `.timeout`), con una sola llamada a `backend.audio` para esa pista y un
     `statusMessage` que contenga `carpeta de música`.

## Criterios de aceptación

- [ ] `grep -n "openWrite" lib/services/youtube_service.dart` no devuelve nada.
- [ ] `grep -n "\.part" lib/services/youtube_service.dart` solo muestra el parcial construido sobre el directorio temporal.
- [ ] Las dos pruebas nuevas existen y las anteriores siguen intactas (no se borra ni se relaja ningún `expect`).
- [ ] `flutter analyze --no-pub` sin problemas.
- [ ] Sin `catch (_) {}` nuevos ni `TODO`.
- [ ] Diff limitado a los 2 archivos permitidos y sin reformatear código ajeno al cambio.

## Qué se probará en el entorno real (lo hace el humano o el jefe por adb)

Instalar en el Xiaomi y descargar una canción y una playlist desde la pestaña
YOUTUBE. Los `.m4a` deben aparecer en `Music/AuraMusic/<playlist>/` y en Biblioteca,
sin ningún `.part`.
