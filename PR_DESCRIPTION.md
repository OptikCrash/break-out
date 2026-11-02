Closes #23

Adds a title screen (`TitleScreen.tscn` + `title.gd`) and makes it `run/main_scene`, so F5 and
web builds open on it. Space, Enter, gamepad A (all through Godot's built-in `ui_accept` action)
or a left click start the game. Nothing in `main.tscn`, the HUD or restart (R) changed.

## The Godot idea: `change_scene_to_file`

A `SceneTree` has one **current scene**. `get_tree().change_scene_to_file("res://main.tscn")`
frees the title screen and loads `main.tscn` in its place. The swap waits until the end of the
frame, so the code that asked for it finishes running first. This is the same approach
`main.gd` already uses for restart (`reload_current_scene()`, which loads a new copy of the
current scene). Pause and game-over will follow the same pattern, with "Back to Title" being
`get_tree().change_scene_to_file("res://TitleScreen.tscn")`.

**Alternative considered: an autoloaded scene manager.** An autoload is a node Godot keeps
alive across scene changes. It would be the place for fade transitions, loading screens or
state that must outlive a scene. This project has none of those yet, and a manager would add a
global plus an extra layer around a single engine call. Plain `change_scene_to_file` is easy to
read and easy to swap out later. If fades or shared state are added, we can wrap the same call
in an autoload without changing the scenes.

## A subtlety: one Space press, two meanings

Space is both `ui_accept` (start) and `launch`. The new headless test showed that swapping
scenes as soon as Space was pressed made the ball launch the moment the game appeared. Godot
treats a press as "just pressed" during the **next physics step**, and the deferred scene swap
runs before that step, so the new ball sees the same press. `title.gd` waits for
`get_tree().physics_frame` before swapping. That lets the step pass while the title screen is
still the current scene, and the ball starts resting on the paddle as before. Handling it here
keeps the fix in presentation code; the alternative was making `ball.gd` ignore launch input on
its first frame, which would change gameplay code for a menu problem.

## Layout and input details

- The root `Control`, the black `Background` ColorRect and a `CenterContainer` all use Full Rect
  anchors, so the text stays centred at 1920x1080 and when the window is resized (stretch mode
  is `canvas_items`). There are no pixel offsets.
- Clicks are read in `_unhandled_input`. Every node has `mouse_filter = Ignore` so the GUI does
  not consume the click before it reaches the script.
- A `starting` flag stops a Space press and a click in the same frame from asking for the scene
  change twice.
- No art: default font at larger sizes, white on black like the play area, and the controls
  hint in light grey (still high contrast).

## Tests

`tests/title_screen_test.gd` (headless, no addon) checks:
- `run/main_scene` is the title screen;
- the text block is centred and every label fits on screen at 1920x1080 and 1280x720;
- Space, Enter and a left click each load `main.tscn`, and the ball is not launched afterwards.
  The test failed before the `physics_frame` wait was added.

Validation: headless editor import gave no errors, and all six `tests/*_test.gd` passed when run
one by one with `godot --headless --path . --script ...` and checked for `ERROR:` output.
`scripts/run-tests.sh` and `scripts/test-runner.sh` were not run directly in this environment
because shell scripts needed permission I didn't have; CI runs both. There is no display here, so
nobody has yet looked at the screen in a real window, and gamepad A is untested (it comes from
Godot's default `ui_accept` mapping).

README now says F5 (or F6 on `TitleScreen.tscn`) starts at the title screen. AGENTS.md gains a
short "Scene flow" section on this pattern and the one-press-two-actions trap.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
