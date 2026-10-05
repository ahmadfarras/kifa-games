extends GutTest

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 3


func test_factors_are_too_hard_for_a_young_child() -> void:
	for i in 100:
		var question := GateQuestion.new(rng)

		assert_between(question.a, GateQuestion.MIN_FACTOR, GateQuestion.MAX_FACTOR)
		assert_between(question.b, GateQuestion.MIN_FACTOR, GateQuestion.MAX_FACTOR)
		assert_eq(str(question.a * question.b).length(), GateQuestion.ANSWER_DIGITS)


func test_text_shows_the_multiplication() -> void:
	var question := GateQuestion.new(rng)
	question.a = 7
	question.b = 8

	assert_eq(question.text(), "7 × 8 = ?")


func test_only_the_product_is_the_answer() -> void:
	var question := GateQuestion.new(rng)
	question.a = 7
	question.b = 8

	assert_true(question.is_answer("56"))
	for typed in ["", "5", "57", "056", "56 ", "fifty-six"]:
		assert_false(question.is_answer(typed), typed)


func test_questions_vary() -> void:
	var seen: Dictionary[String, bool] = {}
	for i in 50:
		seen[GateQuestion.new(rng).text()] = true

	assert_gt(seen.size(), 5)
