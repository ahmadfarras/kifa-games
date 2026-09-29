extends GutTest

const RunnerUiScene := preload("res://src/games/runner/presentation/runner_ui.tscn")

var ui: RunnerUi


func before_each() -> void:
	ui = RunnerUiScene.instantiate()
	add_child_autofree(ui)


func _character_button(index: int) -> CharacterButton:
	return ui.get_node("%CharacterButtons").get_child(index)


func test_offers_girl_and_boy() -> void:
	var paths := []
	for button: CharacterButton in ui.get_node("%CharacterButtons").get_children():
		paths.append(button.frames.resource_path)

	assert_eq(paths, ["res://assets/runner/characters/little_girl.tres", "res://assets/runner/characters/little_boy.tres"])


func test_first_character_is_selected_by_default() -> void:
	assert_true(_character_button(0).button_pressed)
	assert_eq(ui.selected_character(), _character_button(0).frames)


func test_pressing_character_only_selects_it() -> void:
	watch_signals(ui)

	_character_button(1).button_pressed = true

	assert_false(_character_button(0).button_pressed)
	assert_eq(ui.selected_character(), _character_button(1).frames)
	assert_signal_not_emitted(ui, "runner_chosen")


func test_selecting_character_emits_character_selected() -> void:
	watch_signals(ui)

	_character_button(1).pressed.emit()
	_character_button(1).button_pressed = true

	assert_signal_emitted_with_parameters(ui, "character_selected", [_character_button(1).frames])


func test_only_selected_character_animates() -> void:
	_character_button(1).button_pressed = true

	assert_false(_character_button(0).is_processing())
	assert_true(_character_button(1).is_processing())


func test_start_emits_selected_character() -> void:
	_character_button(1).button_pressed = true
	watch_signals(ui)

	ui.get_node("%StartButton").pressed.emit()

	assert_signal_emitted_with_parameters(ui, "runner_chosen", [_character_button(1).frames])


func test_play_again_button_emits_signal() -> void:
	watch_signals(ui)

	ui.get_node("%PlayAgainButton").pressed.emit()

	assert_signal_emitted(ui, "play_again_pressed")


func test_change_runner_button_emits_signal() -> void:
	watch_signals(ui)

	ui.get_node("%ChangeRunnerButton").pressed.emit()

	assert_signal_emitted(ui, "change_runner_pressed")


func test_show_start_shows_only_start_screen() -> void:
	ui.show_game_over(1, 2)

	ui.show_start()

	assert_true(ui.get_node("%StartScreen").visible)
	assert_false(ui.get_node("%ScoreBar").visible)
	assert_false(ui.get_node("%GameOverScreen").visible)


func test_show_playing_shows_score_bar_with_reset_score() -> void:
	ui.set_score(7)

	ui.show_playing(12)

	assert_false(ui.get_node("%StartScreen").visible)
	assert_false(ui.get_node("%GameOverScreen").visible)
	assert_true(ui.get_node("%ScoreBar").visible)
	assert_eq(ui.get_node("%ScoreLabel").text, "⭐ 0")
	assert_eq(ui.get_node("%BestLabel").text, "🏆 12")


func test_set_score_updates_label() -> void:
	ui.set_score(3)

	assert_eq(ui.get_node("%ScoreLabel").text, "⭐ 3")


func test_set_score_pops_on_milestone() -> void:
	var label: Label = ui.get_node("%ScoreLabel")

	ui.set_score(RunnerUi.SCORE_POP_EVERY)
	await wait_process_frames(2)

	assert_gt(label.scale.x, 1.0)


func test_set_score_does_not_pop_between_milestones() -> void:
	var label: Label = ui.get_node("%ScoreLabel")

	ui.set_score(RunnerUi.SCORE_POP_EVERY + 1)
	await wait_process_frames(2)

	assert_eq(label.scale, Vector2.ONE)


func test_show_game_over_shows_results() -> void:
	ui.show_game_over(8, 15)

	assert_true(ui.get_node("%GameOverScreen").visible)
	assert_eq(ui.get_node("%FinalScoreLabel").text, "⭐ 8")
	assert_eq(ui.get_node("%FinalBestLabel").text, "🏆 15")
	assert_eq(ui.get_node("%BestLabel").text, "🏆 15")
