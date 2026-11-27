# Brief R7 · Barra inferior, Inicio y Buscar

- **Rama:** `feat/rediseno-navegacion` · **Worktree:** `~/Desktop/Projects/worktrees/aura-rediseno-navegacion`
- **Lee primero:** `AGENTS.md` (reglas obligatorias), `docs/rediseno/README.md` (sección «Navegación nueva») y los prototipos `docs/rediseno/prototipo/Main.dc.html` (Inicio) y `Buscar.dc.html`.
- **Objetivo:** reemplazar las pestañas de arriba (BIBLIOTECA / DESCARGAS / YOUTUBE) y el menú de hamburguesa por una barra inferior de 4 destinos con el mini reproductor encima, y crear las pantallas Inicio y Buscar con datos reales de la biblioteca.

## Contexto (por qué)

- `lib/screens/home_screen.dart`:
  - `HeaderBar` (logo copiado de YouTube Music + «Abrir app») + `TabBar` con 3 pestañas + `TabBarView` + `MiniPlayer` flotante;
  - `_showFolderOptions` es la hoja «Configuración» (crear playlist, elegir carpeta, actualizar);
  - `_showCreateFolderDialog` es el diálogo «Crear Playlist (Subcarpeta)»;
  - `MusicSearchDelegate` es la búsqueda vieja con `showSearch`;
  - `_openFullscreenPlayer` abre el reproductor.
- Ya integrado en `integracion/rediseno` (léelo, no lo cambies):
  - `lib/widgets/aura_logo.dart`: `AuraWordmark`, `AuraMark` y `AuraAppIcon`.
  - `lib/screens/library_screen.dart`: `LibraryScreen({onSearch, onCreatePlaylist, bottomInset})`.
  - `lib/widgets/song_tile.dart`: `SongTile` y `NowPlayingBars`.
  - `lib/widgets/collage_cover.dart`: `PlaylistArtwork`.
  - `lib/screens/playlist_detail_screen.dart`: `PlaylistDetailScreen(playlist:)`.
  - `lib/screens/youtube_screen.dart`: `YoutubeScreen`.
  - `lib/widgets/mini_player.dart`: `MiniPlayer(onExpand:)`.
  - `lib/services/storage_service.dart`:
    - listas: `recentlyPlayed`, `mostPlayed`, `recentlyAdded`;
    - `autoPlaylist(AutoPlaylistKind)`, `topArtists`, `artistMix(artista)`, `likedSongsPlaylist`, `playlists`, `allSongs`;
    - búsqueda: `searchSongs(q)`, `searchPlaylists(q)`;
    - búsquedas recientes: `recentSearches`, `addSearch`, `removeSearch`, `clearSearches`.

  **Nunca calcules listas, órdenes ni filtros en las pantallas:** usa esos getters.
- `test/widget_test.dart` prueba la app completa con las pestañas viejas y el menú de hamburguesa. Esta tarea la **reescribe** para la navegación nueva, conservando las comprobaciones de la hoja «Configuración».

## Archivos permitidos

- `lib/screens/home_screen.dart`
- `lib/widgets/header_bar.dart`
- `lib/screens/inicio_screen.dart` (**nuevo**)
- `lib/screens/buscar_screen.dart` (**nuevo**)
- `test/widget_test.dart`
- `test/inicio_screen_test.dart` (**nuevo**)
- `test/buscar_screen_test.dart` (**nuevo**)

## Qué hacer

1. **`HomeScreen` como contenedor:**
   - `Scaffold` con `NavigationBar` (tema ya definido en `AppTheme.darkTheme`). Destinos e iconos según la tabla de `docs/rediseno/README.md`: Inicio, Buscar, Biblioteca, Añadir.
   - Cuerpo: `IndexedStack` con `InicioScreen`, `BuscarScreen`, `LibraryScreen(onSearch: ir a Buscar, onCreatePlaylist: _showCreateFolderDialog, bottomInset: …)` y `YoutubeScreen`.
   - `MiniPlayer` **encima** de la barra inferior (en `bottomNavigationBar`, una `Column` con el mini reproductor y la `NavigationBar`). El contenido deja ese espacio abajo.
   - `PopScope`: con el botón atrás de Android fuera de Inicio, vuelve a Inicio en lugar de cerrar la app.
   - Conserva `_showFolderOptions`, `_showCreateFolderDialog` y `_openFullscreenPlayer` con sus textos (los usa la prueba), pasados a tokens de `AppTheme`. Borra `TabController`, `TabBar` y `MusicSearchDelegate`.
2. **`header_bar.dart` → `InicioHeader`:**
   - `AuraWordmark` a la izquierda;
   - a la derecha, buscar (tooltip «Buscar», va al destino Buscar) y ajustes (`Icons.settings_outlined`, tooltip «Ajustes», abre `_showFolderOptions`);
   - sin «Abrir app», sin `Icons.menu` y sin el logo de YouTube Music.
3. **`InicioScreen`** (`Main.dc.html`), con callbacks `onOpenSearch`, `onOpenSettings`, `onAddMusic`:
   - `InicioHeader` arriba y un brillo sutil de `AppTheme.brandViolet` (radial, ≤ 22 % de opacidad) detrás.
   - **Chips de acceso rápido** (alto 40): uno por playlist de `storage.playlists` (hasta 8). Tocar uno abre su `PlaylistDetailScreen`.
   - **Cuadrícula 3 × 3** (tiles cuadrados, espacio 8, radio 8). Orden: «Música que te gustó», las playlists, `autoPlaylist(recentlyAdded)`, `autoPlaylist(mostPlayed)` y un `artistMix` por cada uno de los primeros `topArtists`; se omiten los `null` y los vacíos.
     - Cada tile: `PlaylistArtwork` a tamaño completo, degradado negro abajo y el nombre (`label`, 1 línea) con chevron.
     - Si la canción actual está en esa playlist, el tile lleva un anillo blanco de 2 px y `NowPlayingBars` arriba a la izquierda.
     - Con más de 9 tiles, `PageView` de páginas de 9 (máximo 3) con puntos indicadores.
   - **«Escuchado hace poco»** (`titleLarge`): fila horizontal de tarjetas de 144 con carátula, título y subtítulo (artista o, si no se conoce, la carpeta). El botón «Más» abre `autoPlaylist(recentlyPlayed)`. La sección **no aparece** si la lista está vacía.
   - Biblioteca vacía (`allSongs` vacío y sin carga): icono, «Tu biblioteca está vacía» y un botón «Añadir música» que llama `onAddMusic`.
   - Mientras `isLoading`, un indicador de progreso.
4. **`BuscarScreen`** (`Buscar.dc.html`):
   - Campo en píldora (alto 52, `surfaceHigh`), con icono de buscar, placeholder «Canciones, artistas, playlists…» y botón «Borrar búsqueda» (tooltip) si hay texto. Al **enviar**, `storage.addSearch(q)`.
   - **Sin consulta:**
     - «Reproducido hace poco»: fila de tarjetas de 104 con `recentlyPlayed`, si hay. Tocar reproduce.
     - Búsquedas recientes: filas de 56 con icono `history`, el texto y un botón «Usar búsqueda <texto>» (icono `north_west`) que rellena el campo. Al tocar la fila se busca. Botón «Borrar historial» que llama `clearSearches()`.
     - «Explora tu música»: tarjetas `surface` de radio 16 para «Recién añadidas», «Más escuchadas» y «Música que te gustó», que abren su playlist. Se omiten las que no tienen canciones.
   - **Con consulta:**
     - sección «Playlists» (`searchPlaylists`, filas con `PlaylistArtwork` de 56);
     - sección «Canciones» (`searchSongs` con `SongTile`; tocar reproduce con los resultados como cola);
     - sin resultados: «Sin resultados para "<consulta>"».
5. **Pruebas.** Para tener datos reales, usa una carpeta temporal con subcarpetas y `.m4a` vacíos + `setCustomRootDirectory`, y un `LibraryStateStore` con directorio temporal.
   - `widget_test.dart`:
     - se ven las etiquetas Inicio, Buscar, Biblioteca y Añadir;
     - no existen «BIBLIOTECA», «Abrir app» ni `Icons.menu`;
     - el tooltip «Ajustes» abre «Configuración» con las mismas comprobaciones de hoy (crear playlist, cerrar, etc.);
     - tocar «Añadir» muestra «Añadir música».
   - `inicio_screen_test.dart`: aparecen «Música que te gustó» y las playlists de la carpeta. «Escuchado hace poco» no aparece sin historial y sí después de `storage.recordPlay(song)`. Con la biblioteca vacía aparece el botón «Añadir música».
   - `buscar_screen_test.dart`: escribir «asi» y enviar muestra la canción «Esto Es Así» y guarda la búsqueda. Con el campo vacío aparece en recientes. «Borrar historial» la quita.

## Criterios de aceptación

- [ ] `grep -rn "Abrir app\|TabBar\|MusicSearchDelegate\|Icons.menu" lib/` no devuelve nada.
- [ ] `grep -n "Color(0x\|fontSize:" lib/screens/home_screen.dart lib/screens/inicio_screen.dart lib/screens/buscar_screen.dart lib/widgets/header_bar.dart` no devuelve nada.
- [ ] Ni `inicio_screen.dart` ni `buscar_screen.dart` contienen `.sort(` ni `.where(` (los datos salen de `MusicStorageService`).
- [ ] Las tres pruebas cubren el paso 5.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el entorno real (lo hace el humano)

Moverse entre Inicio, Buscar, Biblioteca y Añadir con la barra inferior. El mini reproductor queda siempre encima de la barra. El botón atrás vuelve a Inicio. Desde ajustes se crea una playlist. En Buscar, encontrar una canción por artista sin tildes.
