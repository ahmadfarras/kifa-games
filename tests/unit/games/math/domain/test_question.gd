extends GutTest

const Op := Question.Operation
const SAMPLES := 300

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 8


func _samples(op: Op) -> Array[Question]:
	var made: Array[Question] = []
	for i in SAMPLES:
		made.append(Question.make(op, rng))
	return made


func test_init_solves_answer() -> void:
	var question := Question.new(6, 3, Op.DIVIDE, [2, 1, 4] as Array[int])

	assert_eq(question.a, 6)
	assert_eq(question.b, 3)
	assert_eq(question.operation, Op.DIVIDE)
	assert_eq(question.answer, 2)
	assert_eq(question.choices, [2, 1, 4])


func test_solve_each_operation() -> void:
	assert_eq(Question.solve(3, 4, Op.ADD), 7)
	assert_eq(Question.solve(9, 4, Op.SUBTRACT), 5)
	assert_eq(Question.solve(3, 4, Op.MULTIPLY), 12)
	assert_eq(Question.solve(12, 4, Op.DIVIDE), 3)


func test_addition_sums_up_to_ten() -> void:
	for question in _samples(Op.ADD):
		assert_between(question.a, 1, 9)
		assert_gte(question.b, 1)
		assert_lte(question.answer, 10)


func test_subtraction_stays_positive_within_ten() -> void:
	for question in _samples(Op.SUBTRACT):
		assert_lte(question.a, 10)
		assert_gte(question.b, 1)
		assert_gte(question.answer, 1)


func test_multiplication_factors_up_to_five() -> void:
	for question in _samples(Op.MULTIPLY):
		assert_between(question.a, 1, 5)
		assert_between(question.b, 1, 5)


func test_division_is_always_whole() -> void:
	for question in _samples(Op.DIVIDE):
		assert_between(question.b, 1, 5)
		assert_eq(question.a % question.b, 0)
		assert_between(question.answer, 1, 5)


func test_choices_hold_answer_and_close_distinct_wrongs() -> void:
	for op in [Op.ADD, Op.SUBTRACT, Op.MULTIPLY, Op.DIVIDE]:
		for question in _samples(op):
			assert_eq(question.choices.size(), Question.CHOICE_COUNT)
			assert_has(question.choices, question.answer)
			var unique := {}
			for choice in question.choices:
				unique[choice] = true
				assert_gte(choice, 0)
				assert_lte(absi(choice - question.answer), Question.MAX_MISS)
			assert_eq(unique.size(), Question.CHOICE_COUNT)


func test_answer_is_not_always_first() -> void:
	var positions := {}
	for question in _samples(Op.ADD):
		positions[question.choices.find(question.answer)] = true

	assert_eq(positions.size(), Question.CHOICE_COUNT)


func test_choices_for_smallest_answer_stay_non_negative() -> void:
	for i in 100:
		for choice in Question.make_choices(0, rng):
			assert_gte(choice, 0)


func test_same_seed_same_question() -> void:
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 3
	rng_b.seed = 3

	var a := Question.make(Op.MULTIPLY, rng_a)
	var b := Question.make(Op.MULTIPLY, rng_b)

	assert_eq([a.a, a.b, a.choices], [b.a, b.b, b.choices])
