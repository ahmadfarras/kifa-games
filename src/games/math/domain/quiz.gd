class_name Quiz
extends RefCounted

## One play session: GOAL questions of the chosen mode. A right answer earns a star and (after a short
## pause, via next_question) the next question; a wrong answer stays out so the kid can try another.
## Other layers read its fields but change state only through answer() and next_question().

enum Mode { ADD, SUBTRACT, MULTIPLY, DIVIDE, MIX }
enum Answer { IGNORED, CORRECT, WRONG }

const GOAL := 5
const OPERATIONS := {
	Mode.ADD: Question.Operation.ADD,
	Mode.SUBTRACT: Question.Operation.SUBTRACT,
	Mode.MULTIPLY: Question.Operation.MULTIPLY,
	Mode.DIVIDE: Question.Operation.DIVIDE,
}

var mode: Mode
var question: Question
var solved := 0

var _rng: RandomNumberGenerator
var _answering := true
var _wrong: Array[int] = []


func _init(quiz_mode: Mode, rng: RandomNumberGenerator) -> void:
	mode = quiz_mode
	_rng = rng
	next_question()


func is_won() -> bool:
	return solved == GOAL


## False after a right answer, until next_question().
func is_answering() -> bool:
	return _answering


func answer(value: int) -> Answer:
	if not _answering or _wrong.has(value):
		return Answer.IGNORED
	if value != question.answer:
		_wrong.append(value)
		return Answer.WRONG
	_answering = false
	solved += 1
	return Answer.CORRECT


func next_question() -> void:
	question = Question.make(_operation(), _rng)
	_answering = true
	_wrong.clear()


func _operation() -> Question.Operation:
	if mode == Mode.MIX:
		return _rng.randi_range(0, Question.Operation.size() - 1) as Question.Operation
	return OPERATIONS[mode]
