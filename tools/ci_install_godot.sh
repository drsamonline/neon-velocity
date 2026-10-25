#!/usr/bin/env bash
# Install a headless Godot build (and optionally the export templates) on a
# Debian runner. Usage: tools/ci_install_godot.sh [version] [templates:0|1]
set -euo pipefail

VERSION="${1:-4.3}"
WITH_TEMPLATES="${2:-0}"
BIN="Godot_v${VERSION}-stable_linux.x86_64"

wget -q "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/${BIN}.zip"
unzip -q "${BIN}.zip"
mv "${BIN}" /usr/local/bin/godot
chmod +x /usr/local/bin/godot

if [ "${WITH_TEMPLATES}" = "1" ]; then
  TPL="Godot_v${VERSION}-stable_export_templates.tpz"
  wget -q "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/${TPL}"
  mkdir -p "${HOME}/.local/share/godot/export_templates"
  unzip -q "${TPL}"
  mv templates/* "${HOME}/.local/share/godot/export_templates/${VERSION}.stable/"
  rmdir templates
fi

godot --version
