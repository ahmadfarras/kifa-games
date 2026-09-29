class_name MathSession
extends RefCounted

## Use cases for Math Fun: start a quiz, answer, move to the next question.

signal quiz_won

var quiz: Quiz

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func start(mode: Quiz.Mode) -> Quiz:
	quiz = Quiz.new(mode, _rng)
	return quiz


func answer(value: int) -> Quiz.Answer:
	var result := quiz.answer(value)
	if result == Quiz.Answer.CORRECT and quiz.is_won():
		quiz_won.emit()
	return result


func next_question() -> void:
	quiz.next_question()
