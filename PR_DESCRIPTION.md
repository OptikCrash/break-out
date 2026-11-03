Closes #24

Adds a pause menu. While the ball is in play, Escape or gamepad Start (the new `pause` input
action) freezes the game and shows **Resume**, **Restart** and **Back to Title**. Each one works
with a mouse click, with Tab/arrow keys + Enter/Space, or with the gamepad d-pad + A. Resume has
focus when the menu opens. Escape, Start or gamepad B (`ui_cancel`) close it again.

## The Godot idea: `SceneTree.paused` and `process_mode`

`get_tree().paused = true` stops `_process`, `_physics_process` and input for every node whose
`process_mode` is **Inherit/Pausable**, which is the default. The ball and paddle stop moving
without any change to their scripts. A node set to **Always** keeps running, and so do its
children that use Inherit.
`PauseScreen.tscn` is a `CanvasLayer` with `process_mode = Always` set on its own root, so its
buttons and its Escape handler keep working while everything else is frozen.

This also decides where the pause key is read:
- `main.gd` opens the menu. Its `_unhandled_input` only acts when `can_pause()` is true:
  `ball.launched and not reset_ready`. That rules out the ball resting on the paddle (before
  launch, or after losing a life) and the game-over/win message.
- `pause_screen.gd` closes it. Once paused, `main.gd` gets no input, so it couldn't unpause even
  if it tried.

`paused` belongs to the tree, not the scene, so it would carry over into the next scene.
Restart and Back to Title therefore unpause first, then call the same `reload_current_scene()` /
`change_scene_to_file("res://TitleScreen.tscn")` the game already uses.

**Alternatives considered**
- *Toggle with `Input.is_action_just_pressed("pause")` in `main.gd`'s `_process`.* While paused
  `_process` doesn't run, so it could open the menu but never close it. Making `Main` Always
  would un-freeze its restart check and everything else under it.
- *Put the toggle in an autoload.* An autoload could handle pausing anywhere, but pausing is
  only allowed in one scene, and the rule for it (`can_pause()`) uses gameplay state that
  `main.gd` already has.
- *Build the menu into `HUD.tscn`.* The HUD is just labels, and keeping the menu separate means
  it gets its own `process_mode` and its own test. The menu is on layer 10, above the HUD
  (layer 1).

## Input bindings

Godot 4.7.2's default `ui_accept` and `ui_cancel` events in this project only include
keyboard keys. Explicit A/B bindings preserve Enter, keypad Enter, Space and Escape
and let standard Button focus handle gamepad activation and cancellation. Keeping
this in the Input Map avoids custom per-button gamepad handling. Tests send actual
joypad events for Start, d-pad navigation, A activation and B cancellation.

Buttons emit `pressed` on release, so Space on Restart does not launch the fresh
ball. The regression test checks this without adding a scene-transition delay.

## Layout and look

- The `Dim` overlay (black at 75% alpha) and a `CenterContainer` use Full Rect anchors, so the
  menu stays centred at 1920x1080 and after a resize. There are no pixel offsets.
- It uses the same default font and size scale as the title screen: a 96 px "PAUSED" heading,
  48 px buttons at least 480 px wide (big click/focus targets), and a light-grey hint line.
  There is no new art. The buttons use Godot's default theme, which includes a visible focus
  outline for keyboard and gamepad players.

## Tests

`tests/pause_screen_test.gd` (headless SceneTree, no addon) checks:
- `pause` is bound to Escape and to joypad Start;
- a bare `PauseScreen.tscn` has its script and `process_mode = Always` on its own root, and
  starts hidden;
- Escape does nothing before launch or under the game-over message;
- during play, Escape pauses, shows the menu and focuses Resume. Ball and paddle don't move
  while paused (even with D held), and R does nothing;
- the menu is centred and every item fits on screen at 1920x1080 and 1280x720;
- Resume works by Escape, Enter and click, and the ball moves again afterwards;
- Restart works by arrow down + Enter, arrow down + Space and click, and loads a fresh
  `main.tscn` with the ball not launched;
- Back to Title works by arrow down x2 + Enter and by click;
- every exit leaves the tree unpaused.

I checked that the test catches real breakage: removing `process_mode = Always` makes every
resume check fail.

Validation: Godot 4.7.2 headless editor import, `scripts/test-runner.sh` and
`scripts/run-tests.sh` all pass without unexpected Godot errors. The runner's own
regression checks deliberately exercise failing fixtures. The pause tests also
cover Tab navigation, gamepad activation of all three options, Start/B resume,
and ignoring held Escape repeat events.

No display or physical controller is available here, so visual inspection and
physical gamepad testing remain unverified.
