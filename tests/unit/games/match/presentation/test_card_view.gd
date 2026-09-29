extends GutTest

const CardScene := preload("res://src/games/match/presentation/card_view.tscn")

var card: CardView


func before_each() -> void:
	card = CardScene.instantiate()
	card.animation_speed = 100.0
	add_child_autofree(card)
	card.setup("🐶", 120.0)


func _finish_animations() -> void:
	await wait_process_frames(4)


func _style() -> StyleBox:
	return card.get_theme_stylebox("normal")


func test_setup_shows_back() -> void:
	assert_eq(card.text, CardView.BACK_TEXT)
	assert_false(card.shows_face)
	assert_eq(_style(), card.back_style)
	assert_eq(card.face_text, "🐶")


func test_setup_sizes_card() -> void:
	assert_eq(card.custom_minimum_size, Vector2(120, 120))
	assert_eq(card.pivot_offset, Vector2(60, 60))
	assert_eq(card.get_theme_font_size("font_size"), int(120 * CardView.BACK_FONT_RATIO))


func test_turn_up_shows_face_after_flip() -> void:
	card.turn_up()
	assert_true(card.shows_face)

	await _finish_animations()

	assert_eq(card.text, "🐶")
	assert_eq(_style(), card.front_style)
	assert_eq(card.get_theme_font_size("font_size"), int(120 * CardView.FACE_FONT_RATIO))
	assert_almost_eq(card.scale.x, 1.0, 0.001)


func test_turn_down_shows_back_again() -> void:
	card.turn_up()
	await _finish_animations()

	card.turn_down()
	await _finish_animations()

	assert_false(card.shows_face)
	assert_eq(card.text, CardView.BACK_TEXT)


func test_celebrate_marks_matched_and_blocks_taps() -> void:
	card.turn_up()

	card.celebrate()
	await _finish_animations()

	assert_true(card.shows_matched)
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(_style(), card.matched_style)
	assert_eq(card.text, "🐶")
	assert_almost_eq(card.scale, Vector2.ONE, Vector2(0.001, 0.001))


func test_flip_then_celebrate_in_one_frame_queue_up() -> void:
	card.turn_up()
	card.celebrate()

	await _finish_animations()

	assert_eq(card.text, "🐶")
	assert_eq(_style(), card.matched_style)


func test_celebrate_while_flip_is_running_finishes_flip_first() -> void:
	card.animation_speed = 1.0
	card.turn_up()
	await wait_process_frames(2)
	assert_lt(card.scale.x, 1.0)

	card.animation_speed = 100.0
	card.celebrate()

	assert_eq(card.text, "🐶")
	await _finish_animations()
	assert_eq(_style(), card.matched_style)
	assert_almost_eq(card.scale, Vector2.ONE, Vector2(0.001, 0.001))


func test_wobble_ends_upright() -> void:
	card.wobble()

	await _finish_animations()

	assert_almost_eq(card.rotation, 0.0, 0.001)


func test_resize_updates_size_and_font() -> void:
	card.resize(200.0)

	assert_eq(card.custom_minimum_size, Vector2(200, 200))
	assert_eq(card.get_theme_font_size("font_size"), int(200 * CardView.BACK_FONT_RATIO))


func test_setup_again_resets_a_used_card() -> void:
	card.turn_up()
	card.celebrate()
	await _finish_animations()

	card.setup("🐱", 120.0)

	assert_false(card.shows_face)
	assert_false(card.shows_matched)
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(card.text, CardView.BACK_TEXT)
	assert_eq(card.face_text, "🐱")
