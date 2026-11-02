# break-out

A small Breakout/Arkanoid clone built with Godot 4.7.2 and GDScript.
The Godot project is at the repository root. Open `project.godot` in Godot
4.7.2 and press F6 on `main.tscn`, or F5 to run the project.
Move with A/D or the arrow keys, launch with Space, and restart with R.

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
