extends GutTest

const WinScreenScene := preload("res://src/shared/presentation/win_screen.tscn")

var win: WinScreen


func before_each() -> void:
	win = WinScreenScene.instantiate()
	add_child_autofree(win)


func test_starts_hidden_with_default_texts() -> void:
	assert_false(win.visible)
	assert_eq(win.get_node("%Emoji").text, "🏆")
	assert_eq(win.get_node("%Title").text, "You did it!")
	assert_eq(win.get_node("%PrimaryButton").text, "🔄 Play again")


func test_texts_can_be_set_per_game() -> void:
	var custom: WinScreen = WinScreenScene.instantiate()
	custom.emoji = "🌈"
	custom.title = "Beautiful!"
	custom.primary_text = "Keep"
	custom.secondary_text = "New"

	add_child_autofree(custom)

	assert_eq(custom.get_node("%Emoji").text, "🌈")
	assert_eq(custom.get_node("%Title").text, "Beautiful!")
	assert_eq(custom.get_node("%PrimaryButton").text, "Keep")
	assert_eq(custom.get_node("%SecondaryButton").text, "New")


func test_celebrate_shows_stars_and_confetti() -> void:
	win.celebrate("⭐⭐")

	assert_true(win.visible)
	assert_true(win.get_node("%Stars").visible)
	assert_eq(win.get_node("%Stars").text, "⭐⭐")
	assert_true(win.get_node("%Confetti").emitting)


func test_celebrate_without_stars_hides_star_row() -> void:
	win.celebrate()

	assert_false(win.get_node("%Stars").visible)


func test_confetti_spans_screen_width() -> void:
	win.celebrate("⭐")

	var screen := win.get_viewport_rect().size
	var confetti: CPUParticles2D = win.get_node("%Confetti")
	assert_eq(confetti.emission_rect_extents.x, screen.x * 0.5)
	assert_eq(confetti.position.x, screen.x * 0.5)


func test_primary_button_emits_signal() -> void:
	watch_signals(win)

	win.get_node("%PrimaryButton").pressed.emit()

	assert_signal_emitted(win, "primary_pressed")


func test_secondary_button_emits_signal() -> void:
	watch_signals(win)

	win.get_node("%SecondaryButton").pressed.emit()

	assert_signal_emitted(win, "secondary_pressed")
