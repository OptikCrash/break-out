# Glossary

Vocabulary specific to break-out. General Godot/programming terms don't belong here.

**Play Area**:
The bounded rectangle where the ball, paddle, and bricks live, walled on three sides. Distinct
from the full 1920×1080 window, which also holds the HUD.

**Death Zone**:
The invisible area below the Play Area's bottom wall; the ball entering it costs a life.

**Brick Grid**:
The rows-and-columns layout of bricks generated at the start of a run (currently 17×5, fixed in
code; M3 makes this data-driven per level).

**Launch**:
The player input (and the moment) that sends the ball moving for the first time, or after a life
is lost. Always mostly vertical with a small random lean; avoid "serve" for this.
