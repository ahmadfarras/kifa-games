extends GutTest

const RunnerUiScene := preload("res://src/games/runner/presentation/runner_ui.tscn")

var ui: RunnerUi


func before_each() -> void:
	ui = RunnerUiScene.instantiate()
	add_child_autofree(ui)


func test_character_button_emits_runner_chosen() -> void:
	watch_signals(ui)
	var button: CharacterButton = ui.get_node("%CharacterButtons").get_child(0)

	button.pressed.emit()

	assert_signal_emitted_with_parameters(ui, "runner_chosen", [button.frames])


func test_character_buttons_show_first_idle_frame() -> void:
	for button: CharacterButton in ui.get_node("%CharacterButtons").get_children():
		assert_not_null(button.frames)
		assert_eq(button.icon, button.frames.get_frame_texture(RunnerGame.ANIM_IDLE, 0))


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
