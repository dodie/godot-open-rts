#!/usr/bin/env sh

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GODOT_BIN=${GODOT_BIN:-godot}
EXPORT_DIR="$PROJECT_ROOT/build/web"
EXPORT_PATH="$EXPORT_DIR/openrts.html"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	printf 'Godot executable not found: %s\n' "$GODOT_BIN" >&2
	printf 'Install Godot or set GODOT_BIN to its executable path.\n' >&2
	exit 127
fi

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-release Web "$EXPORT_PATH"
