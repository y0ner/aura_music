# Brief R2 · Carátulas sin franjas negras

- **Rama:** `feat/rediseno-caratulas` · **Worktree:** `~/Desktop/Projects/worktrees/aura-rediseno-caratulas`
- **Lee primero:** `AGENTS.md` (reglas obligatorias).
- **Objetivo:** que las carátulas de YouTube se guarden sin las franjas negras de arriba y abajo, para que los collages y las miniaturas cuadradas muestren la imagen y no bandas grises. Incluye las carátulas que ya están guardadas.

## Contexto (por qué)

- `lib/services/youtube_service.dart:763` `_artwork(videoId, url)` descarga `video.thumbnails.highResUrl`. Es la miniatura `hqdefault` de **480 × 360 (4:3)** y trae el video 16:9 en el centro, con **45 px negros arriba y 45 abajo**. La guarda tal cual en `<soporte>/covers/<id>.jpg` (`lib/services/artwork_store.dart`: `defaultArtworkDirectory`, `artworkFileFor`).
- Las pantallas muestran esas carátulas con `BoxFit.cover` en cuadros cuadrados, y las franjas negras siguen ahí porque forman parte de la imagen. En el celular del usuario ya hay 69 carátulas así.
- La dependencia `image` (`^4.5.0`) ya está en `pubspec.yaml`. Su API está en `~/.pub-cache/hosted/pub.dev/image-4.13.1/lib/` (`decodeImage`, `copyCrop`, `encodeJpg`, `Image.getPixel`, `Pixel.luminance`/`r,g,b`).
- **No detectes las franjas por oscuridad de forma libre:** muchas portadas tienen fondo negro (p. ej. «Coronamos»), y un detector libre se comería parte de la imagen. La regla es exacta (paso 1).

## Archivos permitidos

- `lib/services/artwork_store.dart`
- `lib/services/youtube_service.dart` (**solo** el método `_artwork` y los imports que necesite)
- `test/artwork_store_test.dart`

**No toques** `storage_service.dart`: otro agente trabaja ahí. El jefe conectará `normalizeArtworkDirectory` al escaneo cuando se fusionen las dos ramas.

## Qué hacer

1. En `artwork_store.dart`, la función pura `Uint8List? removeLetterbox(Uint8List bytes)`:
   - Decodifica la imagen. Si falla, devuelve `null`.
   - Solo actúa si la imagen es **exactamente 4:3** (`ancho * 3 == alto * 4`).
   - Banda superior = filas `[0, alto/8)`; banda inferior = filas `[alto*7/8, alto)`. Las dos deben ser «negras»: muestrea un píxel de cada 4 en cada fila y exige luminancia media < 20 y máxima < 48 (escala 0–255).
   - Si las dos bandas son negras, recorta a las filas `[alto/8, alto*7/8)` (queda 16:9, 480 × 270) y devuelve el JPEG (calidad 90). En cualquier otro caso devuelve `null`: la imagen no se toca.
2. `Future<int> normalizeArtworkDirectory(Directory dir)`:
   - Recorre los `*.jpg` del directorio que **no** figuran en `<dir>/.normalizadas` (un nombre de archivo por línea).
   - Procesa cada uno con `removeLetterbox` fuera del hilo de la interfaz (`Isolate.run`). Si devuelve bytes, reescribe el archivo. En los dos casos, añade el nombre a `.normalizadas`.
   - Devuelve cuántos archivos recortó. Nunca lanza: los errores van a `debugPrint` y el archivo queda como estaba.
   - Una segunda llamada sobre el mismo directorio devuelve `0` y no vuelve a decodificar.
3. En `youtube_service.dart` `_artwork`: con `statusCode == 200`, guarda `await Isolate.run(() => removeLetterbox(bytes)) ?? bytes`. Si el recorte falla, se guarda la original (con `debugPrint`). No cambies nada más de ese archivo.

## Criterios de aceptación

- [ ] La prueba de 480 × 360 con franjas negras de 45 px y el centro de color devuelve 480 × 270 y el color del centro se conserva.
- [ ] Una imagen 4:3 con el **centro también negro** pero las franjas de otro color devuelve `null`. Una imagen 1:1 devuelve `null`. Unos bytes corruptos devuelven `null`.
- [ ] Una imagen 4:3 de fondo negro con un dibujo en el centro que entra en la banda superior devuelve `null` (no recorta la imagen).
- [ ] `normalizeArtworkDirectory` en un directorio temporal con 2 carátulas con franjas y 1 sin ellas: la primera llamada devuelve 2 y la segunda 0, y `.normalizadas` lista los 3 nombres.
- [ ] `git diff integracion/rediseno -- lib/services/youtube_service.dart` solo toca `_artwork` e imports.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el entorno real (lo hace el humano)

Descargar una canción nueva desde Añadir: su carátula en Biblioteca se ve sin bandas negras arriba y abajo.
