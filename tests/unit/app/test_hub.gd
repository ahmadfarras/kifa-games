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


func test_runner_button_chooses_runner() -> void:
	hub.get_node("%RunnerButton").pressed.emit()

	assert_signal_emitted_with_parameters(hub, "game_chosen", [Hub.RUNNER])
