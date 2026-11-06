extends RefCounted

const CAPACITY := 10

static func valid_initials(initials: String) -> bool:
	if initials.length() != 3:
		return false
	for index in 3:
		if initials.unicode_at(index) < 65 or initials.unicode_at(index) > 90:
			return false
	return true

static func qualifies(rows: Array, score: int) -> bool:
	return rows.size() < CAPACITY or score >= rows.back().score

# The insertion index is also the row to highlight after confirmation (zero-based).
static func insertion_index(rows: Array, score: int) -> int:
	for index in rows.size():
		if score >= rows[index].score:
			return index
	return rows.size()
