extends GutTest

const HubScene := preload("res://src/app/hub.tscn")

var hub: Hub


func before_each() -> void:
	hub = HubScene.instantiate()
	add_child_autofree(hub)
	watch_signals(hub)


func test_match_button_chooses_match() -> void:
	hub.get_node("%MatchButton").pressed.emit()

	assert_signal_emitted_with_parameters(hub, "game_chosen", [Hub.MATCH])


func test_math_button_chooses_math() -> void:
	hub.get_node("%MathButton").pressed.emit()

	assert_signal_emitted_with_parameters(hub, "game_chosen", [Hub.MATH])


func test_coloring_button_chooses_coloring() -> void:
	hub.get_node("%ColoringButton").pressed.emit()

	assert_signal_emitted_with_parameters(hub, "game_chosen", [Hub.COLORING])


func test_games_fit_one_row_in_landscape_two_in_portrait() -> void:
	var games: GridContainer = hub.get_node("%Games")
	var screen := hub.get_viewport_rect().size

	var expected := games.get_child_count() if screen.x > screen.y else ceili(games.get_child_count() / 2.0)
	assert_eq(games.columns, expected)
	assert_eq(games.get_child_count(), 4)


func test_runner_button_chooses_runner() -> void:
	hub.get_node("%RunnerButton").pressed.emit()

	assert_signal_emitted_with_parameters(hub, "game_chosen", [Hub.RUNNER])
