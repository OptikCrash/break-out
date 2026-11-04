# Test Lab is a development-only scene with a verified release-export boundary

## Context

Chris needs a way to try out levels, power-ups/hazards and his own art in the real gameplay loop
without playing through the game normally — picking any level directly, triggering any effect on
demand, and seeing art changes in context. The dungeon-crawler project solved the equivalent
problem with its Combat Lab (that project's decision 0034): a development-only scene living in
the same repository and project, reusing the real runtime, with navigation and export boundaries
— not a separate repository — keeping it out of players' hands.

## Decision

Break-out follows the same shape, scaled down: a `devtools/test_lab.tscn` scene built on the real
`Ball`/`Paddle`/`Bricks`/capsule/effect code (not a second approximation), opened directly in the
Godot editor and never reachable from `TitleScreen` or any production scene. Unlike the
dungeon-crawler's Combat Lab, there is no versioned scenario schema and no promotion workflow —
break-out's levels and effects are already plain `.tres` data with their own validation and
headless tests, so there's nothing to author-and-promote; the Test Lab only needs to load and
trigger what already exists. The release-export exclusion itself waits on M9 (Web export, not
built yet), but the Test Lab lives under one clearly-named root (`devtools/`) specifically so
that exclusion is a trivial filter addition when M9 adds an export preset, not a restructuring.

## Consequences

Chris gets immediate access to live gameplay changes the same way the dungeon-crawler's Combat
Lab does, without a second repository or a speculative shared-package boundary. The Test Lab
cannot leak into a release build today only because no release build exists yet; M9 must add the
actual export-filter check, and until then "never shipped" only means "no production scene links
to it," not an automatically-enforced boundary. If break-out ever needs authored draft content
beyond what's already in `levels/`/`effects/` (the dungeon-crawler's original reason for a
scenario schema), that's a reason to revisit this decision, not evidence it was wrong now.
