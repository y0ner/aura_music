# Manual operativo para agentes de IA — Aura Music

Rige cómo trabajan los agentes de IA en este repositorio. Si algo de este
archivo choca con una instrucción de un brief, gana este archivo.

## 1. Roles

| Rol | Quién | Qué hace |
|---|---|---|
| **Humano** | Yoner | Aprueba cada oleada, autoriza los merges y prueba en su Xiaomi (Android 16) y en Linux. |
| **Agente jefe** | Claude Code | Escribe los briefs, crea ramas y *worktrees*, revisa, corre pruebas y builds, abre los PR y fusiona a `integracion/rediseno` con autorización. |
| **Agentes trabajadores** | Gemini (CLI `agy`) | Implementan **una tarea por rama**, en su propio *worktree*, tocando solo los archivos de su brief. |

## 2. Flujo (una tarea = una rama = un PR)

1. El jefe crea el *worktree* desde `integracion/rediseno`.
2. El trabajador recibe `docs/agentes/briefs/<id>.md` y trabaja **solo** en su *worktree*.
3. El trabajador hace commits pequeños y **no hace push**.
4. El jefe revisa (sección 4), hace push y abre el PR contra `integracion/rediseno`.
5. Si algo falla, el jefe devuelve el error exacto con archivo y línea; el trabajador corrige en la misma rama.
6. Con la revisión aprobada, el jefe fusiona con *squash* a `integracion/rediseno`.
7. La rama principal solo recibe cambios tras la prueba del humano.

## 3. Reglas para los trabajadores

1. **Aislamiento:** solo los "Archivos permitidos" del brief. Si hace falta otro, te detienes y lo reportas.
2. **Sin merge, push, rebase ni cambio de rama.**
3. **Solo análisis estático:** puedes correr `flutter analyze --no-pub`; **no** `flutter test`, `flutter build` ni `flutter pub get` (los corre el jefe, uno a la vez).
4. **Sin dependencias nuevas** (el *sandbox* no tiene red). Las disponibles están en `pubspec.yaml`; su código fuente, en `~/.pub-cache/hosted/pub.dev/` (léelo para no inventar métodos).
5. **Código completo:** sin `TODO`/`FIXME`, métodos vacíos, datos falsos, textos de relleno ni errores silenciados (`catch (_) {}` vacío está prohibido: como mínimo `debugPrint` con el motivo).
6. **Pruebas:** toda lógica nueva (servicios, modelos, utilidades) llega con su prueba en `test/`. Las pruebas de widgets que el brief pida, también.
7. **Diseño:** usa los tokens de `lib/theme/app_theme.dart` (`AppTheme.*`). Nada de `Color(0x...)`, `fontSize:` ni radios sueltos en las pantallas que reescribas. La guía visual está en `docs/rediseno/README.md` y las medidas exactas en `docs/rediseno/prototipo/*.dc.html`.
8. **No hagas trampas con las pruebas:** no escondas textos (opacidad 0, `Offstage`), no fuerces el tema ni debilites una prueba vieja para que pase. Si una prueba existente choca con el diseño nuevo y el brief no te deja tocarla, repórtalo.
9. **No formatees archivos enteros** con `dart format` si no los reescribes: el diff debe mostrar solo tu cambio.
10. **Idioma:** español en comentarios, textos de usuario y mensajes de commit.

### Alcance prohibido

- Volver a usar la marca de YouTube Music (logo «▶ Music», rojo #FF0000/#FF0033 como color de marca, botón «Abrir app»).
- Mostrar «Artista desconocido» en la interfaz (usa `song.hasKnownArtist`).
- Enviar datos del usuario a servicios externos.

## 4. Lista de revisión de cada PR (jefe)

1. **[Aislamiento]** Solo cambió los archivos permitidos.
2. **[Integridad]** Sin `TODO`, simulaciones en producción ni errores silenciados.
3. **[Análisis]** `flutter analyze --no-pub` sin problemas.
4. **[Pruebas]** `flutter test` en verde.
5. **[Criterios]** Cada criterio de aceptación del brief se puede señalar en el diff.
6. **[Entorno real]** El PR dice qué debe probar el humano.
