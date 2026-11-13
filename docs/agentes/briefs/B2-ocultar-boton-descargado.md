# Brief B2 · Ocultar "Descargar playlist" cuando ya se descargó

- **Rama:** `feat/ocultar-boton-descargado` · **Worktree:** `../worktrees/aura-boton-descarga`
- **Objetivo:** que, tras una descarga completa, la pestaña YOUTUBE no vuelva a mostrar el botón "Descargar playlist/canción" hasta que el usuario analice otro enlace.

## Contexto (por qué)

Al terminar una descarga, `YoutubeDownloadService` conserva el `preview`, así que
`lib/screens/youtube_screen.dart` (~líneas 196-265: `if (service.isDownloading) ... else ...`)
vuelve a mostrar el `FilledButton.icon` de "Descargar playlist". El usuario se confunde y
cree que todavía tiene que descargar. Quiere que el botón solo aparezca con un enlace nuevo.

`lib/services/youtube_service.dart`, `YoutubeDownloadService`:
- `analyzeUrl()` (~línea 330) pone el preview nuevo.
- `clearPreview()` (~línea 290) lo limpia.
- `startDownload()` (~línea 395) devuelve `true` solo si se completó todo sin cancelar. Ya existen los getters `failedTracks`, `completedTracks` y `totalTracks`.

## Archivos permitidos

- `lib/services/youtube_service.dart`: **solo** la clase `YoutubeDownloadService`, en los campos y getters de estado, `clearPreview`, `analyzeUrl` y `startDownload`. No toques `_artwork`, `_downloadTrack` ni el constructor (otro agente trabaja ahí en paralelo).
- `lib/screens/youtube_screen.dart`
- `test/youtube_screen_test.dart`
- `test/youtube_download_state_test.dart` (**nuevo**)

## Qué hacer

1. **Estado en el servicio:** agrega `bool _previewDownloaded = false;` y `bool get isPreviewDownloaded => _previewDownloaded;`.
   - Ponlo en `true` en `startDownload` cuando el resultado es éxito completo (el mismo valor que devuelve `true`).
   - Ponlo en `false` al empezar `analyzeUrl`, en `clearPreview` y al empezar una descarga.
2. **UI** (`youtube_screen.dart`), dentro del bloque `else` de `if (service.isDownloading)`:
   - Si `service.isPreviewDownloaded`: **no** muestres el botón ni el selector "Guardar en". En su lugar, una fila informativa (sin `onPressed`) con `Icons.check_circle` y el texto `'Descargada en tu biblioteca'`, y debajo, en `AppTheme.textSecondary`, `'Pega otro enlace para descargar más.'`. Usa solo colores de `AppTheme`, como el resto de la pantalla.
   - Si no está descargada y `service.failedTracks > 0` (hubo una descarga incompleta): el botón sigue, pero con el texto `'Reintentar ${service.failedTracks} fallidas'`.
   - En cualquier otro caso, todo queda como hoy.
3. **Pruebas:**
   - `test/youtube_download_state_test.dart` (**nuevo**), con un `YoutubeBackend` falso y un `MusicStorageService` falso, como los de `test/youtube_service_test.dart` (cópialos; no importes ese archivo). Debe cubrir:
     - tras una descarga exitosa `isPreviewDownloaded` es `true`;
     - tras `analyzeUrl` de otro enlace vuelve a `false`;
     - con una pista fallida queda en `false`.
   - `test/youtube_screen_test.dart`: agrega a `_Youtube` un campo `bool downloaded = false` que sobrescriba `isPreviewDownloaded`. Agrega una prueba de widget: con preview y `downloaded = true`, `find.text('Descargar canción')` no encuentra nada y `find.text('Descargada en tu biblioteca')` encuentra uno. Las pruebas existentes no se tocan ni se relajan.

## Criterios de aceptación

- [ ] Con la descarga completa, el botón no aparece (prueba de widget).
- [ ] Al analizar otro enlace, el botón vuelve (prueba de servicio).
- [ ] `flutter analyze --no-pub` sin problemas.
- [ ] Sin colores fijos fuera de `AppTheme`, sin `TODO` y sin `catch (_) {}`.
- [ ] Diff limitado a los archivos permitidos, sin reformatear código ajeno.

## Qué se probará en el entorno real

En el celular: descargar una canción y comprobar que desaparece el botón y aparece
"Descargada en tu biblioteca". Al pegar otro enlace, el botón vuelve.
