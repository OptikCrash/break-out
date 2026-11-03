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
- `power_action` mirrors `launch` (Space, pad A, left click), so one press triggers both. Rebind
  them together (`tests/power_action_test.gd` checks they match), and action power-ups read it independently: a launch press may also fire Blaster
  (see the provisional overlap default in GLOSSARY.md).
- Gamepad bindings use `device: -1` (any pad). Godot names buttons by position (Xbox layout):
  `JOY_BUTTON_A` is the bottom face button, Cross on PlayStation. A stick direction is an
  `InputEventJoypadMotion` with `axis_value` -1 or 1; the action's `deadzone` (0.2) filters
  drift, and `Input.get_axis()` returns the analog strength (rescaled past the deadzone), so a
  partial tilt moves the paddle more slowly. In tests, release a stick by sending the same axis with `axis_value = 0.0`.
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
- The Play Area covers x 384-1536, so new HUD panels go in the side gutters (the
  Active Effects panel is anchored top-right) rather than over the bricks.
  `hud.update_effects()` runs every physics frame: update existing rows instead of
  rebuilding them.
- `project.godot` uses `window/stretch/mode="canvas_items"`, so the logical viewport stays
  1920x1080 when the window is resized and the canvas is scaled. In headless checks, compare
  against `get_viewport().get_visible_rect()`, not the window size.

- In Godot 4.7.2, the built-in `ui_accept` and `ui_cancel` bindings here have no
  joypad buttons. Keep explicit A/B bindings in `project.godot` alongside their
  keyboard events; d-pad focus alone does not prove a gamepad can activate a menu.

## Game feel

- Screen shake moves `main.tscn`'s `ScreenShake` Camera2D `offset` only (top-left anchor, so at rest
  it is the identity view). Never shake by moving `PlayArea`: that moves every collision shape.
  The HUD is a CanvasLayer and stays still. `MainBG` reaches 32 px past the viewport so a shake
  never shows the clear colour; keep shake strengths below that.
- Brick bursts hang off `brick.destroyed(at)` (forwarded as `bricks.brick_destroyed`), not
  `brick_broken`, so they need no score data. Add them to `PlayArea`, never `Bricks`:
  completion recounts read `definition` on every `Bricks` child.
- A destroyed brick emits both `broken(points, at)` (point popups) and `destroyed(at)` (bursts);
  `Bricks` relays each one. Score still comes from the ball's `brick_broken`. Hook new
  presentation onto one of these signals rather than adding another emit.

## Level data

- `Level.grid` uses equal-width rows and `.` for holes; spaces are invalid. The parser
  accepts LF/CRLF and one final newline. It validates the whole grid before returning
  cells, so malformed data cannot spawn a partial layout. `#`/`x`/`o`/`?` map to the stable Normal/Reinforced/Indestructible/Mystery definitions in
  `bricks/`. Definition resources are shared: keep remaining hit points on each
  brick instance, never mutate the definition when a brick is hit.
- `brick_broken(points)` emits only on destruction; the brick queues deletion before
  the signal, guarding repeated final hits within the same frame.
- Level progression keeps `main.tscn` alive. Configure `main.levels` for a custom
  sequence (typed arrays in dynamic test fixtures use `game.levels.assign([...])`).
  `main` is the only level owner: `Bricks` has no default level and builds nothing until
  `load_level()` is called, so a bare `bricks.gd` test node must call it explicitly.
  `Bricks.load_level()` detaches old children before queuing deletion so the next
  level's destructible count cannot include the previous layout.
- Level validation rejects grids without `#`, `x` or `?` (including all-hole grids),
  before replacing a layout; every level needs a destructible brick to trigger completion.

## Capsules and effects

- `effects/*.tres` own stable effect IDs and tuning. `effect_rules.gd` owns the uniform
  pool, pure timers, scoring and width calculation; shared resources are never mutated.
- Capsule Area2Ds monitor paddle bodies (layer 2) and Death Zone areas (layer 16).
  Death Zone still monitors only balls (layer 4), so a missed capsule cannot cost a life.
- Brick drop signals carry global brick-center positions. Defer capsule creation out of
  physics queries and recheck end-of-level state before adding the Area2D: the final
  brick can finish a level before that deferred call runs.
- Paddle width changes scale its shape node and existing sprite, leaving the shared shape
  resource untouched. Ball bounce offsets divide by the current paddle half-width.
- To assert a deferred capsule's exact spawn position, disable its physics from the
  SceneTree `node_added` signal before awaiting `process_frame`; otherwise a physics
  step can move it before the assertion. Disconnect the test callback afterwards.
- Capsule drops use the brick collision shape's global center, so layout/shape offsets
  do not need a second hard-coded center in the drop logic.

## Ball lifecycle

- `main.get_balls()` returns live balls owned by that gameplay scene. Future ball
  creation should use `main.add_ball()` to wire scoring and paddle references.
  `main.ball` is only a convenience getter for the first live ball.
- Remove Death Zone balls from the `ball` group before `queue_free()` so repeated
  callbacks and multiple losses in one frame cannot count a dying ball as alive.
  The last loss creates a fresh resting ball only if lives remain.

- Capsule effects clear on a life loss, which means the last live ball reaching the
  Death Zone; removing an earlier ball must preserve the paddle timers and width.

- Resistant (`r`) is destructible but has `counts_for_completion = false`. Recount
  unqueued completion bricks on destruction rather than decrementing for every score signal.
  Breaker pickup refreshes current balls only; shared HUD time and per-ball time clear on level end.
- For manually stepped collision tests, call `set_physics_process(false)` after adding
  the ball to the tree: script initialization enables its physics callback on entry.
  Keep the test world enabled so its collision bodies remain in the physics space.

- Breaker pass-through must depend on the ball state and Resistant definition, not
  on `take_hit()` returning true: a queued brick can still collide again before
  frame end, while its repeated hit correctly returns false to prevent duplicate score.
- Multi-ball copies use `add_ball()` collision exceptions in both directions: the ball
  scene mask includes layer 4, so overlapping copies otherwise collide with each other.
- Capsule catches run inside physics queries: defer Multi-ball body creation and
  recheck the source ball and end-of-level state before spawning copies.
- Ball speed effects scale current velocity by the ratio of new/old multipliers;
  `ball.speed` stays the base launch speed. Use `main.add_ball()` so new balls inherit
  active speed effects before launch. Do not repeatedly multiply velocity each tick.

- Sticky catches remain `launched` (so pause still works), with a separate `caught`
  flag. They visually center but retain the contact offset and held speed; scale
  that held speed alongside velocity when speed effects change. Read the paddle's
  actual last-step travel velocity, not its requested velocity (mouse input and
  wall stops differ). Input-release tests must run real physics steps so Godot's
  `is_action_just_pressed()` observes the press in the right clock.

- Sticky momentum steers direction only: normalize after the momentum and angle clamps
  to retain held speed. Test repeated catches, then an ordinary post-expiry bounce,
  so transient momentum cannot become a permanent speed increase.
- Deferred-spawn tests that freeze balls in `node_added` must also disable physics
  on `ready`, after script initialization enables callbacks. Keep the node process
  mode active so manual collision checks still have a physics body in the space.
  This also applies to capsules: freezing only in `node_added` can let their first
  physics step move them before an exact spawn-position assertion.

- Completion tests must load or destroy actual bricks rather than assign `bricks_left`: the
  completion recount intentionally ignores that cached value after each destruction.

- Multi-ball copies of a Sticky catch must copy `caught`, `catch_offset` and
  `caught_speed`: copying only zero velocity creates launched balls that never move.

- Satellite Shield orbs are a charge count on `main.satellite_orbs` (not `effects.active`) and a
  drawn-only `placeholder_satellite_orbs.gd` under the paddle. `main.gd` reads `power_action`
  in `_physics_process` (same clock as `ball.gd`) and skips while any ball is un-launched, since
  that press is the ball's `launch`. A launched orb is an `add_ball()` ball with a fresh Breaker timer.

- Caught Multi-ball copies also carry a one-use `release_rotation` from the authored
  split angle. Consume it on release and clear it on reset; later Sticky catches
  must not inherit an earlier split’s spread.

- Balls and Blaster bolts share `brick_damage.gd` for take_hit and score reporting;
  Breaker damage permits Resistant hits, but does not bypass Reinforced hit points.
- Force Field charges live separately on `main.gd`, never in the timed `active`
  dictionary. HUD charge entries are display-only; hazard gating happens before
  applying any capsule effects. Charges clear with the other capsule effects.

- Companion scenes inherit `paddle.tscn` with their own root script and retain the
  `paddle` group for shared ball/capsule detection. Only the main paddle collects
  power-ups or catches Sticky balls; companions consume hazards locally.
- After manually moving a physics body in a headless test, await a physics frame
  and then a process frame before checking collisions at its new position, so the
  physics server has synchronized the transform.
- Companion replacement defers body creation out of capsule physics queries. Its
  generation counter invalidates pending replacements on life loss/level end.
- Floating companions can be hit underneath or on a side. Reflect those contacts
  using the collision normal; the upward paddle-angle rule would send an underside
  hit straight back into the surface and drain health across consecutive frames.

- Companion wall bounds come from the inner edges of the wall collision shapes.
  Clamp centers by their half-width on spawn as well as while following; target-only
  clamping leaves an initially out-of-bounds companion outside until it catches up.

- When combining Satellite Shield and Blaster, retain both content-pool entries and
  validation branches. Lifecycle cleanup clears waiting orbs, bolts and shot cooldown;
  the same physics-step power action can trigger both alongside Sticky release.

- When merging Companion Paddle with Satellite Shield, preserve both stable IDs in
  the uniform pool and its pinned content test; keep both deferred companion cleanup
  and waiting-orb cleanup in the shared life-loss/level-end path.

- Paddle Boost is additive after speed effects: remove `ball.boost` before changing
  the multiplier, then add it back. Decay adjusts held Sticky speed too. Multi-ball
  copies must retain boost total, rate and remaining clock alongside velocity, or
  the copied bonus becomes permanent. Boost tuning lives in pure `ball_rules.gd`.

- Paddle Boost collision tests must leave decay active and assert the observed total,
  clock and rate before changing state. Restoring saved values after a stationary
  hit masks an accidental timer restart; account for the collision step in expectations.

## Presentation feedback

- Paddle squash animates only the sprite. Compose its feedback scale with the current
  width multiplier, because `main.gd` reapplies width every physics step; keep the
  collider and `half_width` stable during feedback.
- Brick `broken(points, at)` is a presentation signal emitted after queuing deletion,
  forwarded by Bricks. The ball/bolt score signals still own scoring and completion.
  Capture capsule positions when caught, not when spawned: capsules move while falling.

- Sound calls go through main's `sounds.play_cue()`; balls emit `sound_requested`
  and `add_ball()` wires it. Use Bricks' presentation signal for break audio so
  bolts and balls share it without duplicating score/completion handling.
- Reflections from surviving bricks use `wall_bounce`, including Reinforced and
  Indestructible bricks. A destroying hit uses only the existing `brick_break` cue.
- The sound dispatcher skips playback with Godot's Dummy audio driver (headless),
  while still generating streams and emitting cue requests for tests. Scheduling
  WAV playback without an output driver can leave mixer references at test exit.
