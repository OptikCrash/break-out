# Glossary

Vocabulary specific to break-out. General Godot/programming terms don't belong here.

**Play Area**:
The bounded rectangle where the ball, paddle, and bricks live, walled on three sides. Distinct
from the full 1920×1080 window, which also holds the HUD.

**Death Zone**:
The invisible area below the Play Area's bottom wall; balls entering it are removed; only the last ball costs a life.

**Brick Grid**:
The rows-and-columns layout of bricks loaded from a Level's ASCII grid (one row per line, one
character per cell). Dimensions vary per level.

**Level**:
A `Level` Resource (`.tres` under `levels/`) defining one brick grid. Levels play in a fixed
sequence; clearing one loads the next.

**Brick Type**:
What a brick cell's character means: Normal (`#`, 1 hit), Reinforced (`x`, 2 hits), or
Indestructible (`o`, never breaks, doesn't count toward a level's win condition), or
Mystery (`?`, 1 hit, 0 points, drops a Capsule, counts toward completion), or
Resistant (`r`, Breaker-only, 1 hit, 50 points, excluded from completion).

**Launch**:
The player input (and the moment) that sends the ball moving for the first time, or after a life
is lost. Always mostly vertical with a small random lean; avoid "serve" for this.
The direction is normalized from `(lean, -1)`, with lean sampled from -0.3 to 0.3.
An exact zero sample uses 0.3 so it cannot travel perfectly vertically. A dead-center
paddle hit uses this same rule, keeping the ball's current speed.

**Power-up Action** (`power_action`):
The shared input action for whatever a currently-active power-up lets the player trigger
(releasing a Sticky Paddle catch, firing the Blaster, launching the Satellite Shield's balls).
Bound to the same key as `launch`/accept; only one such power-up is ever active at a time.

**Multi-ball Life Rule**:
With more than one ball in play, a ball reaching the Death Zone is just removed; a life is lost
only when the last remaining ball goes out. Mirrors Indestructible not counting toward a level's
win condition.

**Capsule**:
The falling pickup dropped by a broken Mystery Brick, carrying either a power-up or a hazard.
Falls straight down at a fixed speed; applies its effect on touching the paddle; disappears with
no penalty if it reaches the Death Zone untouched.

**Power-up**:
A beneficial Capsule effect. Catching one awards 25 points in addition to its effect.
_Avoid_: Bonus, item.

**Hazard**:
A detrimental Capsule effect, using the same pickup mechanics as a Power-up. Catching one awards
0 points.

**Breaker** (ball state):
A temporary state a ball can carry, with its own duration timer, letting it destroy a Resistant
Brick in one hit instead of bouncing off it. A property of the ball, not a separate ball type —
see [ADR-0001](docs/adr/0001-power-up-ball-state.md).

**Mystery Brick**:
A 1-hit brick, worth 0 points, that drops a Capsule drawn uniformly at random from the combined
power-up and hazard pool.

**Resistant Brick**:
A brick that a normal ball hit bounces off without effect; destroyed in one hit by a ball in the
Breaker state, which continues through the destroyed brick. Grid symbol: `r`. Worth 50 points when destroyed; does not count toward a level's win condition.

**Capsule tuning (issue #50 provisional defaults)**:
Fall speed is 240 pixels/second. Wide Paddle multiplies the base 128-pixel width by 1.5
(192 pixels); Shrink Paddle multiplies it by 0.75 (96 pixels). Both together multiply
(144 pixels), each retaining its independent 10-second timer. Catching the same effect
refreshes only that timer. Extra Life adds exactly one life, without a cap or timer.
Life loss and level completion clear timed effects and loose capsules. Pausing freezes
both fall and effect time. A final Mystery Brick still completes the level immediately;
its pending drop is discarded with the level's other loose capsules.
These tuning and reset choices were unspecified in PLAN.md and the issue; they are
explicit implementation defaults for review, rather than previously agreed design values.

**Multi-ball tuning (issue #52 provisional defaults)**:
Each catch adds two copies of the first launched ball (or the first resting ball if
none is launched), leaving other balls unchanged. Copies retain speed, launched state
and remaining Breaker time. In flight, their velocities rotate -20 and +20 degrees
from the original, which keeps its trajectory. They start at the same position and
ignore collisions with other balls, separating through their different velocities
without offsetting a copy into a wall or brick. Resting copies wait on the paddle
and use the ordinary launch rule. There is no timer or ball-count cap.
Creation waits until physics queries finish; a lost source or completed level
cancels its pending copies.
Repeat-catch behavior, resting catches and spread were unspecified in PLAN.md and
the issue; these are explicit implementation defaults for review.
**Ball speed capsule tuning (issue #53 provisional defaults)**:
Slow Ball (`slow_ball`) multiplies ball speed by 0.75; Speed-up Ball (`speed_up_ball`)
multiplies it by 1.5. Both last 10 seconds, refresh independently without stacking,
and multiply together to 1.125 times the underlying speed. They affect all live balls,
including balls added or launched during the effect. Expiry or lifecycle clearing removes
only the effect multiplier, preserving direction and each ball's underlying speed.
The factors and overlap calculation were unspecified in the design; these are explicit
implementation defaults for review. Catch scores remain +25 and +0 respectively.

**Sticky Paddle tuning (issue #54)**:
Sticky Paddle (`sticky_paddle`) lasts 10 seconds, refreshes on pickup, and awards
25 points. A caught ball stops and follows the paddle center, retaining its original
normalized catch offset for release. This reconciles the centered placement in PLAN.md
with the issue's catch-point-relative release rule. `power_action` or timer expiry
releases every caught ball using the normal bounce direction at that stored offset
(including the random lean at center), at its held speed including active speed effects.
Add 25% of the paddle's actual horizontal velocity from its latest completed physics
step to the release's horizontal velocity, capped to ±the held speed. Clamp the resulting
horizontal component to ±the upward vertical component (at least 45° above horizontal),
then normalize back to the held speed. Momentum changes angle only: repeated catches
cannot accumulate speed, and active Slow/Speed-up multipliers still scale held speed.
There is no momentum history or smoothing; a stationary step clears the contribution.
Mouse travel can produce much larger one-step velocities than keyboard movement, but
both use the same cap. The weighting, cap, 45° limit and one-step meaning of "recent"
are implementation defaults for review.

When Multi-ball copies a caught ball, the copies retain its catch offset and held speed,
remaining caught until Power-up Action or expiry releases them. Copies apply the authored
Multi-ball spread (−20° and +20°) after the Sticky direction and momentum calculation,
with unchanged held speed; the source keeps its original release angle. This one-use
rotation clears on release or reset, so later catches use ordinary Sticky rules.
The spread can extend the 45° Sticky limit to 25° above horizontal on this release.
Splitting an already split caught copy adds its pending rotation to the new spread.
The design does not specify this interaction; preserving the catch and applying the
usual split spread are implementation defaults for review.

**Force Field (issue #65)**:
`force_field` is a power-up worth 25 catch points. Catching it sets three charges,
replacing any remaining charges. Each subsequent hazard catch consumes one charge
and applies no effect or points; power-ups apply and score normally without spending
a charge. The third blocked hazard removes the field; the fourth applies normally.
Charges have no timer. The HUD shows remaining charges in the active-effects panel.
Life loss (last live ball) and level completion clear charges, following other capsule
effects. The design does not specify charge clearing; this is an implementation default
for review.

**Companion Paddle (issue #67 provisional defaults)**:
`companion_paddle` awards 25 catch points and always replaces the whole power-up with
exactly two fresh companions, each with three hit points, even if both still survive.
They start at horizontal offsets −160/+160 pixels and 96 pixels above the main paddle.
Each follows its own horizontal target at 600 pixels/second without overshoot; vertical
placement stays 96 pixels above the main paddle. When one dies the other's horizontal
target becomes the main paddle center; it catches up at the same speed rather than
teleporting. Offsets and follow speed are authored in the effect definition.
Each retains the ordinary base 128×16 paddle surface and existing paddle sprite;
Wide/Shrink and Sticky affect only the main paddle. Companion bounces use ordinary
paddle angles and preserve ball speed. Only top-face bounces spend one health;
side and underside contacts reflect off the collision normal at unchanged speed,
without spending health or catching Sticky balls. This contact-face distinction is a
provisional default: the design did not specify non-top contacts, and steering an
underside hit upward would repeatedly hit the same surface. An intercepted hazard spends one health;
power-up capsules pass untouched. Intercepted hazards give no score/effect and do not
spend Force Field charges. Companions have no timer and clear on last-ball life loss
or level completion; pending creation is canceled too. Spacing, speed, fixed base width,
Sticky interaction, gradual re-centering and lifecycle clearing are implementation
defaults where the design was unspecified. Always resetting on any re-catch generalizes
PLAN.md's one-survivor reset rule, as requested by issue #67; it remains provisional.
Companion centers are clamped between the inner wall edges plus/minus their 64-pixel
half-width, including on spawn, so their whole bounce surface stays inside the play area.
This placement rule is a provisional default following issue #67 review feedback.
