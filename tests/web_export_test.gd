extends SceneTree


func _initialize() -> void:
	var preset := ConfigFile.new()
	var error := preset.load("res://export_presets.cfg")
	if error != OK:
		push_error("Cannot load export_presets.cfg: %s" % error_string(error))
		quit(1)
		return

	var expected := {
		"name": "Web",
		"platform": "Web",
		"runnable": true,
		"export_filter": "all_resources",
		"export_path": "build/web/index.html",
	}
	for key in expected:
		if preset.get_value("preset.0", key, null) != expected[key]:
			push_error("Web export preset has an invalid or missing %s" % key)
			quit(1)
			return

	# Static hosting must not depend on cross-origin isolation headers.
	for key in ["variant/thread_support", "variant/extensions_support"]:
		if preset.get_value("preset.0.options", key, null) != false:
			push_error("Web export must disable %s for ordinary static hosting" % key)
			quit(1)
			return

	var exclusions: String = preset.get_value("preset.0", "exclude_filter", "")
	for pattern in ["*_test.gd", "*_test.tscn", "scripts/*", "build/*"]:
		if pattern not in exclusions.split(","):
			push_error("Web export must exclude %s" % pattern)
			quit(1)
			return
	quit(0)
