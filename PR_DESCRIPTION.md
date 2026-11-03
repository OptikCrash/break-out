Closes #25

On Game Over or Win, two buttons now appear under the message: **Restart (R)** and **Back to
Title**. Restart has focus when they appear, so Enter/Space or gamepad A picks it right away.
Left/Right (arrows or D-pad) moves between the buttons, and the mouse works as well. `R` still
restarts directly. While playing, the buttons are hidden.

## The Godot ideas

**Signals from the HUD, decisions in `main.gd`.** `HUD.tscn` connects each button's `pressed`
signal to its own signals, `restart_pressed` and `back_to_title_pressed`. `main.gd` connects to
those in `_ready()`. The HUD only reports what the player chose. The game decides what that
means: `restart()` (the same `reload_current_scene()` that R used) or `back_to_title()`
(`change_scene_to_file("res://TitleScreen.tscn")`, the pattern from #23). R and the button
call the same `restart()`. It clears `reset_ready` first, so R and a click in the same frame
can't request two scene changes.
*Alternative considered:* calling `get_tree().reload_current_scene()` straight from `hud.gd`.
It's shorter, but then the HUD would own game flow, and R and the button would have two copies
of the restart logic.

**Focus.** A Control with focus gets keyboard and gamepad input. Buttons in an
`HBoxContainer` are focus neighbours of each other automatically, so `ui_left`/`ui_right` move
between them without setting anything up. `hud.show_end_buttons()` calls
`Restart.grab_focus()` when the buttons appear.

**`ui_accept` had no gamepad button.** Godot's built-in `ui_accept` action only has Enter,
Keypad Enter and Space. The new test showed that gamepad A did nothing, and that the title
screen from #23 didn't start on A either, although the #23 PR said it did. `project.godot` now
overrides `ui_accept` to add joypad A. An override replaces the whole built-in list, so the
three keys are listed again. The D-pad was already bound to `ui_left`/`ui_right`.

**No physics-frame wait needed here.** `Button`s fire on *release*, for keyboard and gamepad
too. So pressing Space on Restart doesn't give the new scene a fresh "just pressed" Space, and
the ball stays on the paddle (the test checks this). The title screen still needs its wait,
because it reacts to the *press* in `_unhandled_input`.

## Layout

`EndButtons` is anchored to the viewport centre (it sits directly under the `Hud`
`CanvasLayer`) and offset 96 px below it, under the centred message. It grows from its centre,
so it stays centred at 1920x1080 and after a resize. I raised `MessageLabel`'s font size to 64
so the heading isn't smaller than the 32 px button text. Its anchoring from #8 is unchanged.
The buttons use the default theme, like the rest of the UI, so there's no new art.

## Message text

I dropped the hard-coded "\nPress R to restart" and kept the shortcut in the button label
instead (**Restart (R)**). That way the hint is still visible but isn't shown twice. The
messages are now just "Game Over!" / "You Win!".

## Tests

- New `tests/end_screen_test.gd`:
  - The buttons are hidden during play, and R does nothing then.
  - On both Game Over and Win, the buttons appear with Restart focused.
  - They are centred, below the message and on screen at 1920x1080 and 1280x720.
  - Each of these reloads a fresh game without launching the ball: R, Enter, Space, gamepad A
    and a click on Restart.
  - Each of these opens the title screen: Right then Enter, D-pad right then A, and a click on
    Back to Title.
- `title_screen_test.gd` also covers gamepad A now.
- `hud_layout_test.gd` and `brick_hit_test.gd` use the new message text, and `brick_hit_test`
  checks that the buttons appear on a win.
- `scripts/run-tests.sh`: 7 tests pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
