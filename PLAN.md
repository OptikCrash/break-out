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

M1, M2 and M3 are merged: the core loop (paddle, ball angle set by paddle hit position, data-driven
levels, lives, score, win/lose, restart) is bug-fixed, tested, and has a title screen, a pause
menu, a Game Over/Win screen with buttons, mouse/gamepad input alongside keyboard, and three
brick types (Normal, Reinforced, Indestructible) across three levels. 1920×1080, GL Compatibility
renderer. M4 (below) is current.

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

Levels defined as data instead of the single hard-coded grid, plus brick types. No new features
beyond what's listed here (power-up-dependent brick types are explicitly M4's, below).

- **Level format:** a custom `Level` Resource (`level.gd`), authored as `.tres` files under
  `levels/`. Each level has an ASCII-art multi-line string grid, one row per line, one character
  per brick cell: `.` empty, `#` Normal, `x` Reinforced, `o` Indestructible. `bricks.gd` reads a
  `Level` resource instead of generating a hard-coded rectangle. Every level must contain at
  least one destructible brick (`#` or `x`): a grid of only holes and/or Indestructible bricks
  could never be cleared, so `level.gd` rejects it as invalid.
- **Level ownership:** `main.gd`'s ordered `levels` array is the only place that names levels,
  including the first one. `bricks.gd` has no default level; it builds whatever `main` passes to
  `load_level()`.
- **Brick types** (exactly three for M3):
  - **Normal** — 1 hit, 10 points, today's look.
  - **Reinforced** — 2 hits, visibly changes after the first hit, 20 points.
  - **Indestructible** — never breaks, worth 0 points, and does **not** count toward the brick
    count that ends a level.
  - Points are only awarded when a brick is actually destroyed, never per intermediate hit.
- **Level progression:** levels play in a fixed sequence. Clearing a level (all non-Indestructible
  bricks gone) shows a "Level X Complete!" splash with a Continue button/action (mouse click or
  the existing accept input, matching the Game Over/Win screen's pattern); continuing resets the
  ball/paddle (like a life-lost reset, no life cost) and loads the next level. Lives and score
  carry over between levels. After the last level, the existing "You Win!" screen shows. No
  level-select screen in M3.
- **HUD:** a "Level: X" label alongside the existing Score and Lives labels.
- **Level content:** three levels, a small difficulty ramp —
  1. Today's layout minus one row (17×4), all Normal bricks.
  2. A geometric pattern introducing Reinforced bricks.
  3. A geometric pattern introducing Indestructible bricks alongside Reinforced.

### M4: Power-ups

Designed in a grilling session with Chris on 2026-11-03; see
[ADR-0001](docs/adr/0001-power-up-ball-state.md) for the architecture and `GLOSSARY.md` for the
vocabulary used below. Only the items in this milestone ship now — see M5 for the rest of the
power-up roster, deferred because it needs systems this milestone builds.

Acceptance criteria:
- New shared input action `power_action` (bound to the same key as `launch`/accept).
- **Multi-ball life rule**: a ball reaching the Death Zone is removed from play; a life is lost
  only when the last ball goes out. (Needed even before Multi-ball ships, because Resistant
  bricks and Breaker reuse the same ball-state plumbing — see ADR-0001.)
- **Capsule pickup model**: a broken Mystery Brick drops a capsule that falls straight down at a
  fixed speed. Touching the paddle applies its effect immediately. A capsule that reaches the
  Death Zone untouched just disappears — no life cost, no other penalty.
- **Timed effects** run for a fixed 10s duration. Different effects run concurrently (no
  mutual exclusion). Catching the same timed effect again refreshes its timer to full rather
  than stacking magnitude.
- **Scoring on catch**: catching a power-up capsule awards 25 points. Catching a hazard capsule
  awards 0 points.
- **Power-ups** (each a capsule effect):
  - **Multi-ball** — splits the current ball into 3, governed by the multi-ball life rule above.
  - **Wide Paddle** — timed, widens the paddle.
  - **Slow Ball** — timed, reduces the speed of every ball currently in play.
  - **Extra Life** — instant, +1 life, no timer.
  - **Breaker** — timed; every ball currently in play enters the Breaker state (see ADR-0001):
    while active, a ball breaks a Resistant Brick in one hit instead of bouncing off it.
  - **Sticky Paddle** — timed; a caught ball centers on the paddle instead of bouncing. Releasing
    it (via `power_action`) uses the same angle-from-paddle-position formula as a normal bounce,
    and factors the paddle's recent movement into the release angle/speed.
- **Hazards** (bad capsule effects, same pickup/timer mechanics as power-ups): **Shrink Paddle**
  and **Speed-up Ball** (reduces/increases apply to every ball currently in play).
- **Mystery Brick** — a new 1-hit brick type, worth 0 points when broken, that drops a capsule
  drawn uniformly at random from the combined power-up + hazard pool. (Deliberately one brick
  type with one random pool for now; a later milestone may split specific power-ups/hazards into
  their own authored brick types — don't design against that possibility, just don't make it
  hard.)
- **Resistant Brick** — a new brick type that a normal ball hit bounces off without effect; a
  ball in the Breaker state destroys it in one hit. Worth 50 points when destroyed. Does **not**
  count toward the brick count that ends a level (like Indestructible).
- Extend the `Level` ASCII format with characters for Mystery Brick and Resistant Brick
  (`bricks.gd` / `level.gd`); update `GLOSSARY.md`'s Brick Type entry and the M3 level content
  notes don't need to change (existing three levels keep their current bricks; new levels using
  these types are a later concern, not required for M4's acceptance).
- HUD shows which timed effects are currently active (placeholder icons/text; no new art from the
  team — Chris owns art).

### M5: Blaster, shields and Companion Paddle

The rest of the power-up roster from the same grilling session, deferred because each one reuses
machinery M4 builds (the ball power-state property, the multi-ball life rule) or adds a new
charge-based (not timed) lifecycle. Not broken into issues until M4 ships and Chris says go.

- **Blaster** — timed paddle weapon (named to leave room for a differently-functioning "Laser"
  later). `power_action` fires a bolt on the paddle's axis with a ~0.3s cooldown between shots
  (duration-gated at 10s like other timed effects, no separate ammo count); a bolt does the same
  damage as the Breaker state (destroys a Resistant Brick in one hit).
- **Satellite Shield** — 3 balls orbit the paddle. `power_action` launches them one at a time (or
  all at once — decide during implementation planning) as ordinary balls in the Breaker state,
  with the Breaker timer starting at launch, not while orbiting. Once launched they behave exactly
  like any other ball (subject to the multi-ball life rule); the power-up itself is consumed once
  all 3 are launched or lost.
- **Force Field** — charge-based, not timed: 3 charges. Catching a hazard capsule while active
  negates it (no effect) and consumes one charge; power-up capsules pass through unaffected.
  Disappears after the 3rd hazard is negated.
- **Companion Paddle** — floaty extra paddle(s) that lag behind the main paddle's movement, then
  catch up (the "floaty" feel). Starts at 2, positioned above-left and above-right of the main
  paddle, each independently lagging/catching up and each a full-width bounce surface. Each has
  3-hit health: a ball bouncing off *that* companion, or a hazard capsule touching it, depletes
  one hit point (power-up capsules pass through companions untouched — only the main paddle
  collects pickups). If one companion is destroyed, the remaining one re-centers above the
  paddle. Catching Companion Paddle again while only one remains resets the whole power-up back
  to 2 fresh companions, rather than just restoring the second one.

### M6: Speed-up and game feel

Ball speed-up over time or on milestones, juice (screen shake, particles, tweened feedback), and
sound.

### M7: Local high scores

### M8: Web export

The goal stated up front: a small, finished, polished game Chris can share as a web build.
Produce and verify an actual exported HTML5/Web build (not just the editor instructions README
already covers) — export presets/settings, confirming input (keyboard, and whatever M2 added)
and audio (if M5 added sound) work in a browser, and a checked-in or documented way to reproduce
the export. Comes last, once every other milestone's features are in the build being shared.

## Scope rule

A milestone starts only after Chris says go for it. Finishing one milestone is not a go for the
next. New ideas go in a later milestone rather than expanding the current one.
