# Builder notes

- Use Godot 4.7.2, with the project at the repository root.
- Run `godot --headless --path . --editor --import`, then
  `scripts/test-runner.sh` and `scripts/run-tests.sh`. No addon test framework.
- Godot may return zero after reporting a script/import error. Check output for
  `ERROR:` / `SCRIPT ERROR:` as CI and the runner do.
- Tests must explicitly quit; scripts extend SceneTree/MainLoop, scenes quit via
  their tree. A `*_test.tscn` owns the matching `*_test.gd`, which is not run twice.
- Commit new script `.uid` files, preserve scene UIDs, and never commit `.godot/`.
- `queue_free()` marks a brick immediately but deletes it at frame end. Check the
  deletion flag before emitting `brick_broken`; duplicate-hit tests must repeat
  the hit before yielding a frame so they exercise that window.
- PR descriptions explain the Godot concept and why the approach was chosen,
  including alternatives considered. For CI, editor import builds the resource
  cache before standalone headless tests; plain processes avoid an addon dependency.

- Winning disables ball physics immediately after `reset()`. Reset must place the ball
  on the paddle synchronously; waiting for `_physics_process()` leaves it in flight.

Gotchas learned while working on break-out. `PLAN.md` and `GLOSSARY.md` stay the sources of truth.

- Ball direction rules live in `ball_rules.gd`, a plain `RefCounted` script that
  headless tests can preload without a scene. Seed the random generator before
  each call when comparing launch and center-hit behavior.

## Scenes

- Attach a scene's script to that scene's own root (in its `.tscn`), not on the instance in
  the parent scene. An instance-level `script =` line in `main.tscn` is an override that a bare
  `instantiate()` of the child scene won't have. `SceneState` (`load(...).get_state()`) lets a
  headless test check for such overrides, as `tests/hud_script_test.gd` does.

## UI layout

- Some scenes were built when the window was Godot's default 1152x648. Controls placed with
  plain `offset_*` values (no anchors) still have sizes from that window, so they are not
  centred in the real 1920x1080 viewport. To centre something, anchor it (for example with the
  Full Rect preset) instead of typing in new pixel offsets.
- Controls directly under a `CanvasLayer` (such as `Hud`) are anchored to the viewport, not
  to a parent Control.
- `project.godot` uses `window/stretch/mode="canvas_items"`, so the logical viewport stays
  1920x1080 when the window is resized and the canvas is scaled. In headless checks, compare
  against `get_viewport().get_visible_rect()`, not the window size.
