#!/usr/bin/env bash
# Install a headless Godot build (and optionally the export templates).
# Usage: bash tools/ci_install_godot.sh [version] [templates:0|1]
#
# Called with `bash` on purpose: the repository may be checked out without the
# executable bit, which would otherwise fail with "Permission denied".
set -euo pipefail

VERSION="${1:-4.3}"
WITH_TEMPLATES="${2:-0}"
BIN="Godot_v${VERSION}-stable_linux.x86_64"

wget -q "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/${BIN}.zip"
unzip -q "${BIN}.zip"

# Prefer /usr/local/bin, fall back to a user directory when it is not writable.
DEST="/usr/local/bin"
if [ ! -w "${DEST}" ]; then
  DEST="${HOME}/.local/bin"
  mkdir -p "${DEST}"
fi
mv "${BIN}" "${DEST}/godot"
chmod +x "${DEST}/godot"
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "${DEST}" >> "${GITHUB_PATH}"
fi
export PATH="${DEST}:${PATH}"

if [ "${WITH_TEMPLATES}" = "1" ]; then
  TPL="Godot_v${VERSION}-stable_export_templates.tpz"
  wget -q "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/${TPL}"
  mkdir -p "${HOME}/.local/share/godot/export_templates"
  unzip -q "${TPL}"
  mv templates/* "${HOME}/.local/share/godot/export_templates/${VERSION}.stable/"
  rm -rf templates
fi

godot --version
