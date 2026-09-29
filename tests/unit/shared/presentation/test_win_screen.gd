extends GutTest

const WinScreenScene := preload("res://src/shared/presentation/win_screen.tscn")

var win: WinScreen


func before_each() -> void:
	win = WinScreenScene.instantiate()
	add_child_autofree(win)


func test_starts_hidden() -> void:
	assert_false(win.visible)


func test_celebrate_shows_stars_and_confetti() -> void:
	win.celebrate("⭐⭐")

	assert_true(win.visible)
	assert_eq(win.get_node("%Stars").text, "⭐⭐")
	assert_true(win.get_node("%Confetti").emitting)


func test_confetti_spans_screen_width() -> void:
	win.celebrate("⭐")

	var screen := win.get_viewport_rect().size
	var confetti: CPUParticles2D = win.get_node("%Confetti")
	assert_eq(confetti.emission_rect_extents.x, screen.x * 0.5)
	assert_eq(confetti.position.x, screen.x * 0.5)


func test_play_again_button_emits_signal() -> void:
	watch_signals(win)

	win.get_node("%PlayAgainButton").pressed.emit()

	assert_signal_emitted(win, "play_again_pressed")


func test_home_button_emits_signal() -> void:
	watch_signals(win)

	win.get_node("%HomeButton").pressed.emit()

	assert_signal_emitted(win, "home_pressed")
