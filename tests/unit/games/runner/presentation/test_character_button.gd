extends GutTest

const BOY := preload("res://assets/runner/characters/little_boy.tres")
const IDLE := RunnerSprite.ANIM_IDLE

var button: CharacterButton


func before_each() -> void:
	button = CharacterButton.new()
	button.frames = BOY
	button.toggle_mode = true
	button.button_pressed = true
	add_child_autofree(button)


func _frame_duration() -> float:
	return 1.0 / BOY.get_animation_speed(IDLE)


func test_starts_on_first_idle_frame() -> void:
	assert_eq(button.icon, BOY.get_frame_texture(IDLE, 0))


func test_advances_to_next_frame_over_time() -> void:
	button._process(_frame_duration() * 1.5)

	assert_eq(button.icon, BOY.get_frame_texture(IDLE, 1))


func test_stays_on_frame_within_frame_duration() -> void:
	button._process(_frame_duration() * 0.5)

	assert_eq(button.icon, BOY.get_frame_texture(IDLE, 0))


func test_loops_back_to_first_frame() -> void:
	var loop := BOY.get_frame_count(IDLE) * _frame_duration()

	button._process(loop + _frame_duration() * 0.5)

	assert_eq(button.icon, BOY.get_frame_texture(IDLE, 0))


func test_selected_button_animates() -> void:
	assert_true(button.is_processing())


func test_unselected_button_does_not_animate() -> void:
	button.button_pressed = false

	assert_false(button.is_processing())


func test_unselected_button_shows_first_frame() -> void:
	button._process(_frame_duration() * 1.5)

	button.button_pressed = false

	assert_eq(button.icon, BOY.get_frame_texture(IDLE, 0))


func test_reselected_button_restarts_animation() -> void:
	button.button_pressed = false

	button.button_pressed = true

	assert_true(button.is_processing())
	assert_eq(button.icon, BOY.get_frame_texture(IDLE, 0))


func test_unselected_on_ready_does_not_animate() -> void:
	var other := CharacterButton.new()
	other.frames = BOY
	other.toggle_mode = true

	add_child_autofree(other)

	assert_false(other.is_processing())


func test_hidden_selected_button_does_not_animate() -> void:
	button.hide()

	assert_false(button.is_processing())


func test_stops_processing_when_parent_hides() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	button.reparent(parent)

	parent.hide()

	assert_false(button.is_processing())


func test_resumes_when_parent_shows_again() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	button.reparent(parent)
	parent.hide()

	parent.show()

	assert_true(button.is_processing())


func _locked_button() -> CharacterButton:
	var other := CharacterButton.new()
	other.frames = BOY
	other.character_id = &"cat"
	other.toggle_mode = true
	add_child_autofree(other)
	other.set_locked(true, 500)
	return other


func test_starts_unlocked() -> void:
	assert_false(button.is_locked)
	assert_eq(button.text, "")


func test_locked_shows_price_and_dims_art() -> void:
	var locked := _locked_button()

	assert_true(locked.is_locked)
	assert_eq(locked.text, "🔒 🪙 500")
	assert_eq(locked.get_theme_color(&"icon_normal_color"), CharacterButton.LOCKED_ICON_COLOR)


func test_locked_tap_requests_shop_without_selecting() -> void:
	var locked := _locked_button()
	watch_signals(locked)

	locked.pressed.emit()
	locked._pressed()

	assert_signal_emitted_with_parameters(locked, "shop_requested", [&"cat"])
	assert_false(locked.button_pressed)
	assert_false(locked.is_processing())


func test_unlocked_tap_does_not_request_shop() -> void:
	watch_signals(button)

	button._pressed()

	assert_signal_not_emitted(button, "shop_requested")


func test_unlocking_restores_toggle_and_art() -> void:
	var locked := _locked_button()

	locked.set_locked(false, 500)

	assert_false(locked.is_locked)
	assert_true(locked.toggle_mode)
	assert_eq(locked.text, "")
	assert_false(locked.has_theme_color_override(&"icon_normal_color"))


func test_locked_button_cannot_be_pressed() -> void:
	var locked := _locked_button()

	locked.button_pressed = true

	assert_false(locked.button_pressed)
