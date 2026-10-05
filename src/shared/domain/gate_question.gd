class_name GateQuestion
extends RefCounted

## The parental gate's question: a multiplication a grown-up answers quickly and a young child cannot
## (the Math game stops at factors of 5). A new question is made for every attempt.

const MIN_FACTOR := 6
const MAX_FACTOR := 9
## Every answer has two digits (36..81).
const ANSWER_DIGITS := 2

var a: int
var b: int


func _init(rng: RandomNumberGenerator) -> void:
	a = rng.randi_range(MIN_FACTOR, MAX_FACTOR)
	b = rng.randi_range(MIN_FACTOR, MAX_FACTOR)


func text() -> String:
	return "%d × %d = ?" % [a, b]


func is_answer(typed: String) -> bool:
	return typed == str(a * b)
