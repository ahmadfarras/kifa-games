extends GutTest

const ColoringGameScene := preload("res://src/games/coloring/presentation/coloring_game.tscn")

var session: ColoringSession
var game: ColoringGame


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	session = ColoringSession.new(rng)
	game = ColoringGameScene.instantiate()
	game.setup(session)
	add_child_autofree(game)


func _picture_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in game.get_node("%PictureButtons").get_children():
		if child.visible:
			buttons.append(child)
	return buttons


func _swatches() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in game.get_node("%Palette").get_children():
		buttons.append(child)
	return buttons


func _open(index: int) -> void:
	_picture_buttons()[index].pressed.emit()


func _tap(region: int) -> void:
	(game.get_node("%Canvas") as ColoringCanvas).region_tapped.emit(region)


func _shown_color(region: int) -> Color:
	return game._display[region]


func _fire(timer_name: String) -> void:
	var timer: Timer = game.get_node(timer_name)
	timer.stop()
	timer.timeout.emit()


func _finish() -> WinScreen:
	return game.get_node("%FinishScreen")


func test_starts_on_pick_screen_with_all_pictures() -> void:
	assert_true(game.get_node("%PickScreen").visible)
	assert_false(game.get_node("%ColorScreen").visible)
	assert_eq(_picture_buttons().size(), PictureLibrary.IDS.size())
	assert_eq(_picture_buttons()[0].text, PictureLibrary.ICONS[0])


func test_palette_has_colors_and_eraser() -> void:
	assert_eq(_swatches().size(), ColoringGame.PALETTE.size() + 1)
	assert_eq(_swatches()[-1].text, ColoringGame.ERASER_TEXT)


func test_opening_picture_shows_blank_page_with_first_color() -> void:
	_open(1)

	assert_true(game.get_node("%ColorScreen").visible)
	assert_eq(session.page.colors.size(), PictureLibrary.build(&"fish").region_count)
	assert_eq(session.page.brush, 0)
	assert_eq(_shown_color(0), ColoringGame.BLANK_COLOR)
	assert_eq(_swatches()[0].scale, ColoringGame.SELECTED_SCALE)


func test_tap_paints_region_with_selected_color() -> void:
	_open(0)
	_swatches()[4].pressed.emit()

	_tap(3)

	assert_eq(session.page.colors[3], 4)
	assert_eq(_shown_color(3), ColoringGame.PALETTE[4])


func test_picking_swatch_highlights_only_it() -> void:
	_open(0)

	_swatches()[2].pressed.emit()

	assert_eq(_swatches()[2].scale, ColoringGame.SELECTED_SCALE)
	assert_eq(_swatches()[0].scale, Vector2.ONE)


func test_eraser_makes_region_blank() -> void:
	_open(0)
	_tap(2)
	_swatches()[-1].pressed.emit()

	_tap(2)

	assert_eq(session.page.colors[2], ColoringPage.BLANK)
	assert_eq(_shown_color(2), ColoringGame.BLANK_COLOR)


func test_painting_every_region_celebrates_after_delay() -> void:
	_open(0)
	for region in session.page.colors.size():
		_tap(region)
	assert_false(_finish().visible)

	_fire("%CompleteTimer")

	assert_true(_finish().visible)
	assert_eq(_finish().get_node("%Title").text, "Beautiful!")
	assert_false(_finish().get_node("%Stars").visible)


func test_finish_button_celebrates_any_time() -> void:
	_open(0)

	game.get_node("%FinishButton").pressed.emit()

	assert_true(_finish().visible)


func test_keep_coloring_hides_celebration() -> void:
	_open(0)
	game.get_node("%FinishButton").pressed.emit()

	_finish().primary_pressed.emit()

	assert_false(_finish().visible)
	assert_true(game.get_node("%ColorScreen").visible)


func test_new_picture_returns_to_pick_screen() -> void:
	_open(0)
	game.get_node("%FinishButton").pressed.emit()

	_finish().secondary_pressed.emit()

	assert_true(game.get_node("%PickScreen").visible)
	assert_false(_finish().visible)


func test_magic_reveals_colors_one_by_one() -> void:
	_open(3)

	game.get_node("%MagicButton").pressed.emit()

	assert_true(session.page.is_complete())
	assert_eq(_shown_color(0), ColoringGame.BLANK_COLOR)
	_fire("%MagicTimer")
	assert_eq(_shown_color(0), ColoringGame.PALETTE[session.page.colors[0]])
	assert_eq(_shown_color(1), ColoringGame.BLANK_COLOR)


func test_magic_timer_stops_after_last_region() -> void:
	_open(3)
	game.get_node("%MagicButton").pressed.emit()
	var timer: Timer = game.get_node("%MagicTimer")

	for region in session.page.colors.size():
		timer.timeout.emit()

	assert_true(timer.is_stopped())
	for region in session.page.colors.size():
		assert_eq(_shown_color(region), ColoringGame.PALETTE[session.page.colors[region]])


func test_tap_during_magic_shows_everything_then_paints() -> void:
	_open(3)
	game.get_node("%MagicButton").pressed.emit()
	_swatches()[-1].pressed.emit()

	_tap(0)

	assert_true(game.get_node("%MagicTimer").is_stopped())
	assert_eq(_shown_color(0), ColoringGame.BLANK_COLOR)
	assert_eq(_shown_color(1), ColoringGame.PALETTE[session.page.colors[1]])


func test_clear_wipes_page_and_stops_magic() -> void:
	_open(2)
	_tap(1)
	game.get_node("%MagicButton").pressed.emit()

	game.get_node("%ClearButton").pressed.emit()

	assert_true(game.get_node("%MagicTimer").is_stopped())
	for region in session.page.colors.size():
		assert_eq(_shown_color(region), ColoringGame.BLANK_COLOR)


func test_pictures_button_returns_to_pick_screen() -> void:
	_open(0)

	game.get_node("%PicturesButton").pressed.emit()

	assert_true(game.get_node("%PickScreen").visible)
	assert_false(game.get_node("%ColorScreen").visible)


func test_palette_rows_follow_orientation() -> void:
	var screen := game.get_viewport_rect().size
	var palette: GridContainer = game.get_node("%Palette")

	var expected := _swatches().size() if screen.x > screen.y else ceili(_swatches().size() / 2.0)
	assert_eq(palette.columns, expected)


func test_back_button_requests_exit() -> void:
	watch_signals(game)

	game.get_node("%BackButton").pressed.emit()

	assert_signal_emitted(game, "exit_requested")
