extends GutTest

const RunnerUiScene := preload("res://src/games/runner/presentation/runner_ui.tscn")

var ui: RunnerUi


func before_each() -> void:
	ui = RunnerUiScene.instantiate()
	add_child_autofree(ui)


func _character_button(index: int) -> CharacterButton:
	return ui.get_node("%CharacterButtons").get_child(index)


func _owned(ids: Array[StringName]) -> Dictionary[StringName, bool]:
	var owned: Dictionary[StringName, bool] = {}
	for id in ids:
		owned[id] = true
	return owned


func test_offers_every_catalog_character_in_order() -> void:
	var paths := []
	var ids: Array[StringName] = []
	for button: CharacterButton in ui.get_node("%CharacterButtons").get_children():
		paths.append(button.frames.resource_path)
		ids.append(button.character_id)

	assert_eq(ids, CharacterCatalog.ids())
	assert_eq(paths, [
		"res://assets/runner/characters/little_girl.tres",
		"res://assets/runner/characters/little_boy.tres",
		"res://assets/runner/characters/cat.tres",
	])


func test_cat_is_locked_by_default() -> void:
	assert_false(_character_button(0).is_locked)
	assert_false(_character_button(1).is_locked)
	assert_true(_character_button(2).is_locked)
	assert_eq(_character_button(2).text, "🔒 🪙 500")


func test_character_buttons_share_one_group() -> void:
	var group := _character_button(0).button_group

	for button: CharacterButton in ui.get_node("%CharacterButtons").get_children():
		assert_eq(button.button_group, group)


func test_show_progress_updates_coins_and_locks() -> void:
	ui.show_progress(310, _owned([&"little_girl", &"little_boy", &"cat"]))

	assert_eq(ui.get_node("%CoinsLabel").text, "🪙 310")
	assert_false(_character_button(2).is_locked)


func test_show_progress_moves_selection_to_owned_character() -> void:
	ui.show_progress(0, _owned([&"little_boy"]))

	assert_true(_character_button(0).is_locked)
	assert_true(_character_button(1).button_pressed)
	assert_eq(ui.selected_character(), _character_button(1).frames)


func test_show_progress_keeps_owned_selection() -> void:
	_character_button(1).button_pressed = true

	ui.show_progress(5, _owned([&"little_girl", &"little_boy"]))

	assert_true(_character_button(1).button_pressed)


func test_locked_character_cannot_be_selected() -> void:
	_character_button(2).button_pressed = true

	assert_false(_character_button(2).button_pressed)
	assert_eq(ui.selected_character(), _character_button(0).frames)


func test_tapping_locked_character_requests_shop() -> void:
	watch_signals(ui)

	_character_button(2)._pressed()

	assert_signal_emitted_with_parameters(ui, "shop_requested", [&"cat"])


func test_shop_button_requests_shop() -> void:
	watch_signals(ui)

	ui.get_node("%ShopButton").pressed.emit()

	assert_signal_emitted_with_parameters(ui, "shop_requested", [&""])


func test_select_character_selects_owned() -> void:
	ui.select_character(&"little_boy")

	assert_true(_character_button(1).button_pressed)


func test_select_character_ignores_locked() -> void:
	ui.select_character(&"cat")

	assert_false(_character_button(2).button_pressed)
	assert_true(_character_button(0).button_pressed)


func test_shop_bar_only_on_start_screen() -> void:
	ui.show_playing(0)
	assert_false(ui.get_node("%ShopBar").visible)

	ui.show_start()
	assert_true(ui.get_node("%ShopBar").visible)


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


func test_back_button_emits_signal() -> void:
	watch_signals(ui)

	ui.get_node("%BackButton").pressed.emit()

	assert_signal_emitted(ui, "back_pressed")


func test_back_button_only_on_start_screen() -> void:
	ui.show_playing(0)
	assert_false(ui.get_node("%BackButton").visible)

	ui.show_start()
	assert_true(ui.get_node("%BackButton").visible)


func test_play_again_button_emits_signal() -> void:
	watch_signals(ui)

	ui.get_node("%PlayAgainButton").pressed.emit()

	assert_signal_emitted(ui, "play_again_pressed")


func test_change_runner_button_emits_signal() -> void:
	watch_signals(ui)

	ui.get_node("%ChangeRunnerButton").pressed.emit()

	assert_signal_emitted(ui, "change_runner_pressed")


func test_show_start_shows_only_start_screen() -> void:
	ui.show_game_over(1, 2, 3)

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
	ui.show_game_over(8, 15, 8)

	assert_true(ui.get_node("%GameOverScreen").visible)
	assert_eq(ui.get_node("%FinalScoreLabel").text, "⭐ 8")
	assert_eq(ui.get_node("%FinalBestLabel").text, "🏆 15")
	assert_eq(ui.get_node("%FinalCoinsLabel").text, "+8 🪙")
	assert_eq(ui.get_node("%BestLabel").text, "🏆 15")
