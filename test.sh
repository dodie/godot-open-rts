#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if command -v godot4 >/dev/null 2>&1; then
	Godot=godot4
elif command -v godot >/dev/null 2>&1; then
	Godot=godot
else
	echo "Godot executable not found (expected godot4 or godot)." >&2
	exit 127
fi

mapfile -d '' test_files < <(
	find "$project_dir/tests" \
		-path "$project_dir/tests/manual" -prune -o \
		-type f -name '*Test.gd' -print0 | sort -z
)

if ((${#test_files[@]} == 0)); then
	echo "No non-manual tests found." >&2
	exit 1
fi

for test_file in "${test_files[@]}"; do
	echo "Running ${test_file#"$project_dir/"}"
	"$Godot" --headless --path "$project_dir" --script "$test_file"
done
