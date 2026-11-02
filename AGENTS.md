# Builder notes

- Use Godot 4.7.2, with the project at the repository root.
- Run `godot --headless --path . --editor --import`, then
  `scripts/test-runner.sh` and `scripts/run-tests.sh`. No addon test framework.
- Godot may return zero after reporting a script/import error. Check output for
  `ERROR:` / `SCRIPT ERROR:` as CI and the runner do.
- Tests must explicitly quit; scripts extend SceneTree/MainLoop, scenes quit via
  their tree. A `*_test.tscn` owns the matching `*_test.gd`, which is not run twice.
- Commit new script `.uid` files, preserve scene UIDs, and never commit `.godot/`.
- `queue_free()` marks a brick immediately but deletes it at frame end. Check the
  deletion flag before emitting `brick_broken`; duplicate-hit tests must repeat
  the hit before yielding a frame so they exercise that window.
- PR descriptions explain the Godot concept and why the approach was chosen,
  including alternatives considered. For CI, editor import builds the resource
  cache before standalone headless tests; plain processes avoid an addon dependency.
