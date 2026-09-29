extends GutTest

const MathGameScene := preload("res://src/games/math/presentation/math_game.tscn")

var session: MathSession
var game: MathGame


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	session = MathSession.new(rng)
	game = MathGameScene.instantiate()
	game.setup(session)
	add_child_autofree(game)


func _mode_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in game.get_node("%ModeButtons").get_children():
		if child.visible:
			buttons.append(child)
	return buttons


func _answers() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in game.get_node("%Answers").get_children():
		buttons.append(child)
	return buttons


func _start(mode_index: int) -> void:
	_mode_buttons()[mode_index].pressed.emit()


func _question() -> Question:
	return session.quiz.question


func _right_index() -> int:
	return _question().choices.find(_question().answer)


func _wrong_index() -> int:
	return (_right_index() + 1) % Question.CHOICE_COUNT


func _style(button: Button) -> StyleBox:
	return button.get_theme_stylebox("normal")


## Like a real timeout: a one-shot timer is stopped when it fires.
func _fire(timer_name: String) -> void:
	var timer: Timer = game.get_node(timer_name)
	timer.stop()
	timer.timeout.emit()


func _solve_all() -> void:
	for i in Quiz.GOAL:
		_answers()[_right_index()].pressed.emit()
		if i < Quiz.GOAL - 1:
			_fire("%NextTimer")


func test_question_text_uses_math_signs() -> void:
	var question := Question.new(6, 3, Question.Operation.DIVIDE, [2, 1, 3] as Array[int])

	assert_eq(MathGame.question_text(question), "6 ÷ 3 =")


func test_every_operation_has_a_sign() -> void:
	for op in Question.Operation.values():
		assert_has(MathGame.SIGNS, op)


func test_starts_on_pick_screen_with_all_modes() -> void:
	assert_true(game.get_node("%PickScreen").visible)
	assert_false(game.get_node("%GameScreen").visible)
	assert_eq(_mode_buttons().size(), Quiz.Mode.size())
	assert_eq(_mode_buttons()[1].get_node("Content/Sign").text, "−")


func test_mode_button_starts_quiz_in_that_mode() -> void:
	_start(2)

	assert_eq(session.quiz.mode, Quiz.Mode.MULTIPLY)
	assert_true(game.get_node("%GameScreen").visible)
	assert_false(game.get_node("%PickScreen").visible)
	assert_eq(game.get_node("%Progress").lit_count(), 0)


func test_shows_question_and_choices() -> void:
	_start(0)

	assert_eq(game.get_node("%QuestionLabel").text, MathGame.question_text(_question()))
	for i in Question.CHOICE_COUNT:
		assert_eq(_answers()[i].text, str(_question().choices[i]))
		assert_eq(_style(_answers()[i]), game.answer_style)


func test_right_answer_turns_green_lights_star_and_waits() -> void:
	_start(0)
	var button := _answers()[_right_index()]

	button.pressed.emit()

	assert_eq(_style(button), game.correct_style)
	assert_eq(game.get_node("%Progress").lit_count(), 1)
	assert_false(game.get_node("%NextTimer").is_stopped())


func test_wrong_answer_turns_grey_and_kid_can_try_again() -> void:
	_start(0)
	var wrong := _answers()[_wrong_index()]

	wrong.pressed.emit()

	assert_eq(_style(wrong), game.wrong_style)
	assert_eq(game.get_node("%Progress").lit_count(), 0)
	assert_true(game.get_node("%NextTimer").is_stopped())
	_answers()[_right_index()].pressed.emit()
	assert_eq(game.get_node("%Progress").lit_count(), 1)


func test_taps_after_right_answer_are_ignored() -> void:
	_start(0)
	_answers()[_right_index()].pressed.emit()
	var other := _answers()[_wrong_index()]

	other.pressed.emit()

	assert_eq(_style(other), game.answer_style)


func test_next_question_resets_buttons() -> void:
	_start(0)
	_answers()[_wrong_index()].pressed.emit()
	_answers()[_right_index()].pressed.emit()

	_fire("%NextTimer")

	assert_true(session.quiz.is_answering())
	assert_eq(game.get_node("%QuestionLabel").text, MathGame.question_text(_question()))
	for button in _answers():
		assert_eq(_style(button), game.answer_style)


func test_goal_th_right_answer_shows_win_after_delay() -> void:
	_start(4)

	_solve_all()
	assert_true(game.get_node("%NextTimer").is_stopped())
	assert_false(game.get_node("%WinTimer").is_stopped())

	_fire("%WinTimer")

	var win: WinScreen = game.get_node("%WinScreen")
	assert_true(win.visible)
	assert_eq(win.get_node("%Stars").text, "⭐".repeat(Quiz.GOAL))


func test_play_again_restarts_same_mode() -> void:
	_start(3)
	_solve_all()
	_fire("%WinTimer")

	(game.get_node("%WinScreen") as WinScreen).play_again_pressed.emit()

	assert_eq(session.quiz.mode, Quiz.Mode.DIVIDE)
	assert_eq(session.quiz.solved, 0)
	assert_false(game.get_node("%WinScreen").visible)
	assert_eq(game.get_node("%Progress").lit_count(), 0)


func test_win_home_returns_to_pick_screen() -> void:
	_start(0)
	_solve_all()
	_fire("%WinTimer")

	(game.get_node("%WinScreen") as WinScreen).home_pressed.emit()

	assert_true(game.get_node("%PickScreen").visible)
	assert_false(game.get_node("%WinScreen").visible)


func test_home_button_returns_to_pick_and_stops_timers() -> void:
	_start(0)
	_answers()[_right_index()].pressed.emit()

	game.get_node("%HomeButton").pressed.emit()

	assert_true(game.get_node("%PickScreen").visible)
	assert_false(game.get_node("%GameScreen").visible)
	assert_true(game.get_node("%NextTimer").is_stopped())


func test_back_button_requests_exit() -> void:
	watch_signals(game)

	game.get_node("%BackButton").pressed.emit()

	assert_signal_emitted(game, "exit_requested")
