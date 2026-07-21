#!/usr/bin/env sh

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GODOT_BIN=${GODOT_BIN:-godot}
EXPORT_DIR="$PROJECT_ROOT/build/web"
EXPORT_PATH="$EXPORT_DIR/openrts.html"
BUILD_INFO_PATH="$PROJECT_ROOT/source/BuildInfo.gd"

cleanup() {
	rm -f "$BUILD_INFO_PATH" "$BUILD_INFO_PATH.uid"
}

trap cleanup EXIT INT TERM

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	printf 'Godot executable not found: %s\n' "$GODOT_BIN" >&2
	printf 'Install Godot or set GODOT_BIN to its executable path.\n' >&2
	exit 127
fi

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
BUILD_TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
printf 'class_name BuildInfo\n\nconst BUILD_TIMESTAMP = "%s"\n' "$BUILD_TIMESTAMP" > "$BUILD_INFO_PATH"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-release Web "$EXPORT_PATH"
