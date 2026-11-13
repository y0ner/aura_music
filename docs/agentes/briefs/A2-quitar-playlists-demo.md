# Brief A2 · Quitar las playlists de demo autogeneradas

- **Rama:** `chore/quitar-playlists-demo` · **Worktree:** `../worktrees/aura-quitar-demo`
- **Objetivo:** que la app nunca vuelva a crear playlists ni canciones de demostración en la carpeta de música del usuario.

## Contexto (por qué)

`lib/services/storage_service.dart`:
- `initialize()` (~línea 45) llama a `await _ensureStarterContent();`.
- `_ensureStarterContent()` (~líneas 364-400): si la carpeta raíz está vacía, crea 4
  carpetas ("Trap Latino Malandro", "🍂 Autumn Vibes & Jazz", "🔥 Perreo & Club",
  "🏋️ Gym Motivación") con 5 `.wav` de tono cada una.
- `_generateSampleWavTone()` (~líneas 402-465) genera esos WAV.

El usuario ya borró esas carpetas, pero reaparecen cada vez que la carpeta de música
queda vacía. Son contenido falso: hay que eliminarlo del código.

## Archivos permitidos

- `lib/services/storage_service.dart`

## Qué hacer

1. Borra la llamada `await _ensureStarterContent();` de `initialize()`.
2. Borra por completo los métodos `_ensureStarterContent` y `_generateSampleWavTone`, con sus comentarios.
3. Si algún import queda sin uso (p. ej. el que aporta `ByteData`/`Endian`), quítalo
   **solo si** `flutter analyze --no-pub` lo marca como no usado. `Uint8List` se sigue usando en `_parseAudioFile`.
4. No cambies nada más: ni la lógica de escaneo, ni `likedSongsPlaylist`
   ("Música que te gustó" se queda), ni la heurística `isExplicit`, ni el formato del resto del archivo.

## Criterios de aceptación

- [ ] `grep -rn "_ensureStarterContent\|_generateSampleWavTone\|samplePlaylists\|Trap Latino Malandro" lib` no devuelve nada.
- [ ] `flutter analyze --no-pub` sin problemas.
- [ ] `git diff --stat` solo muestra `lib/services/storage_service.dart`, y solo con eliminaciones (más, como mucho, un import).

## Qué se probará en el entorno real

Con `Music/AuraMusic` vacía, abrir la app: la biblioteca queda vacía y no aparece ninguna carpeta de demo.
