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


func _picture() -> AtlasTexture:
	return button.icon as AtlasTexture


func _frame_duration() -> float:
	return 1.0 / BOY.get_animation_speed(IDLE)


func test_starts_on_first_idle_frame() -> void:
	assert_eq(_picture().atlas, BOY.get_frame_texture(IDLE, 0))


func test_crop_covers_every_idle_frame() -> void:
	var region := Rect2i(_picture().region)

	for i in BOY.get_frame_count(IDLE):
		var body := RunnerSprite.visible_rect(BOY.get_frame_texture(IDLE, i))
		assert_true(region.encloses(body), "frame %d outside crop" % i)


func test_crop_is_smaller_than_canvas() -> void:
	var canvas := BOY.get_frame_texture(IDLE, 0).get_size()

	assert_lt(_picture().region.size.x, canvas.x)


func test_advances_to_next_frame_over_time() -> void:
	button._process(_frame_duration() * 1.5)

	assert_eq(_picture().atlas, BOY.get_frame_texture(IDLE, 1))


func test_stays_on_frame_within_frame_duration() -> void:
	button._process(_frame_duration() * 0.5)

	assert_eq(_picture().atlas, BOY.get_frame_texture(IDLE, 0))


func test_loops_back_to_first_frame() -> void:
	var loop := BOY.get_frame_count(IDLE) * _frame_duration()

	button._process(loop + _frame_duration() * 0.5)

	assert_eq(_picture().atlas, BOY.get_frame_texture(IDLE, 0))


func test_selected_button_animates() -> void:
	assert_true(button.is_processing())


func test_unselected_button_does_not_animate() -> void:
	button.button_pressed = false

	assert_false(button.is_processing())


func test_unselected_button_shows_first_frame() -> void:
	button._process(_frame_duration() * 1.5)

	button.button_pressed = false

	assert_eq(_picture().atlas, BOY.get_frame_texture(IDLE, 0))


func test_reselected_button_restarts_animation() -> void:
	button.button_pressed = false

	button.button_pressed = true

	assert_true(button.is_processing())
	assert_eq(_picture().atlas, BOY.get_frame_texture(IDLE, 0))


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
