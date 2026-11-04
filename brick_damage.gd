extends RefCounted

# Shared destruction/score path for balls and bolts. take_hit guards queued bricks.
static func hit(brick: Node, breaker: bool, report: Callable) -> bool:
	if brick.take_hit(breaker):
		report.call(brick.definition.points)
		return true
	return false
