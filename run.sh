#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Aura Music · Script de desarrollo y ejecución
# Uso:
#   ./run.sh                  (Ejecuta en Linux desktop por defecto)
#   ./run.sh linux            (Ejecuta en Linux desktop)
#   ./run.sh android          (Ejecuta en dispositivo Android conectado)
#   ./run.sh build-apk        (Compila el APK instalable para celular)
# ─────────────────────────────────────────────────────────────
set -euo pipefail

# Priorizar JDK 17 si está instalado o el JBR de Android Studio
if [ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
  export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
elif [ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]; then
  export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
else
  export JAVA_HOME="${JAVA_HOME:-/home/yoner/.local/share/flatpak/app/com.google.AndroidStudio/current/active/files/extra/jbr}"
fi

export ANDROID_HOME="${ANDROID_HOME:-/home/yoner/Android/Sdk}"
export PATH="$JAVA_HOME/bin:$HOME/flutter/bin:$ANDROID_HOME/platform-tools:$PATH"

ACTION="${1:-linux}"

# Opción para compilar el APK directamente
if [ "$ACTION" = "build-apk" ] || [ "$ACTION" = "apk" ]; then
  echo "▶ Compilando APK de Aura Music para Android..."
  flutter build apk --release --android-skip-build-dependency-validation
  echo "✔ APK generado con éxito en: build/app/outputs/flutter-apk/app-release.apk"
  exit 0
fi

DEVICE="$ACTION"

if [ "$DEVICE" = "linux" ]; then
  if ! gst-inspect-1.0 avdec_aac >/dev/null 2>&1; then
    bash tool/setup_linux_audio.sh
  fi
  LOCAL_PLUGIN_DIR="$(find "$PWD/.dart_tool/linux-codecs/usr/lib" -name libgstlibav.so -printf '%h\n' -quit 2>/dev/null || true)"
  if [ -n "$LOCAL_PLUGIN_DIR" ]; then
    export GST_PLUGIN_PATH="$LOCAL_PLUGIN_DIR${GST_PLUGIN_PATH:+:$GST_PLUGIN_PATH}"
  fi
fi

# Si se especifica "android", resolver el ID del dispositivo Android conectado o emulador
if [ "$DEVICE" = "android" ]; then
  DETECTED_DEV=$(python3 -c "
import json, subprocess
try:
    devs = json.loads(subprocess.check_output(['flutter', 'devices', '--machine']))
    android_dev = next((d['id'] for d in devs if 'android' in d.get('targetPlatform', '')), 'android')
    print(android_dev)
except Exception:
    print('android')
" 2>/dev/null || echo "android")
  DEVICE="$DETECTED_DEV"
fi

EXTRA_FLAGS="--android-skip-build-dependency-validation"

echo "▶ Ejecutando Aura Music en $DEVICE..."
flutter run -d "$DEVICE" $EXTRA_FLAGS
