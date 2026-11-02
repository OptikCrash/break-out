# PLAN.md

Break-out: a small Breakout/Arkanoid clone (Godot 4.7, GDScript), and a pilot for running a
Godot project end to end through the team. Chris wrote the core loop to learn Godot; the team
picks it up from here. Every PR explains the Godot idea involved (signals, physics layers and
masks, scene instancing, groups, autoloads...) and any alternative considered, not just the diff.

This file is the source of truth for scope and milestone order. `GLOSSARY.md` holds the
project's vocabulary. Decision records, once any are needed, go in `docs/adr/`
(hard-to-reverse, surprising, real-trade-off choices only — most of this project's choices
don't rise to that bar and are just recorded here instead).

## Current state

The core loop works: paddle, ball angle set by where it hits the paddle, a 17×5 brick grid,
lives, score, win/lose, restart. 1920×1080, GL Compatibility renderer. Known rough edges are
milestone 1's scope.

## Conventions

- **Tests:** a plain `scripts/run-tests.sh` that discovers `*_test.tscn`/`*_test.gd` and runs
  them headless, no GUT or other addon — the same pattern as the team's other Godot project.
- **Regression-test scope:** pure game-logic bugs get a headless test. Structural/scene fixes
  (anchoring, script placement, a scene's default property) are caught by the headless import
  check and a manual playthrough, not a unit test.
- **CI:** one `ci` workflow, triggered on pull requests into `develop`: headless import check,
  then the test runner.
- **Art:** all art (sprites, textures, icons) is Chris's own. The team never creates, replaces,
  or regenerates it; a missing asset gets a plain placeholder shape, called out in the PR.

## Milestones

### M1: Foundation (current)

No new features. Scope:

- `README.md`: what the game is, controls, how to run it in the editor, how to export the web
  build.
- CI: headless import check + the test runner, on PRs into `develop`.
- Fix the known issues in the current core loop:
  1. **Message label centering** — `MessageLabel`'s anchoring centers Game Over/Win text on the
     real 1920×1080 viewport (it's currently sized/positioned for an old 1152×648 box).
  2. **Double-counted brick** — a brick can register a hit twice before `queue_free()` takes
     effect (e.g. two physics ticks), double-counting score and skipping the win trigger when it
     happens on the last brick. Guard against scoring the same brick twice (for example, check
     `is_queued_for_deletion()` before treating a collision as a score).
  3. **Dead-center paddle loop** — a dead-center paddle hit can send the ball straight up and
     down forever. Refactor so the paddle-bounce tie-break reuses the same random-lean logic
     already used for the initial launch, instead of a separate rule, so there's one place that
     decides "mostly vertical with a small random lean."
  4. **Win freeze** — `ball.reset()` only clears the launch flag; on a win the ball freezes
     wherever it was in flight instead of returning to its paddle-rest position. Fix `reset()`
     (or the win path) so the ball snaps to its resting spot on the paddle before freezing.
  5. **`ball.tscn`'s `speed = null`** — fix the scene's own default to `550.0` and remove the
     now-redundant override on the `main.tscn` instance.
  6. **HUD script placement** — the script is attached to the `Hud` instance in `main.tscn`
     instead of on `HUD.tscn`'s own root; move it so any instance of the scene behaves
     correctly.

### M2: Screens and input polish

Title, pause, and game-over screens; mouse or gamepad input alongside keyboard.

### M3: Content variety

Levels defined as data instead of the single hard-coded grid; brick types.

### M4: Power-ups

### M5: Speed-up and game feel

Ball speed-up over time or on milestones, juice (screen shake, particles, tweened feedback), and
sound.

### M6: Local high scores

## Scope rule

A milestone starts only after Chris says go for it. Finishing one milestone is not a go for the
next. New ideas go in a later milestone rather than expanding the current one.
