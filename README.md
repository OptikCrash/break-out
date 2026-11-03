# break-out

A small Breakout/Arkanoid clone built with Godot 4.7.2 and GDScript.
The Godot project is at the repository root. Open `project.godot` in Godot
4.7.2 and press F5 to run the project, or F6 on `TitleScreen.tscn`. Both start at
the title screen; press Space or Enter, or click, to start the game. F6 on
`main.tscn` still skips straight to gameplay.
Move with A/D, the arrow keys or the mouse, launch with Space or a left click, and restart with R.
With a gamepad, move with the left stick or D-pad, launch with A (Cross on
PlayStation) and restart with Y (Triangle). Menus use the D-pad or left stick
to move between buttons and A to press one.
While the ball is in play, Escape (or gamepad Start) pauses the game and opens a
menu with Resume, Restart and Back to Title. Start or B (Circle) also resumes.

## Level progression

Clearing all destructible bricks shows "Level X Complete!". Choose Continue
with the mouse, keyboard or gamepad to load the next level with score and lives
intact. The paddle and ball return to their starting positions; launch again
when ready. Clearing the final level shows "You Win!".

The ordered `levels` array on `main.gd` selects the sequence. The gameplay scene
stays alive while only the brick layout changes, preserving score and lives
without an autoload. Each level grid must contain at least one Normal (`#`) or
Reinforced (`x`) brick; all-hole and all-Indestructible grids are rejected because
they cannot trigger completion. Levels 2 and 3 are temporary progression fixtures;
their designed layouts and difficulty ramp are deferred to issue #39.

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

   Open <http://localhost:8000/>. The build opens on the title screen; click it
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
