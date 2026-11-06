extends RefCounted

const Rules := preload("res://high_score_rules.gd")
const DEFAULT_PATH := "user://high_scores.json"

var _path: String
var _rows: Array[Dictionary] = []

# An alternate local path lets tests isolate their saves from the player's board.
func _init(path: String = DEFAULT_PATH) -> void:
	if path.begins_with("user://") and not ".." in path.replace("\\", "/").split("/"):
		_path = path
		_load_board()

# Rows contain only initials: String and score: int; rank is their array position + 1.
func records() -> Array[Dictionary]:
	return _rows.duplicate(true)

func qualifies(score: int) -> bool:
	return Rules.qualifies(_rows, score)

# Call only for a completed run after initials confirmation. -1 means no row saved.
# Commit memory only after a successful write, so a caller can retry a failed save.
func submit(initials: String, score: int) -> int:
	if _path.is_empty() or not Rules.valid_initials(initials) or not qualifies(score):
		return -1
	var next := records()
	var index := Rules.insertion_index(next, score)
	next.insert(index, {"initials": initials, "score": score})
	next.resize(mini(next.size(), Rules.CAPACITY))
	if not _save_board(next):
		return -1
	_rows = next
	return index

func _save_board(rows: Array[Dictionary]) -> bool:
	var encoded: Array = []
	for row in rows:
		# Decimal strings on disk avoid JSON's floating-point loss for 64-bit scores.
		encoded.append({"initials": row.initials, "score": str(row.score)})
	# Write beside the save first so a failed write does not truncate the old board.
	var temporary := _path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(encoded))
	file.flush()
	var written := file.get_error() == OK
	file.close()
	if written and DirAccess.rename_absolute(temporary, _path) == OK:
		return true
	DirAccess.remove_absolute(temporary)
	return false

func _load_board() -> void:
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or file.get_error() != OK:
		return
	var data: Variant = json.data
	if not data is Array or data.size() > Rules.CAPACITY:
		return
	var loaded: Array[Dictionary] = []
	for row in data:
		if not row is Dictionary or row.size() != 2:
			return
		if not row.get("initials") is String or not row.get("score") is String:
			return
		if not Rules.valid_initials(row.initials) or not row.score.is_valid_int():
			return
		var score: int = row.score.to_int()
		# Canonical round-trip also rejects overflow instead of accepting a clamped int.
		if str(score) != row.score or (not loaded.is_empty() and score > loaded.back().score):
			return
		loaded.append({"initials": row.initials, "score": score})
	_rows = loaded
