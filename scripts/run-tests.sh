#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
if ! command -v godot >/dev/null 2>&1; then
    echo 'Error: godot must be installed and available on PATH.' >&2
    exit 1
fi

# A scene owns its companion script; running both would execute the test twice.
mapfile -d '' tests < <(find . -type d \( -name .git -o -name .godot \) -prune -o \
    -type f \( -name '*_test.tscn' -o -name '*_test.gd' \) -print0 | sort -z)
count=0
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT
for test in "${tests[@]}"; do
    if [[ "$test" == *.gd && -f "${test%.gd}.tscn" ]]; then
        continue
    fi
    echo "Running $test"
    args=(--headless --path "$project_root")
    if [[ "$test" == *.gd ]]; then
        args+=(--script "$test")
    else
        args+=("$test")
    fi
    # Godot can print script errors while still returning zero.
    if ! timeout 60s godot "${args[@]}" >"$log_file" 2>&1; then
        cat "$log_file"
        echo "Error: $test failed or exceeded 60 seconds." >&2
        exit 1
    fi
    cat "$log_file"
    if grep -Eq '(^|[[:space:]])(SCRIPT ERROR|ERROR):' "$log_file"; then
        echo "Error: $test reported a Godot error." >&2
        exit 1
    fi
    count=$((count + 1))
done
echo "Passed: $count test(s)."
