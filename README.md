# break-out

A small Breakout/Arkanoid clone built with Godot 4.7.2 and GDScript.
The Godot project is at the repository root. Open `project.godot` in Godot
4.7.2 and press F5 to run the project, or F6 on `TitleScreen.tscn`. Both start at
the title screen, which offers Start and High Scores: press Space or Enter, or
click, on the focused button. The board's Back button or Escape (B on a gamepad)
returns to the menu. F6 on
`main.tscn` still skips straight to gameplay.
Move with A/D, the arrow keys or the mouse, launch with Space or a left click, and restart with R.
With a gamepad, move with the left stick or D-pad, launch with A (Cross on
PlayStation) and restart with Y (Triangle). Menus use the D-pad or left stick
to move between buttons and A to press one.
While the ball is in play, Escape (or gamepad Start) pauses the game and opens a
menu with Resume, Restart and Back to Title. Start or B (Circle) also resumes.

## Local high scores

Game Over and You Win! both qualify for the local top ten. A qualifying run asks
for three uppercase A–Z initials; confirm them to save and show the complete board
with your new row highlighted. Restart and Back to Title become available after
confirmation. R and gamepad Y cannot restart while entering initials. Other runs
go directly to the usual end buttons. The title's High Scores choice reads the
persisted board from `user://high_scores.json`; there is no in-game reset.

## Test Lab (development only)

`devtools/test_lab.tscn` is a sandbox for trying levels, power-ups and art in the
real gameplay loop without playing through the game. Open it in the Godot editor
and press **F6** (Run Current Scene). It is never reachable from the title screen.

- **Infinite lives**: losing the last ball clears effects as usual, then a new
  ball appears on the paddle. Lives never drop and there is no Game Over.
- **No end screens**: clearing the level reloads it instead of showing "Level
  Complete" or "You Win!". There is no pause menu.
- **Catch an effect panel** (left gutter, under the level picker): click any current capsule effect to
  apply the real catch, including catch points and Force Field hazard blocking.
  Hazard labels and HUD-colored swatches distinguish hazards from power-ups.
  The list scrolls if the pool grows; Reset clears the resulting state.
- **Reset button** (top-left): one ball back on the paddle, the current level's
  bricks rebuilt, and active effects, capsules, companions and waiting Satellite
  orbs cleared through `main.gd`'s own `_clear_effects_and_capsules()`.
- **Level picker** (left, under Reset): one button per `.tres` file in `levels/`,
  found by scanning the folder when the lab opens, so a new level file shows up
  without editing any list. Clicking one checks it with `Level.validation_error()`
  and loads it with `Bricks.load_level()`, then resets as above. A bad file is
  rejected with the reason shown under the list, and the current level stays.
  Reset afterwards rebuilds the picked level.

How it is built: `test_lab.tscn` is an *inherited scene* of `main.tscn` (Godot's
**Scene → New Inherited Scene**), so it always has the current `PlayArea`, ball,
paddle, bricks, Death Zone, walls and HUD. Its root script, `devtools/test_lab.gd`,
`extends "res://main.gd"` and overrides only the session rules: `_lose_life()`,
`_finish_level()`, `can_pause()`, `restart()` and `back_to_title()`. Loading,
effects, scoring and capsules all stay in `main.gd`. Inherited scenes cannot
delete inherited nodes, so the script frees `PauseScreen` in `_ready()`.

Everything for the Test Lab lives under `devtools/`, and production files must
never link to it (`tests/devtools_boundary_test.gd` checks both `res://devtools/`
paths and `devtools/` UIDs). Links the other way, from devtools to production,
are fine. When M9 adds a Web export preset, add `devtools/*` to that preset's
exclude filter (**Resources → Filters to exclude files/folders**) so the Test Lab
is not shipped. See `docs/adr/0002-test-lab-dev-only-boundary.md`.

## Level progression

Clearing all destructible bricks shows "Level X Complete!". Choose Continue
with the mouse, keyboard or gamepad to load the next level with score and lives
intact. The paddle and ball return to their starting positions; launch again
when ready. Clearing the final level shows "You Win!".

The ordered `levels` array on `main.gd` selects the sequence. The gameplay scene
stays alive while only the brick layout changes, preserving score and lives
without an autoload. Each level grid must contain at least one Normal (`#`) or
Reinforced (`x`) or Mystery (`?`) brick; all-hole and all-Indestructible grids are rejected because
they cannot trigger completion. Level 2 is a diamond of Normal bricks around a Reinforced core. Level 3 adds
Indestructible side rails around a denser Reinforced formation. Both keep open
approaches from below; the rails never sit beneath destructible bricks.

## Export for the web

1. Open the project in Godot **4.7.2**. Under **Editor → Manage Export
   Templates**, install the matching **4.7.2** export templates.
2. Open **Project → Export → Add… → Web** to create a local export preset.
3. Create an output folder outside the repository, choose **Export Project**,
   turn off **Export With Debug**, and save as `index.html` in that folder.
4. Serve the entire output folder over HTTP to preview it, rather than opening
   `index.html` directly. For example, with Python 3, run this from that folder:

   ```sh
   python3 -m http.server 8000
   ```

   Open <http://localhost:8000/>. The build opens on the title screen; click Start
   (which also gives the page keyboard focus) to start the game.

Keep all generated files together when sharing the build through an HTTPS web
host. These are editor export instructions only; verified export presets,
settings, and browser testing of the finished game belong to milestone 7 in
`PLAN.md`.

## Headless checks

On Linux, install Godot **4.7.2** as `godot` on PATH, plus Bash and GNU
coreutils/findutils (including `timeout` and `sort`). From the repository root:

```sh
godot --headless --path . --editor --import
scripts/test-runner.sh
scripts/run-tests.sh
```

The `ci` GitHub Actions check runs on pull requests targeting `develop`. It
imports the project before running tests. Import and test logs containing Godot
errors fail CI even if Godot returns zero.

The runner recursively discovers `*_test.tscn` and `*_test.gd`, excluding
`.git/` and `.godot/`, and runs each in a separate headless Godot process.
A scene takes precedence over a script with the same path and basename, so its
attached script runs only through the scene. Standalone script tests must extend
`SceneTree` (or `MainLoop`); scene tests can use nodes and `get_tree().quit(...)`.
Tests must explicitly quit with code 0 on success or nonzero on failure. Use
explicit checks and `quit(1)` for failures; do not rely solely on `assert`.
Each test has a 60-second timeout. The runner stops at the first failure and
passes cleanly when zero tests exist. No test addons are required.

`scripts/test-runner.sh` checks discovery and failure handling using temporary
headless Godot fixtures outside the project. It leaves no game test assets behind.
See `PLAN.md` for scope and milestones.

The suite currently contains 33 `tests/*_test.gd` files. The level-progression
test flushes synthetic input with `Input.flush_buffered_events()` and waits for
a `process_frame` between a Button press and release. Several physics steps can
run within one GUI frame, so waiting only for physics frames can lose the press.
The extra tone-generation work on this branch likely exposed that assumption;
it was a test synchronization problem rather than blocked level transitions.
The test checks both unrestricted frames and `Engine.max_fps = 10` to exercise
multiple physics steps per GUI frame, then restores `Engine.max_fps = 0` before
its remaining checks.

## Capsules

Custom levels can use `?` for a one-hit, zero-point Mystery Brick. It drops a random
Wide Paddle, Slow Ball, Sticky Paddle, Blaster, Extra Life, Multi-ball, Breaker,
Shrink Paddle hazard, Speed-up Ball hazard, Force Field, Satellite Shield or Companion Paddle capsule.
Companion Paddle creates two full-width followers with three health each; top-face
ball bounces and intercepted hazards spend health. The survivor follows the center,
and another catch replaces both companions. Force Field blocks the next three
hazard catches; catching it again resets its charges to three. Multi-ball adds two
copies of a ball; only losing
the last ball costs a life. Breaker lasts ten seconds and refreshes every current
ball’s independent timer. Resistant bricks (`r`) stop ordinary balls but break
for 50 points when hit by a Breaker ball, which continues through them. They
never count toward completion.

Catch power-ups for 25 points; hazards give no points, and missed capsules have
no penalty. Width and speed effects last ten
seconds and can overlap; catching the same effect refreshes its timer. The HUD lists
active timers. Life loss and level completion clear effects and loose capsules.
Capsules use plain placeholder shapes and text pending Chris's art.
See GLOSSARY.md for provisional tuning values.

Sticky Paddle catches balls for up to ten seconds. Press Space, left click, or
gamepad A to release; expiry also releases automatically. The original catch point
sets the angle, and sideways paddle movement adds momentum at release.

Blaster lasts ten seconds. Press the launch/power action to fire upward, at most once
every 0.3 seconds. The same press also releases Sticky catches when both are active.
Bolts use a plain placeholder rectangle pending Chris’s art.

Satellite Shield resets three waiting orbs, drawn as placeholder circles orbiting the
paddle. Each Power-up Action press launches one as an ordinary ball with a fresh
ten-second Breaker timer. The same press can fire Blaster and release Sticky catches.
A resting ball takes the shared press to launch before Satellite orbs can launch.

## Placeholder sound

`main.gd` owns a `SoundEvents` child (`sound_events.gd`). Its `play_cue()` method
accepts the nine named gameplay cues in `CUES`; its `volume` multiplier ranges
from 0 (mute) to 1, defaulting to 0.5. Changing it also updates playing voices.
There is no settings screen or saved audio setting yet.

These short sine tones are procedurally synthesized placeholders, explicitly
approved for M6 as an audio-only exception to the team's no-art rule. They use
no recorded or sourced samples. Replace the dispatcher's cached streams with
Chris's audio when available; gameplay callers can keep the same cue names.
A fixed twelve-player pool bounds overlap; a full pool replaces the next voice.
Synthesized streams are generated once and shared across gameplay scene reloads;
each scene keeps its own players and volume so restarting does not rebuild PCM.
A static cache avoids rebuilding samples in every `_ready()` without requiring an
autoload: only the immutable streams need to outlive a gameplay scene, while
players should stop with that scene and volume should remain local.
Final-life loss plays both life-lost and game-over cues, and a final level plays
win in place of level-complete. Blocked hazards still use the hazard-catch cue.
Reflections from surviving bricks (including Reinforced and Indestructible) use
the wall-bounce cue; a destroying hit uses only brick-break, even if it reflects.
Audio balance, cue distinction and browser playback need a listening playthrough;
headless tests check routing and PCM generation, not perceived sound. The Dummy
audio driver skips playback while retaining observable cue requests.
