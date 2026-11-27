# Brief R3 · Logo «A·Play»: widget, icono de la app e icono de notificación

- **Rama:** `feat/rediseno-logo` · **Worktree:** `~/Desktop/Projects/worktrees/aura-rediseno-logo`
- **Lee primero:** `AGENTS.md` (reglas obligatorias) y la sección «Logo «A·Play»» de `docs/rediseno/README.md`. Las referencias visuales exactas están en `docs/rediseno/prototipo/Logo.dc.html` (concepto 1) y `docs/rediseno/prototipo/Marca.dc.html` (SVG en línea).
- **Objetivo:** reemplazar el logo copiado de YouTube Music (círculo rojo con anillo y play) por el logo propio de Aura. Incluye el widget para la interfaz, el icono del lanzador de Android (clásico, adaptativo y monocromo) y un icono de notificación blanco.

## Contexto (por qué)

- `tool/make_app_icon.py` genera hoy el icono rojo «estilo YouTube Music» con un escritor de PNG propio en Python puro (sin PIL). Escribe en `android/app/src/main/res/mipmap-*/` y en `values/ic_launcher_background.xml` (`#FF0033`).
- `lib/main.dart` usa `androidNotificationIcon: 'mipmap/ic_launcher'`. Android pinta el icono pequeño de la notificación como silueta: un icono a color se ve como un cuadro blanco. Hace falta `drawable/ic_stat_aura` blanco sobre transparente. **No toques `main.dart`**: lo cambia el jefe al integrar.
- Geometría del logo en un lienzo de 100 × 100:
  - A: polilínea `(20,82) → (50,18) → (80,82)`, grosor 13, extremos y unión redondeados. Degradado lineal de arriba-izquierda a abajo-derecha: `#FF8A3D` (0) → `#FF3D7F` (0,5) → `#8B5CFF` (1) (`AppTheme.brandGradient`).
  - Play: triángulo `(45,56.5) (45,71.5) (59,64)` blanco, con borde blanco de grosor 3 y unión redondeada.
  - Icono: cuadrado redondeado (radio 23) color `#0E0B14` (`AppTheme.brandInk`), más un brillo radial centrado en (50 %, 62 %) con radio 55 %: `#FF3D7F` al 42 % de opacidad → `#8B5CFF` al 14 % (parada 0,55) → transparente. Encima va la A escalada al 68 % y centrada (`translate(16,16) scale(.68)`).
- La barra superior de Inicio usará `AuraWordmark` (marca de 30 px + «Aura» con `AppTheme.wordmark`). Lo conecta otro agente: aquí solo se crea el widget.

## Archivos permitidos

- `lib/widgets/aura_logo.dart` (**nuevo**)
- `test/aura_logo_test.dart` (**nuevo**)
- `tool/make_app_icon.py`
- `android/app/src/main/res/mipmap-*/ic_launcher*.png` (regenerados por el script)
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, `ic_launcher_round.xml`
- `android/app/src/main/res/values/ic_launcher_background.xml`
- `android/app/src/main/res/drawable-*/ic_stat_aura.png` (**nuevos**, generados por el script)

## Qué hacer

1. **`lib/widgets/aura_logo.dart`**:
   - `enum AuraMarkStyle { gradient, white, mono }`. `mono` usa un `Color` que se pasa al widget.
   - `class AuraMark extends StatelessWidget`: `({double size = 30, AuraMarkStyle style = AuraMarkStyle.gradient, Color? color})`. Pinta **solo la A y el play** (sin fondo) con un `CustomPainter` que sigue la geometría de arriba, escalada a `size`. Con `gradient`, el play es blanco.
   - `class AuraAppIcon extends StatelessWidget`: `({double size = 96})`. Pinta el icono completo (fondo `brandInk`, brillo radial y la A al 68 %).
   - `class AuraWordmark extends StatelessWidget`: una `Row` con `AuraMark(size: 30)`, 8 px de espacio y `Text('Aura', style: AppTheme.wordmark)`. Semántica: un único nodo con etiqueta «Aura».
   - Colores y estilos solo desde `AppTheme`. Los `shouldRepaint` comparan los parámetros.
2. **`tool/make_app_icon.py`**: reescríbelo para el logo nuevo, en **Python puro** (sin PIL ni numpy), conservando su escritor de PNG.
   - **Antialiasing por supermuestreo:** dibuja a 4× y promedia bloques de 4 × 4.
   - Para dibujar la A, usa la distancia de cada punto a los dos segmentos (el trazo con extremos redondeados es una «cápsula»). El triángulo es un polígono con el borde redondeado de grosor 3. El degradado se proyecta sobre la diagonal del rectángulo que encierra la A.
   - Genera:
     - `mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` e `ic_launcher_round.png` (48/72/96/144/192 px): el icono completo. En `_round`, el fondo es un círculo en lugar del cuadrado redondeado.
     - `ic_launcher_foreground.png` (108/162/216/324/432 px): fondo transparente, el brillo radial y la A escalada al **58 %** del lienzo de 108 y centrada, dentro de la zona segura de 66 dp.
     - `ic_launcher_mono.png`: la A al 58 %, blanca y sólida (play incluido), sobre transparente.
     - `values/ic_launcher_background.xml` con `#0E0B14`, y los XML adaptativos (background + foreground + monochrome) como hoy.
     - `drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_stat_aura.png` (24/36/48/72/96 px): la A blanca sólida sobre transparente, ocupando ~85 % del lienzo.
   - Actualiza el docstring del script y **ejecútalo** (`python3 tool/make_app_icon.py`; es el único comando extra permitido en esta tarea) para que los PNG queden en el commit.
3. **`test/aura_logo_test.dart`** (pruebas de widgets):
   - `AuraMark`, `AuraAppIcon` y `AuraWordmark` se pintan a 24, 48 y 200 px sin excepciones.
   - `AuraWordmark` expone la etiqueta semántica «Aura» y muestra el texto «Aura».
   - `AuraMark(style: AuraMarkStyle.mono)` sin `color` usa `AppTheme.textPrimary`.

## Criterios de aceptación

- [ ] `grep -rn "FF0033\|FF0000\|youtube" tool/make_app_icon.py android/app/src/main/res/values/ic_launcher_background.xml` no devuelve nada (sin distinguir mayúsculas: `grep -rni`).
- [ ] Existen los 5 `ic_stat_aura.png` y los PNG de `mipmap-*` cambiaron en el commit.
- [ ] `lib/widgets/aura_logo.dart` no tiene `Color(0x`: todo sale de `AppTheme`.
- [ ] Las pruebas de `test/aura_logo_test.dart` existen y cubren lo del paso 3.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el entorno real (lo hace el humano)

Instalar la APK: el icono del lanzador muestra la A en degradado sobre fondo oscuro (también con los iconos temáticos de Android activados). Al reproducir, la notificación muestra la A blanca y no un cuadro.
