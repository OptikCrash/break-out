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
- Draft the PR body in `PR_DESCRIPTION.md` at the repo root. `.gitignore` lists
  `/PR_DESCRIPTION.md`, so it stays a local file; don't force-add it.

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

## Scene flow

- `TitleScreen.tscn` is `run/main_scene`; screens move between scenes with
  `get_tree().change_scene_to_file(...)`. "Back to Title" is
  `change_scene_to_file("res://TitleScreen.tscn")`.
- An action pressed counts as "just pressed" during the next physics step, and the scene swap
  is applied before that step. If the key that leaves a screen is also a gameplay action
  (Space is `ui_accept` and `launch`), `await get_tree().physics_frame` before swapping, or the
  new scene will act on the same press. `tests/title_screen_test.gd` covers this.
- Pausing: `get_tree().paused` belongs to the SceneTree, so it stays on across
  `reload_current_scene()` / `change_scene_to_file()`. Unpause before you swap scenes. Paused nodes
  get no input either, so the key that unpauses must be read by a node with
  `process_mode = Always` (`PauseScreen.tscn`), not by `main.gd`. A hidden CanvasLayer still
  receives `_unhandled_input`, so check `visible` first.
- `Button` emits `pressed` on release, so the press has already stopped being "just pressed" and
  a Space press on a menu button can't also launch the ball. The `physics_frame` wait in `title.gd`
  is only needed because it acts on the raw press.
- Godot's built-in `ui_accept` has no gamepad button (only Enter, Keypad Enter, Space), so a
  focused `Button` can't be pressed by a pad. `project.godot` overrides `ui_accept` to add
  joypad A. An override replaces the built-in event list, so keep the three keys in it.
  Arrows/D-pad already move focus through `ui_left`/`ui_right`/`ui_up`/`ui_down`.
- `Button`s fire on release, for keyboard and gamepad as well as the mouse, so leaving a scene
  from a button doesn't hand a fresh "just pressed" Space to the next scene. A press that
  comes from `_unhandled_input`, like the title screen's, still needs the physics-frame wait.
- A full-screen Control that reads clicks in `_unhandled_input` needs `mouse_filter = Ignore`
  on itself and on any ColorRect/container over it, or the GUI eats the click first.
- Input actions (`Input.is_action_just_pressed("launch")`) are updated before the GUI sees an
  event, so a mouse button bound to an action works even over ColorRects. Raw mouse motion is
  not: `paddle.gd` reads it in `_input` because the play field's ColorRects would mark it handled.
- "Most recent input wins" has to be decided from events (`event.is_action_pressed()`, which
  skips echoes), not from polled held state (`Input.get_axis()`), or a held key overrides
  every newer mouse move.
- Headless runs start with a 64x64 root window, and `canvas_items` stretch scales event positions
  to match. Tests that send mouse positions set `root.size = Vector2i(1920, 1080)` first.

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

- In Godot 4.7.2, the built-in `ui_accept` and `ui_cancel` bindings here have no
  joypad buttons. Keep explicit A/B bindings in `project.godot` alongside their
  keyboard events; d-pad focus alone does not prove a gamepad can activate a menu.
