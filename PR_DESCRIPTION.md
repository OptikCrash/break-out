Closes #8

MessageLabel now uses Godot's Full Rect anchors with zero offsets. Because it sits directly under a CanvasLayer, its anchors resolve against the viewport. The label fills the actual viewport, and its existing horizontal and vertical center alignment places both Game Over and Win text at the viewport center. Previously, center alignment only centered text inside a fixed rectangle left over from the older scene layout.

Fixed pixel offsets for 1920×1080 were considered and rejected: they would encode another viewport size instead of allowing Godot's layout system to size the label. Full Rect follows the viewport automatically; the project's canvas_items stretch mode scales the logical canvas when the window is resized. No gameplay rules or art were changed by this fix.

Merged origin/develop and resolved AGENTS.md by preserving both the project/test conventions and UI layout notes.

Validation:
- Godot 4.7.2 headless editor import completed without script/import errors.
- scripts/test-runner.sh passed its discovery and failure-handling checks.
- scripts/run-tests.sh passed the new HUD scene layout check: empty text and the actual multiline Game Over/Win messages fill the visible viewport with centered alignment at 1920×1080 and after resizing the headless window to 1280×720.
- git diff --check passed.

The headless check verifies layout geometry and alignment. A visual Game Over/Win playthrough remains pending because this environment has no display, as required by PLAN.md's structural regression scope.
