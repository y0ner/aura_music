# Contribuir a Aura Music

Gracias por tu interés en contribuir a **Aura Music**. Este documento resume cómo preparar el entorno, las comprobaciones obligatorias antes de abrir un Pull Request y las reglas de diseño y estilo del proyecto.

## Preparar el entorno

### Requisitos

- Flutter `3.47+` y Dart `3.13+`
- Android SDK (para ejecutar o compilar en Android)
- GStreamer (`gst-play-1.0`) en Linux de escritorio

### Comandos de compilación y ejecución

```bash
git clone https://github.com/y0ner/aura_music.git
cd aura_music
flutter pub get
```

Usa `./run.sh` para ejecutar y compilar:

- `./run.sh linux` — Ejecuta la app en Linux de escritorio (configura los códecs locales de GStreamer si hacen falta mediante `tool/setup_linux_audio.sh`).
- `./run.sh android` — Ejecuta la app en un dispositivo Android conectado por `adb`.
- `./run.sh build-apk` — Compila la APK release (`build/app/outputs/flutter-apk/app-release.apk`).

## Comprobaciones obligatorias antes del PR

Todo cambio debe pasar sin advertencias ni errores antes de abrir un Pull Request:

```bash
./run.sh analyze   # Ejecuta: flutter analyze --no-pub
./run.sh test      # Ejecuta: flutter test
```

- Toda lógica nueva en servicios, modelos o utilidades debe incluir pruebas en `test/`.
- No debilites pruebas existentes ni ocultes widgets para forzar que pasen.

## Reglas de estilo y código

1. **Tokens de diseño (`AppTheme`):** Usa exclusivamente los tokens definidos en `lib/theme/app_theme.dart` (`AppTheme.*`). No escribas colores `Color(0x...)`, tamaños `fontSize:` ni radios sueltos directamente en pantallas o widgets. Revisa la guía visual en `docs/rediseno/README.md`.
2. **Idioma:** Los textos visibles para el usuario, los comentarios en el código y los mensajes de commit van en **español**.
3. **Artista desconocido:** Nunca muestres el texto `"Artista desconocido"` en la interfaz; usa `song.hasKnownArtist` para decidir qué mostrar en el subtítulo.
4. **Identidad propia:** No reintroduzcas elementos de marca de YouTube Music ni colores rojos de marca (`#FF0000` / `#FF0033`).
5. **Privacidad:** No envíes datos de uso ni analíticas a servicios externos.
6. **Código completo:** Sin marcas de trabajo inconcluso (`FIXME` o tareas pendientes), sin datos simulados en producción y sin bloques `catch (_) {}` vacíos (registra siempre el motivo con `debugPrint`).
7. **Diff limpio:** No formatees archivos completos que no hayas modificado.

## Flujo de Pull Requests

1. Crea una rama descriptiva a partir de la rama de integración activa.
2. Haz commits pequeños y claros en español.
3. Verifica `./run.sh analyze` y `./run.sh test`.
4. Completa la plantilla de Pull Request (`.github/pull_request_template.md`) indicando qué cambia y qué se debe probar en dispositivo real (Android / Linux).

## Cómo reportar errores

Abre un issue en [GitHub Issues](https://github.com/y0ner/aura_music/issues) incluyendo:

- **Plataforma y versión:** modelo de celular y versión de Android (o distribución Linux).
- **Versión de Aura Music:** por ejemplo `1.0.0`.
- **Pasos para reproducir el problema** y qué esperabas que ocurriera.
- **Registros o capturas:** salida de terminal (`flutter run` / `adb logcat` / `flutter analyze --no-pub`) sin rutas personales sensibles.
