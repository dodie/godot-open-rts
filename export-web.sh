#!/usr/bin/env sh

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GODOT_BIN=${GODOT_BIN:-godot}
EXPORT_DIR="$PROJECT_ROOT/build/web"
EXPORT_PATH="$EXPORT_DIR/openrts.html"
BUILD_INFO_PATH="$PROJECT_ROOT/source/BuildInfo.gd"
WEB_UPDATE_SCRIPT="$PROJECT_ROOT/web/update-service-worker.js"

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
BUILD_ID=${GITHUB_SHA:-$(date -u '+%Y%m%dT%H%M%SZ')}
case "$BUILD_ID" in
	*[!A-Za-z0-9._-]*)
		printf 'Invalid build ID: %s\n' "$BUILD_ID" >&2
		exit 1
		;;
esac
printf 'class_name BuildInfo\n\nconst BUILD_TIMESTAMP = "%s"\n' "$BUILD_TIMESTAMP" > "$BUILD_INFO_PATH"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-release Web "$EXPORT_PATH"

# Godot's PWA worker is cache-first, so a cached copy of the HTML cannot notice
# a deployment by itself. The updater compares this build ID with an explicitly
# uncached version file and activates Godot's newly installed worker when needed.
printf '{"build":"%s"}\n' "$BUILD_ID" > "$EXPORT_DIR/version.json"
cp "$WEB_UPDATE_SCRIPT" "$EXPORT_DIR/update-service-worker.js"

UPDATE_TAG="\t<script src=\"update-service-worker.js\" data-build=\"$BUILD_ID\"></script>"
awk -v update_tag="$UPDATE_TAG" '
	/<\/head>/ { print update_tag }
	{ print }
' "$EXPORT_PATH" > "$EXPORT_PATH.tmp"
mv "$EXPORT_PATH.tmp" "$EXPORT_PATH"
