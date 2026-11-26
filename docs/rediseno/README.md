# Rediseño de Aura (noviembre de 2026)

Interfaz inspirada en YouTube Music, pero con **marca propia**: se eliminan el
«▶ Music» rojo, el botón «Abrir app» y el icono circular rojo copiados de
YouTube Music.

- Prototipo navegable (solo el dueño del repo puede abrirlo):
  https://claude.ai/artifact/3LA3wgW6gCFMD255iYw6Xb
- Copia del prototipo, pantalla por pantalla, en `prototipo/*.dc.html`. Es HTML
  normal con estilos en línea: ahí están las medidas, los colores y los textos
  exactos. Las imágenes `/_blob/...` son carátulas de ejemplo: en la app salen
  de `Song.artworkBytes`.
- Tokens (colores, tipografía, medidas): `lib/theme/app_theme.dart`. **Ninguna
  pantalla escribe colores, tamaños de letra ni radios sueltos.**

## Navegación nueva

Barra inferior de 4 destinos (`NavigationBar`), alto 72, fondo
`AppTheme.navBar`. Icono relleno + etiqueta en negrita = destino activo;
contorno + etiqueta normal = inactivo.

| Destino | Icono (inactivo / activo) | Pantalla | Prototipo |
| :--- | :--- | :--- | :--- |
| Inicio | `home_outlined` / `home_rounded` | `lib/screens/inicio_screen.dart` | `Main.dc.html` |
| Buscar | `search` en ambos estados (la etiqueta en negrita marca el activo) | `lib/screens/buscar_screen.dart` | `Buscar.dc.html` |
| Biblioteca | `bookmark_border` / `bookmark` | `lib/screens/library_screen.dart` | `Biblioteca.dc.html` |
| Añadir | `download_outlined` / `download` | `lib/screens/youtube_screen.dart` | `Anadir.dc.html` |

El **mini reproductor** (alto 64, fondo `surfaceHigh`) queda fijo justo
encima de la barra inferior en todos los destinos. Al tocarlo se abre el
reproductor completo (`Reproductor.dc.html`). Las pantallas de detalle
(`Playlist.dc.html`, `MeGusta.dc.html`) se abren con `Navigator.push` y
también muestran el mini reproductor abajo.

Las opciones de carpeta («Crear una playlist», «Elegir carpeta»,
«Actualizar biblioteca») se abren desde el avatar «Y» de la barra superior de
Inicio (antes era el menú de hamburguesa).

## Reglas visuales

- Fondo `AppTheme.bg` (#030303). Texto principal blanco, secundario
  `textSecondary` (#AAAAAA).
- **Acento** `AppTheme.accent` (#FF3D7F) solo en: barra de progreso (mini y
  completo), indicador de «sonando ahora» (tres barritas) y progreso de
  descargas. Los botones de reproducir son **blancos** con icono negro.
- **Degradado de marca** `AppTheme.brandGradient` solo en el logo y en
  «Música que te gustó».
- Chips: alto 40, radio 8, fondo `chip`; seleccionado: fondo blanco y texto
  negro.
- Tipografía: Poppins 600 (`AppTheme.titleLarge`, `wordmark`) para títulos;
  Roboto para lo demás (`itemTitle` 16, `itemSubtitle` 14, `label` 14,
  `caption` 12).
- Áreas táctiles de 48 × 48 como mínimo. Botones de solo icono con
  `tooltip`.
- Si `song.hasKnownArtist` es `false`, el subtítulo muestra solo la
  duración: **nunca** «Artista desconocido».
- Sin emojis como iconos de la interfaz (los emojis de los nombres de
  carpeta sí se muestran: son datos del usuario).

## Logo «A·Play»

Una «A» de trazo redondeado cuyo travesaño es un triángulo de play.
Geometría en un lienzo de 100 × 100 (ver `prototipo/Logo.dc.html`):

- A: polilínea `(20,82) → (50,18) → (80,82)`, grosor 13, extremos y unión
  redondeados, con `brandGradient` de arriba-izquierda a abajo-derecha.
- Play: triángulo `(45,56.5) (45,71.5) (59,64)` blanco, con borde blanco de
  grosor 3 y unión redondeada.
- Icono de la app: cuadrado redondeado (radio 23) color `brandInk`, con un
  brillo radial (centro en 50 % / 62 %, radio 55 %: rosa al 42 % → violeta al
  14 % → transparente) y la A escalada al 68 % y centrada.
- Capa adaptativa de Android: la A escalada al 58 % (cabe en la zona segura
  de 66 dp). Icono monocromo y de notificación: la misma A en blanco sólido.
