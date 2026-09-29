class_name Question
extends RefCounted

## One kid-sized sum, e.g. 3 + 4, with three answer choices (the right one and two close wrong ones).
## Immutable once made.

enum Operation { ADD, SUBTRACT, MULTIPLY, DIVIDE }

const CHOICE_COUNT := 3
## Wrong choices are this close to the answer (1..MAX_MISS away) so kids have to think.
const MAX_MISS := 3

var a: int
var b: int
var operation: Operation
var answer: int
var choices: Array[int] = []


func _init(left: int, right: int, op: Operation, shuffled_choices: Array[int]) -> void:
	a = left
	b = right
	operation = op
	answer = solve(left, right, op)
	choices = shuffled_choices


## Numbers stay small and answers are always whole and never negative:
## + sums up to 10, − within 10, × factors 1..5, ÷ divides evenly with answers 1..5.
static func make(op: Operation, rng: RandomNumberGenerator) -> Question:
	var left: int
	var right: int
	match op:
		Operation.ADD:
			left = rng.randi_range(1, 9)
			right = rng.randi_range(1, 10 - left)
		Operation.SUBTRACT:
			left = rng.randi_range(2, 10)
			right = rng.randi_range(1, left - 1)
		Operation.MULTIPLY:
			left = rng.randi_range(1, 5)
			right = rng.randi_range(1, 5)
		Operation.DIVIDE:
			right = rng.randi_range(1, 5)
			left = right * rng.randi_range(1, 5)
	return Question.new(left, right, op, make_choices(solve(left, right, op), rng))


static func solve(left: int, right: int, op: Operation) -> int:
	match op:
		Operation.ADD:
			return left + right
		Operation.SUBTRACT:
			return left - right
		Operation.MULTIPLY:
			return left * right
	return left / right


## The answer plus distinct, non-negative wrong answers close to it, in random order.
static func make_choices(correct: int, rng: RandomNumberGenerator) -> Array[int]:
	var picked: Array[int] = [correct]
	while picked.size() < CHOICE_COUNT:
		var miss := rng.randi_range(1, MAX_MISS) * (1 if rng.randf() < 0.5 else -1)
		var wrong := correct + miss
		if wrong >= 0 and not picked.has(wrong):
			picked.append(wrong)
	for i in range(picked.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := picked[i]
		picked[i] = picked[j]
		picked[j] = swap
	return picked
