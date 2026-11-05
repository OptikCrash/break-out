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
- **No network services (operational safety constraint, accepted 2026-11-04):** the game and
  its tests need no database or network service, and none is added. Builders never start
  services or daemons outside the repo's own test harness, never write to live services, never
  enable discovery/relays, and any harness listener binds only to `127.0.0.1`. This is a
  working rule for the team, not a gameplay milestone or design decision; the full wording is
  in `AGENTS.md` under "Network services (hard rule)".

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
  4. (Added later) A chevron introducing Mystery bricks alongside Reinforced and Indestructible.
  5. (Added later) A castle introducing Resistant battlements, with Mystery bricks as the Breaker source.

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
    while active, a ball destroys any destructible brick in one hit (including Reinforced) and
    breaks a Resistant Brick instead of bouncing off it. Indestructible still survives.
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
  damage as the Breaker state (destroys any destructible brick, including Reinforced and Resistant,
  in one hit).
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

### M6: Paddle Boost and game feel

Designed in a grilling session with Chris on 2026-11-03; see `GLOSSARY.md`'s Paddle Boost entry
for the vocabulary. Renamed from "Speed-up and game feel": the per-level speed ramp originally
scoped here is parked (see below) in favor of a new per-hit mechanic.

Acceptance criteria:
- **Paddle Boost**: hitting the ball while the paddle is moving (`paddle.gd`'s `recent_velocity_x`)
  adds to a single boost accumulator (speed above the ball's base speed — 550 today, per
  `ball.gd`), scaled from the paddle's velocity. Every boosting hit **adds to the accumulator**
  (clamped to a cap) **and resets its decay clock to full duration**, so repeated hits stack the
  boost and keep extending how long it takes to fade. With no further hits, the accumulator decays
  linearly to 0 over a fixed duration. The ball's actual speed is always base speed plus whatever
  boost remains — it never drops below base while in flight. Boost only changes speed magnitude,
  never the bounce angle (that stays governed by paddle-contact position, unchanged).
  Boost must compose with the existing Slow Ball/Speed-up Ball multiplier effects
  (`set_speed_multiplier()`) without double-counting — e.g. boost is additive on top of
  `base speed × multiplier`, not itself multiplied. Cap and decay-duration numbers are
  implementation defaults for review.
- **Juice**:
  - Screen shake on a hazard hitting the paddle and on a life lost.
  - A particle burst on every brick break (all types, including Resistant).
  - Tweened squash/scale feedback on paddle bounces and on capsule catches.
  - Floating/scrolling point popups: on every brick break (its point value, including Mystery
    Brick's 0) and on every capsule catch (the point delta — a literal "+0" for hazards, not a
    name).
- **Sound**: add the audio plumbing (AudioStreamPlayer nodes, a central sound-event dispatcher,
  volume) plus placeholder cues for paddle bounce, wall bounce, brick break, power-up catch,
  hazard catch, life lost, level complete, game over, and win. Since Chris has no sound files yet,
  placeholder cues may be **procedurally synthesized** (simple generated tones, not sourced or
  recorded samples) — a one-off, documented exception to "the team never creates art," audio-only,
  swapped for Chris's real files whenever he makes them. Falls back to silence/no-op per cue if
  synthesis turns out impractical.

**Parked**: a permanent per-level-count speed-up (e.g. every 5 levels) was discussed but deferred
until the total level count is settled — useful to extend a short level set by cycling back at
higher speed, unnecessary if there end up being plenty of levels. Revisit alongside level-content
planning, not as part of M6.

### M7: Test Lab

Designed in a grilling session with Chris on 2026-11-04, mirroring the dungeon-crawler's
Combat Lab (that project's [decision 0034](../dungeon-crawler/docs/decisions/0034-development-only-combat-lab.md))
scaled down to what break-out actually needs. See [ADR-0002](docs/adr/0002-test-lab-dev-only-boundary.md)
for the dev-only/release-boundary reasoning and `GLOSSARY.md` for the vocabulary below.

Acceptance criteria:
- **`devtools/test_lab.tscn`**: a development-only scene, opened and run directly in the Godot
  editor (F6), never reachable from `TitleScreen` or any in-game menu, and never wired into the
  normal `TitleScreen → main.tscn` flow. A regression check confirms no production scene
  references anything under `devtools/`.
- **Built on the real gameplay scene**, not a second approximation: the same `Ball`/`Paddle`/
  `Bricks`/capsule/effect scenes and scripts `main.tscn` already uses, with the Title/Pause/
  win-lose flow stripped out and a debug overlay added on top.
- **Level picker**: an auto-discovered list of every `.tres` file under `levels/` (scan the
  folder, don't hardcode the list), shown as on-screen buttons; clicking one loads that level
  immediately through the real `Level`/`Bricks` loading path.
- **Power-up/hazard panel**: one button per effect in the uniform capsule pool (both power-ups
  and hazards, hazards visually distinguished using the same color convention the HUD's active-
  effects list already uses), applying the real effect path exactly as if a capsule had been
  caught — no capsule object needed.
- **Infinite lives** while in the Test Lab: a ball reaching the Death Zone never costs a life or
  ends the session, regardless of the normal multi-ball life rule's outcome.
- **A manual reset button**: ball(s) back on the paddle, current level's bricks reloaded, any
  active effects/companions/satellite orbs cleared — same cleanup path life-loss/level-complete
  already trigger.
- **No real progress affected**: the Test Lab never reads or writes whatever score/lives/save
  state a future milestone adds to the shipped game; it's a throwaway sandbox session every time
  it's opened.
- Document in `README.md`/`AGENTS.md` how to open and use it, and that M9 (Web export) must add
  `devtools/` to the export filter once that preset exists — M7 can't verify the actual export
  exclusion yet since no export preset exists until M9, but it must be trivial to exclude by
  living under one clearly-named root.

### M8: Local high scores

Persist a local arcade-style leaderboard across launches. This is deliberately local-only;
M9's web export may decide later how, or whether, browser storage is exposed to players.

- Keep exactly the top 10 **completed runs**, ordered by final score descending. A newer run
  ranks ahead of an older run with the same score; therefore a score tied with the current
  tenth place qualifies and displaces that older entry.
- A completed run means either terminal outcome: **Game Over** or **You Win!**. The final
  score is the only ranking value; do not record or display level reached, lives, duration,
  or date.
- When a completed run qualifies, replace the usual end buttons with a **New High Score!**
  entry panel. The player must explicitly confirm exactly three uppercase `A`–`Z` initials
  before the row is saved. It must work with typing and a focused, controller-operable
  on-screen selector; no score is saved until confirmation.
- After confirmation, show the complete leaderboard and visibly highlight the newly saved
  row. It then offers the ordinary Restart and Back to Title choices. A non-qualifying run
  goes directly to those existing end buttons.
- Make the full leaderboard available from a **High Scores** choice on the title screen,
  with navigation that works by mouse, keyboard, and gamepad.
- Each board row displays only rank, initials, and score. No in-game reset control belongs
  in M8: entries persist until the local save is removed outside the game. Missing or
  unreadable local data must recover safely to an empty board rather than blocking play.
- Store the data only in Godot's per-user local storage (`user://`); no network service,
  account, or online leaderboard is in scope. Keep persistence/ranking/input behavior in
  independently testable scripts and add headless coverage for insertion, tie ordering,
  qualification, save/load round-trips, corrupt-data recovery, and initials validation.

### M9: Web export

The goal stated up front: a small, finished, polished game Chris can share as a web build.
Produce and verify an actual exported HTML5/Web build (not just the editor instructions README
already covers) — export presets/settings, confirming input (keyboard, and whatever M2 added)
and audio (M6 added sound) work in a browser, excluding `devtools/` (M7's Test Lab) from the
build, and a checked-in or documented way to reproduce the export. Comes last, once every other
milestone's features are in the build being shared.

## Scope rule

A milestone starts only after Chris says go for it. Finishing one milestone is not a go for the
next. New ideas go in a later milestone rather than expanding the current one.
