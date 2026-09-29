extends GutTest

var quiz: Quiz


func before_each() -> void:
	quiz = _new_quiz(Quiz.Mode.ADD)


func _new_quiz(mode: Quiz.Mode) -> Quiz:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	return Quiz.new(mode, rng)


func _wrong_choice() -> int:
	for choice in quiz.question.choices:
		if choice != quiz.question.answer:
			return choice
	return -1


func test_starts_with_a_question() -> void:
	assert_not_null(quiz.question)
	assert_eq(quiz.solved, 0)
	assert_true(quiz.is_answering())
	assert_false(quiz.is_won())


func test_each_mode_asks_its_operation() -> void:
	for mode: Quiz.Mode in Quiz.OPERATIONS:
		var single := _new_quiz(mode)
		for i in 20:
			assert_eq(single.question.operation, Quiz.OPERATIONS[mode])
			single.next_question()


func test_mix_asks_every_operation() -> void:
	var mix := _new_quiz(Quiz.Mode.MIX)
	var seen := {}

	for i in 100:
		seen[mix.question.operation] = true
		mix.next_question()

	assert_eq(seen.size(), Question.Operation.size())


func test_right_answer_earns_a_star_and_pauses() -> void:
	assert_eq(quiz.answer(quiz.question.answer), Quiz.Answer.CORRECT)

	assert_eq(quiz.solved, 1)
	assert_false(quiz.is_answering())


func test_answers_ignored_until_next_question() -> void:
	quiz.answer(quiz.question.answer)

	assert_eq(quiz.answer(quiz.question.answer), Quiz.Answer.IGNORED)
	assert_eq(quiz.solved, 1)


func test_wrong_answer_lets_kid_try_again() -> void:
	var wrong := _wrong_choice()

	assert_eq(quiz.answer(wrong), Quiz.Answer.WRONG)
	assert_true(quiz.is_answering())
	assert_eq(quiz.answer(quiz.question.answer), Quiz.Answer.CORRECT)


func test_same_wrong_answer_is_ignored() -> void:
	var wrong := _wrong_choice()
	quiz.answer(wrong)

	assert_eq(quiz.answer(wrong), Quiz.Answer.IGNORED)


func test_next_question_resets_answering_and_wrong_tries() -> void:
	quiz.answer(_wrong_choice())
	quiz.answer(quiz.question.answer)
	var previous := quiz.question

	quiz.next_question()

	assert_ne(quiz.question, previous)
	assert_true(quiz.is_answering())
	assert_eq(quiz.answer(_wrong_choice()), Quiz.Answer.WRONG)


func test_won_after_goal_right_answers() -> void:
	for i in Quiz.GOAL:
		assert_false(quiz.is_won())
		quiz.answer(quiz.question.answer)
		quiz.next_question()

	assert_eq(quiz.solved, Quiz.GOAL)
	assert_true(quiz.is_won())
