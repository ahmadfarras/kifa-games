extends GutTest

var session: MathSession


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	session = MathSession.new(rng)


func test_no_quiz_before_start() -> void:
	assert_null(session.quiz)


func test_start_makes_quiz_in_mode() -> void:
	var quiz := session.start(Quiz.Mode.MULTIPLY)

	assert_eq(session.quiz, quiz)
	assert_eq(quiz.mode, Quiz.Mode.MULTIPLY)


func test_answer_returns_result() -> void:
	session.start(Quiz.Mode.ADD)

	assert_eq(session.answer(session.quiz.question.answer), Quiz.Answer.CORRECT)


func test_next_question_moves_on() -> void:
	session.start(Quiz.Mode.ADD)
	session.answer(session.quiz.question.answer)

	session.next_question()

	assert_true(session.quiz.is_answering())


func test_goal_th_right_answer_wins_once() -> void:
	session.start(Quiz.Mode.SUBTRACT)
	watch_signals(session)

	for i in Quiz.GOAL:
		session.answer(session.quiz.question.answer)
		if i < Quiz.GOAL - 1:
			assert_signal_not_emitted(session, "quiz_won")
			session.next_question()

	assert_signal_emit_count(session, "quiz_won", 1)
