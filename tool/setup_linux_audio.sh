#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if gst-inspect-1.0 avdec_aac >/dev/null 2>&1; then
  echo 'El decodificador AAC ya está disponible.'
  exit 0
fi
codec_dir="$PWD/.dart_tool/linux-codecs"
mkdir -p "$codec_dir"
cd "$codec_dir"
apt-get download gstreamer1.0-libav
for package in gstreamer1.0-libav_*.deb; do
  dpkg-deb -x "$package" .
done
plugin_dir="$(find "$codec_dir/usr/lib" -name libgstlibav.so -printf '%h\n' -quit)"
if [ -z "$plugin_dir" ]; then
  echo 'No se encontró el plugin AAC.' >&2
  exit 1
fi
GST_PLUGIN_PATH="$plugin_dir${GST_PLUGIN_PATH:+:$GST_PLUGIN_PATH}" gst-inspect-1.0 avdec_aac >/dev/null
echo "Decodificador AAC local listo: $plugin_dir"
