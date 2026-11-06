extends SceneTree

const Store := preload("res://high_score_store.gd")
const Rules := preload("res://high_score_rules.gd")
const DIR := "user://high_score_store_test/"
const SAVE := DIR + "board.json"
var failures := 0

func _initialize() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(DIR)
	var store := Store.new(SAVE)
	_check(store.records().is_empty(), "Missing save starts empty")
	_check(store.qualifies(0), "Empty board qualifies zero")
	for invalid in ["", "AB", "ABCD", "abc", "AbC", "A B", "AB1", "ÅBC", "ＡBC", "AB\n"]:
		_check(not Rules.valid_initials(invalid), "Reject non-ASCII or non-three initials")
		_check(store.submit(invalid, 100) == -1, "Invalid initials cannot save")
	_check(not FileAccess.file_exists(SAVE), "Validation and qualification do not write")
	_check(Rules.valid_initials("AZZ"), "Accept ASCII endpoints")
	_check(store.submit("OLD", 100) == 0, "First confirmed run ranks first")
	_check(store.qualifies(0), "Partial board accepts a lower score")
	_check(store.submit("LOW", 0) == 1, "Lower score follows existing row")
	_check(store.submit("NEW", 100) == 0, "New equal score precedes old")
	_check(store.records() == [{"initials": "NEW", "score": 100}, {"initials": "OLD", "score": 100}, {"initials": "LOW", "score": 0}], "Rows contain only initials and integer score")
	var copy := store.records()
	copy[0].score = 999
	copy.clear()
	_check(store.records()[0].score == 100, "Returned rows cannot mutate board")
	for score in range(10, 80, 10):
		store.submit("MID", score)
	_check(store.records().size() == 10, "Ten records fill board")
	_check(not store.qualifies(-1), "Below tenth does not qualify")
	_check(store.submit("BAD", -1) == -1, "Below tenth does not save")
	_check(store.qualifies(0), "Equal tenth qualifies")
	_check(store.submit("TIE", 0) == 9, "Equal tenth displaces older tenth")
	_check(store.records()[9] == {"initials": "TIE", "score": 0}, "New tenth retained")
	_check(store.submit("TOP", 200) == 0, "Higher score ranks first")
	_check(store.records().size() == 10 and store.records()[9].score == 10, "Top ten trims lowest")
	_check(Store.new(SAVE).records() == store.records(), "New instance loads exact board and tie order")
	_check(store.submit("MAX", 9223372036854775807) == 0, "Full int64 score accepted")
	_check(Store.new(SAVE).records() == store.records(), "Persistence preserves int64 precision")
	DirAccess.make_dir_absolute(SAVE + ".tmp")
	var before := store.records()
	_check(store.submit("ERR", 9223372036854775807) == -1, "Blocked temporary write rejects submission")
	_check(store.records() == before and Store.new(SAVE).records() == before, "Failed write preserves memory and previous save")
	DirAccess.remove_absolute(SAVE + ".tmp")
	_write("[]")
	_check(Store.new(SAVE).records().is_empty(), "Saved empty board loads empty")
	# Hand-built synthetic corrupt saves: reject the whole board, never partial rows.
	for corrupt in ["{", "null", "{}", '[{"initials":"ABC","score":1}]', '[{"initials":"abc","score":"1"}]', '[{"initials":"ABC","score":"9223372036854775808"}]', '[{"initials":"ABC","score":"1","date":"today"}]', '[{"initials":"ABC","score":"1"},{"initials":"DEF","score":"2"}]', '[{"initials":"ABC","score":"1"},{}]']:
		_write(corrupt)
		_check(Store.new(SAVE).records().is_empty(), "Malformed save recovers empty")
	var oversized: Array = []
	for index in 11:
		oversized.append({"initials": "AAA", "score": "1"})
	_write(JSON.stringify(oversized))
	_check(Store.new(SAVE).records().is_empty(), "Oversized save is malformed")
	DirAccess.remove_absolute(SAVE)
	DirAccess.make_dir_absolute(SAVE)
	var unreadable := Store.new(SAVE)
	_check(unreadable.records().is_empty(), "Directory instead of save recovers empty")
	_check(unreadable.submit("ABC", 1) == -1 and unreadable.records().is_empty(), "Failed write leaves memory unchanged")
	for path in ["res://forbidden.json", "/tmp/forbidden.json", "user://../forbidden.json"]:
		_check(Store.new(path).submit("ABC", 1) == -1, "Reject paths outside user storage")
	_cleanup()
	quit(1 if failures else 0)

func _write(contents: String) -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _cleanup() -> void:
	DirAccess.remove_absolute(SAVE)
	DirAccess.remove_absolute(SAVE + ".tmp")
	DirAccess.remove_absolute(DIR)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
