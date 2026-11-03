# Glossary

Vocabulary specific to break-out. General Godot/programming terms don't belong here.

**Play Area**:
The bounded rectangle where the ball, paddle, and bricks live, walled on three sides. Distinct
from the full 1920×1080 window, which also holds the HUD.

**Death Zone**:
The invisible area below the Play Area's bottom wall; the ball entering it costs a life.

**Brick Grid**:
The rows-and-columns layout of bricks loaded from a Level's ASCII grid (one row per line, one
character per cell). Dimensions vary per level.

**Level**:
A `Level` Resource (`.tres` under `levels/`) defining one brick grid. Levels play in a fixed
sequence; clearing one loads the next.

**Brick Type**:
What a brick cell's character means: Normal (`#`, 1 hit), Reinforced (`x`, 2 hits), or
Indestructible (`o`, never breaks, doesn't count toward a level's win condition).

**Launch**:
The player input (and the moment) that sends the ball moving for the first time, or after a life
is lost. Always mostly vertical with a small random lean; avoid "serve" for this.
The direction is normalized from `(lean, -1)`, with lean sampled from -0.3 to 0.3.
An exact zero sample uses 0.3 so it cannot travel perfectly vertically. A dead-center
paddle hit uses this same rule, keeping the ball's current speed.
