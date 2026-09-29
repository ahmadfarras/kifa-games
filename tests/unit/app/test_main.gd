extends GutTest

const MainScene := preload("res://src/app/main.tscn")

var main: Node


func before_each() -> void:
	main = MainScene.instantiate()
	add_child_autofree(main)


func _current() -> Node:
	for child in main.get_children():
		if not child.is_queued_for_deletion():
			return child
	return null


func test_default_font_falls_back_to_bundled_emoji_once() -> void:
	var emoji: Font = load(main.EMOJI_FONT)

	main.use_bundled_emoji()

	assert_eq(ThemeDB.fallback_font.fallbacks.count(emoji), 1)


func test_emoji_font_has_every_emoji_used() -> void:
	var emoji: Font = load(main.EMOJI_FONT)

	for text in ["⬅️", "🏠", "⭐", "🏆", "✨", "🧽", "✅", "🌈", "🐶", "🦄", "🎲", "💫"]:
		for char in text:
			# U+FE0F only selects emoji style (handled by the font's variation table); it has no glyph.
			if char.unicode_at(0) != 0xFE0F:
				assert_true(emoji.has_char(char.unicode_at(0)), "missing %s" % char)


func test_starts_on_hub() -> void:
	assert_true(_current() is Hub)


func test_choosing_runner_opens_runner_on_its_start_screen() -> void:
	(_current() as Hub).game_chosen.emit(Hub.RUNNER)

	var game := _current() as RunnerGame
	assert_not_null(game)
	assert_true(game.get_node("%RunnerUi").get_node("%StartScreen").visible)


func test_choosing_match_opens_match_on_its_start_screen() -> void:
	(_current() as Hub).game_chosen.emit(Hub.MATCH)

	var game := _current() as MatchGame
	assert_not_null(game)
	assert_true(game.get_node("%StartScreen").visible)


func test_choosing_math_opens_math_on_its_pick_screen() -> void:
	(_current() as Hub).game_chosen.emit(Hub.MATH)

	var game := _current() as MathGame
	assert_not_null(game)
	assert_true(game.get_node("%PickScreen").visible)


func test_math_exit_returns_to_hub() -> void:
	(_current() as Hub).game_chosen.emit(Hub.MATH)

	(_current() as MathGame).exit_requested.emit()

	assert_true(_current() is Hub)


func test_choosing_coloring_opens_coloring_on_its_pick_screen() -> void:
	(_current() as Hub).game_chosen.emit(Hub.COLORING)

	var game := _current() as ColoringGame
	assert_not_null(game)
	assert_true(game.get_node("%PickScreen").visible)


func test_coloring_exit_returns_to_hub() -> void:
	(_current() as Hub).game_chosen.emit(Hub.COLORING)

	(_current() as ColoringGame).exit_requested.emit()

	assert_true(_current() is Hub)


func test_leaving_a_game_returns_to_hub_and_frees_it() -> void:
	(_current() as Hub).game_chosen.emit(Hub.MATCH)
	var game := _current() as MatchGame

	game.exit_requested.emit()

	assert_true(_current() is Hub)
	assert_true(game.is_queued_for_deletion())


func test_runner_exit_returns_to_hub() -> void:
	(_current() as Hub).game_chosen.emit(Hub.RUNNER)

	(_current() as RunnerGame).exit_requested.emit()

	assert_true(_current() is Hub)


func test_unknown_game_keeps_hub() -> void:
	var hub := _current()

	(hub as Hub).game_chosen.emit(&"unknown")

	assert_eq(_current(), hub)
