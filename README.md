# break-out

A small Breakout/Arkanoid clone built with Godot 4.7.2 and GDScript.
The Godot project is at the repository root. Open `project.godot` in Godot
4.7.2 and press F6 on `main.tscn`, or F5 to run the project.
Move with A/D or the arrow keys, launch with Space, and restart with R.

## Export for the web

1. In Godot **4.7.2**, open **Editor → Manage Export Templates** and install
   the matching **4.7.2** templates (the standard editor download does not include them).
2. Open **Project → Export**, select the checked-in **Web** preset, and create
   `build/web/` at the repository root.
3. Choose **Export Project**, turn off **Export With Debug**, and save as
   `build/web/index.html`.

Alternatively, with the templates installed, run from the repository root:

```sh
mkdir -p build/web
godot --headless --path . --editor --import
godot --headless --path . --export-release "Web" build/web/index.html
```

The preset uses the project's GL Compatibility renderer (WebGL 2) and disables
thread support. This small game needs no worker threads, so hosting does not
require cross-origin isolation headers. Test fixtures and build output are
excluded from the export; generated files under `build/` are ignored by Git.

To preview locally, serve the entire output directory over HTTP, for example
with Python 3:

```sh
python3 -m http.server 8000 --directory build/web
```

Open <http://localhost:8000/> in a WebGL 2-capable browser and click the game
before using the keyboard controls. Opening `index.html` directly via `file://`
will not work. For sharing, upload **all** generated files together to an HTTPS
static host that serves `.wasm` files as `application/wasm`; keep their names and
relative paths intact. See Godot's [web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).
Browser playtesting of the finished game remains milestone 7 in `PLAN.md`.

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
