extends RefCounted

# Shared destruction/score path for balls and bolts. take_hit guards queued bricks.
static func hit(brick: Node, breaker: bool, report: Callable, contact := Vector2.INF) -> bool:
	if brick.take_hit(breaker, contact):
		report.call(brick.definition.points)
		return true
	return false
