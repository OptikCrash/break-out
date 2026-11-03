# Power-ups model ball effects as state on the ball, not separate ball types

## Context

M4/M5 add several effects that change what a ball can do — Breaker (one-hit-destroys Resistant
Bricks) and, in M5, Satellite Shield's launched balls (which are ordinary balls that start in the
Breaker state at launch instead of on pickup). Multi-ball and Satellite Shield also mean more than
one ball can be in play at once, so "the ball reaches the Death Zone, lose a life" no longer holds
as written.

## Decision

A ball carries an optional power-state property (today: Breaker, with its own duration timer)
rather than being modeled as distinct ball subclasses/scenes per effect. Catching Breaker sets
the state (with a fresh timer) on every ball currently in play; a Satellite Shield ball gets the
same state but starts its timer at launch instead of at pickup.

Alongside this, the Multi-ball Life Rule applies everywhere more than one ball can exist: a ball
reaching the Death Zone is just removed from play, and a life is lost only when the last ball
goes out — the same shape as Indestructible bricks not counting toward a level's win condition.

## Consequences

Adding a future ball-altering power-up (or the differently-functioning "Laser" Chris mentioned
wanting to add later) is a new state value and timer, not a new scene/subclass and duplicated
collision/bounce logic. The trade-off is that ball behavior branches on state internally rather
than being polymorphic across ball types; acceptable here since the state space is small and
shared behavior (bounce, collision, Death Zone handling) dominates.
