# Brief R6 · Pantalla «Añadir» (descargas de YouTube)

- **Rama:** `feat/rediseno-anadir` · **Worktree:** `~/Desktop/Projects/worktrees/aura-rediseno-anadir`
- **Lee primero:** `AGENTS.md` (reglas obligatorias), `docs/rediseno/README.md` y el prototipo `docs/rediseno/prototipo/Anadir.dc.html`.
- **Objetivo:** restilizar `YoutubeScreen` como el prototipo, sin cambiar su lógica: título y texto de ayuda, etiqueta visible sobre el campo, campo en píldora con «Pegar» o «Borrar» dentro, tarjeta de vista previa, selector «Guardar en», botón blanco de descarga y una cola con progreso de color acento.

## Contexto (por qué)

- `lib/screens/youtube_screen.dart` (~700 líneas) ya hace todo:
  - analizar el enlace (`service.analyze…`) y mostrar la vista previa (canción o playlist);
  - elegir la carpeta destino («Guardar en», `DropdownButton<String>`);
  - descargar o añadir a la cola;
  - mostrar el progreso, cancelar, reintentar las fallidas y la cola de descargas (estados «En espera», «Descargando…», terminada).
  
  Usa colores sueltos y algunos `AppTheme.*` viejos. **Solo cambia la presentación.**
- `test/youtube_screen_test.dart` depende de estos textos y widgets, que **deben seguir existiendo** tal cual:
  - textos: `'Añadir música'`, `'Analizar enlace'`, `'Guardar en'`, `'Descargar canción'`, `'Descargando • 5/16'`, `'31%'`, `'Cancelar esta descarga'`, `'Cola de descargas'`, `'En espera'`, `'Descargada en tu biblioteca'` y `'Pega otro enlace para descargar más.'`;
  - tooltip `'Quitar de la cola'`;
  - widgets: el primer `FilledButton` es el de analizar, un `TextField` y un `DropdownButton<String>`.
- La pantalla será la pestaña «Añadir» de la barra inferior nueva (otro agente). Debe dejar espacio abajo para el mini reproductor: conserva o añade un relleno inferior de 80 a 140.

## Archivos permitidos

- `lib/screens/youtube_screen.dart`
- `test/youtube_screen_test.dart` (solo para **añadir** pruebas; no cambies ni borres las existentes)

## Qué hacer

1. Sigue `Anadir.dc.html`:
   - **Cabecera:** «Añadir música» con `AppTheme.titleLarge` y debajo «Pega un enlace de YouTube. La canción o la playlist queda en tu biblioteca, sin conexión.» con `itemSubtitle`.
   - **Etiqueta** «Enlace de YouTube» (`label`) **encima** del campo, visible siempre (no solo como placeholder).
   - **Campo:**
     - píldora de alto 52, radio 26, fondo `surfaceHigh`, icono `link` en `textSecondary`;
     - placeholder `youtube.com/watch?v=…` en `textMuted`;
     - **dentro**, a la derecha: con el campo vacío, un botón blanco «Pegar» (icono `content_paste`) con la lógica de pegado actual; con texto, un botón «Borrar enlace» (tooltip, icono `close`).
   - **Botón «Analizar enlace»:** sigue siendo el primer `FilledButton`. Con el estilo del prototipo y el estado de carga actual («Analizando…»).
   - **Vista previa:** tarjeta `AppTheme.surface`, radio 16, padding 16. Dentro:
     - miniatura de 56 (radio 6), título `itemTitle` y tipo/conteo `itemSubtitle`;
     - debajo, «Guardar en» (`label`) y el `DropdownButton<String>` dentro de una caja de alto 48, radio 12, fondo `surfaceHigh`, borde `outline` e icono de carpeta;
     - el botón principal («Descargar canción» / «Descargar playlist» / «Añadir a la cola»): `FilledButton` blanco con texto negro, alto 48, radio 24, icono de descarga.
   - **Progreso de la descarga activa:** barra en `AppTheme.accent` sobre `outline`, alto 4, radio 2. Conserva los textos de estado y el porcentaje.
   - **«Cola de descargas»:** título con `itemTitle` y «Limpiar terminadas» como `TextButton` en `textSecondary`. Cada fila:
     - miniatura 48 (o icono), título, estado `itemSubtitle`;
     - una barra de progreso de acento si se descarga;
     - el icono de estado (`hourglass_empty` en espera, `check_circle` terminada) o el botón de quitar con su tooltip actual.
   - **Estado vacío** («Tu música, sin conexión»): icono y textos con tokens, dentro de una tarjeta `surface`.
2. Reemplaza cada `Color(0x…)`, `fontSize:` y radio suelto por `AppTheme.*`. Los botones de solo icono llevan `tooltip`. Áreas táctiles de 44 a 48 como mínimo.
3. Añade a `test/youtube_screen_test.dart` una prueba: con el campo vacío se ve «Pegar» y la etiqueta «Enlace de YouTube»; al escribir un enlace aparece el tooltip «Borrar enlace», y al tocarlo el campo queda vacío.

## Criterios de aceptación

- [ ] Las pruebas existentes de `test/youtube_screen_test.dart` no se modificaron (`git diff integracion/rediseno -- test/youtube_screen_test.dart` solo **añade** líneas).
- [ ] `grep -n "Color(0x\|fontSize:" lib/screens/youtube_screen.dart` no devuelve nada.
- [ ] `grep -n "Enlace de YouTube" lib/screens/youtube_screen.dart` aparece como etiqueta (un `Text` fuera del `hintText`).
- [ ] La lógica de `YoutubeDownloadService` no cambió (en el diff solo hay cambios de presentación).
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el entorno real (lo hace el humano)

Pegar un enlace de una canción y otro de una playlist, analizarlos, elegir la carpeta y descargar. Ver la cola con la barra rosa, cancelar una descarga y limpiar las terminadas.
