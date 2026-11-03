Closes #26

The paddle now follows the mouse, and a left click launches the ball. A/D, the arrow keys and
Space work exactly as before.

## Click to launch: one more event on the `launch` action

The Input Map (`project.godot`'s `[input]` section) lets one action have several events. The
change adds a left mouse button event to `launch`, next to Space. `ball.gd` already asks
`Input.is_action_just_pressed("launch")`, so it didn't change. Godot updates action state in the
`Input` singleton before the GUI sees the event, so the click counts even over the play field's
ColorRects. A gamepad button can be added the same way later.

**Alternative rejected:** checking for `InputEventMouseButton` in `ball.gd`. That would mean two
launch code paths, and remapping controls in a settings menu wouldn't cover it.

## Paddle follows the mouse: last input wins

`paddle.gd` keeps one flag, `following_mouse`:
- an `InputEventMouseMotion` sets it, and stores the mouse's x in world space;
- holding a move key clears it, and the paddle runs the old keyboard code unchanged.

So whichever device the player last touched is in control. A mouse resting on the desk sends no
motion events, so it never pulls against the keyboard. Releasing the key leaves the paddle where
it is, and it won't jump back to the mouse until the mouse moves again. **Rejected:** adding the
two inputs together, or polling the mouse position every frame. Either way a still mouse would
keep dragging the paddle back while a key is held, which is the jitter the issue warns about.

### Godot ideas involved

- **`_input` vs `_unhandled_input`.** `_unhandled_input` only gets events the GUI didn't consume.
  The backgrounds, walls and bricks are `ColorRect`s, which are Controls with
  `mouse_filter = Stop`, so mouse motion over the play field would never arrive. Reading motion
  in `_input` avoids editing six ColorRects across `main.tscn` and `brick.tscn`. Only motion is read there, and only
  to aim the paddle. A future pause screen pauses the tree, and paused nodes don't get `_input`.
- **Viewport vs world coordinates.** `event.position` is in viewport pixels.
  `get_canvas_transform().affine_inverse()` converts it to world space. That stays correct with
  `canvas_items` stretch when the window is resized, and if a camera is ever added.
- **The walls are the clamp.** The paddle isn't moved by setting `position`. Each physics step it
  gets exactly the velocity that would take it to the mouse
  (`(mouse_x - global_position.x) / delta`) and calls `move_and_slide()` as before. The
  `CharacterBody2D` collides with the wall shapes, so the walkable bounds are the walls'
  collision shapes themselves, with no second copy of the wall positions in code. Setting
  `position` directly would need hand-written bounds and would let the paddle pass through
  anything solid. The speed limit (`speed`) still applies to keyboard movement only. The paddle
  follows the mouse exactly, which is how mouse paddles usually feel.

## Tests

New `tests/paddle_mouse_test.gd` (headless, no addon) loads `main.tscn` and checks:
- `launch` includes a left mouse click;
- the paddle follows the mouse, and the left and right walls stop it at x = 480 and 1440
  (wall inner edge ± half the paddle);
- in a 1280x720 window, the window's centre still maps to the middle of the field;
- a held D key moves the paddle away from a mouse that isn't moving, releasing D doesn't snap it
  back, and moving the mouse again takes control back;
- a left click launches the ball.

`tests/title_screen_test.gd` already checks that the click that starts the game from the title
does not also launch the ball. It still passes now that a click is a `launch` event too.

Validation: headless editor import gave no errors. All seven `tests/*_test.gd` exited 0 when run
one by one with `godot --headless --path . --script ...`, with no `ERROR:` / `FAIL` output.
`scripts/run-tests.sh` and `scripts/test-runner.sh` weren't run directly here because running
shell scripts needed a permission this environment didn't have; CI runs both. There's no display
here, so nobody has tried the mouse feel in a real window yet.

README lists the mouse controls. AGENTS.md notes the action-vs-GUI ordering, why `paddle.gd` uses
`_input`, and that headless tests start with a 64x64 window.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
