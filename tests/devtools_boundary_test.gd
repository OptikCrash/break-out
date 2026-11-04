extends SceneTree

# The Test Lab under devtools/ is development-only (docs/adr/0002): no
# production scene, script or resource may link to it, by path or by UID.
# Tests and devtools/ itself may. Production = every other Godot text file.

const DEVTOOLS := "res://devtools/"
const SKIPPED_DIRS := ["res://.godot/", "res://.git/", DEVTOOLS, "res://tests/"]
const SCANNED_EXTENSIONS := ["tscn", "gd", "tres", "godot"]

var failures := 0

func _initialize() -> void:
	var markers := _devtools_markers()
	_check(markers.has(DEVTOOLS), "Path marker is scanned")
	var lab_uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid("res://devtools/test_lab.tscn"))
	_check(markers.has(lab_uid), "Test Lab scene UID is scanned")
	var script_uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid("res://devtools/test_lab.gd"))
	_check(markers.has(script_uid), "Test Lab script UID is scanned")
	# Guard against a check that can never fail.
	_check(_find_marker('[ext_resource path="res://devtools/test_lab.tscn"]', markers) == DEVTOOLS,
		"A res:// devtools path is detected")
	_check(_find_marker('load("%s")' % lab_uid, markers) == lab_uid, "A devtools UID is detected")
	var files := _production_files("res://")
	_check(files.has("res://main.tscn") and files.has("res://project.godot"), "Production files are scanned")
	_check(not files.has("res://devtools/test_lab.gd"), "devtools/ itself is skipped")
	for path in files:
		var found := _find_marker(FileAccess.get_file_as_string(path), markers)
		_check(found.is_empty(), "%s must not reference devtools/ (found %s)" % [path, found])
	quit(1 if failures else 0)

func _devtools_markers() -> PackedStringArray:
	var markers := PackedStringArray([DEVTOOLS])
	for path in _files_under(DEVTOOLS):
		if path.get_extension() in ["uid", "import"]:
			continue
		var id := ResourceLoader.get_resource_uid(path)
		if id != ResourceUID.INVALID_ID:
			markers.append(ResourceUID.id_to_text(id))
	return markers

func _find_marker(text: String, markers: PackedStringArray) -> String:
	for marker in markers:
		if text.contains(marker):
			return marker
	return ""

func _production_files(dir: String) -> PackedStringArray:
	var result := PackedStringArray()
	for path in _files_under(dir):
		if path.get_extension() in SCANNED_EXTENSIONS:
			result.append(path)
	return result

func _files_under(dir: String) -> PackedStringArray:
	var result := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		result.append(dir + file)
	for sub in DirAccess.get_directories_at(dir):
		var sub_path := dir + sub + "/"
		if sub_path in SKIPPED_DIRS:
			continue
		result.append_array(_files_under(sub_path))
	return result

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
