#!/usr/bin/env bash
# Exercise the runner with real headless Godot in an isolated, disposable project.
set -euo pipefail
source_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/tests with spaces"
cp "$source_root/scripts/run-tests.sh" "$fixture/scripts/"
printf 'config_version=5\n' > "$fixture/project.godot"
runner="$fixture/scripts/run-tests.sh"
"$runner" | grep -F 'Passed: 0 test(s).'
cat > "$fixture/tests with spaces/script_test.gd" <<'GDSCRIPT'
extends SceneTree
func _initialize() -> void:
    quit(0)
GDSCRIPT
cat > "$fixture/tests with spaces/scene_test.gd" <<'GDSCRIPT'
extends Node
func _ready() -> void:
    get_tree().quit(0)
GDSCRIPT
cat > "$fixture/tests with spaces/scene_test.tscn" <<'SCENE'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tests with spaces/scene_test.gd" id="1"]
[node name="Test" type="Node"]
script = ExtResource("1")
SCENE
# Invoking from another directory also checks root resolution.
(cd /tmp && "$runner") | grep -F 'Passed: 2 test(s).'
cat > "$fixture/failure_test.gd" <<'GDSCRIPT'
extends SceneTree
func _initialize() -> void:
    quit(1)
GDSCRIPT
if "$runner" > "$fixture/output" 2>&1; then
    echo 'Error: runner accepted a failing test.' >&2
    exit 1
fi
grep -F 'failure_test.gd failed' "$fixture/output"
cat > "$fixture/failure_test.gd" <<'GDSCRIPT'
extends SceneTree
func _initialize() -> void:
    push_error("Intentional runner regression fixture")
    quit(0)
GDSCRIPT
if "$runner" > "$fixture/output" 2>&1; then
    echo 'Error: runner accepted a Godot error with exit code zero.' >&2
    exit 1
fi
grep -F 'failure_test.gd reported a Godot error.' "$fixture/output"
echo 'Test runner regression checks passed.'
