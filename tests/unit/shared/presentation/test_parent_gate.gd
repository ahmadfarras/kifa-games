extends GutTest

const GateScene := preload("res://src/shared/presentation/parent_gate.tscn")

var gate: ParentGate


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	gate = GateScene.instantiate()
	gate.setup(rng)
	add_child_autofree(gate)
	gate.ask()
	watch_signals(gate)


func _answer() -> String:
	return str(gate._question.a * gate._question.b)


func _type(text: String) -> void:
	for digit in text:
		gate.press(digit)


func test_builds_one_button_per_key() -> void:
	var keys: Array[String] = []
	for button: Button in gate.get_node("%Keys").get_children():
		if button.visible:
			keys.append(button.text)

	assert_eq(keys, ParentGate.KEYS)


func test_ask_shows_the_question_and_an_empty_answer() -> void:
	assert_eq(gate.get_node("%Question").text, gate._question.text())
	assert_eq(gate.get_node("%Answer").text, "?")


func test_buttons_type_digits() -> void:
	gate.get_node("%Keys").get_child(1).pressed.emit()
	gate.get_node("%Keys").get_child(2).pressed.emit()

	assert_eq(gate.get_node("%Answer").text, "12")


func test_right_answer_passes() -> void:
	_type(_answer())
	gate.press(ParentGate.OK)

	assert_signal_emitted(gate, "passed")


func test_wrong_answer_asks_a_new_question() -> void:
	var first := gate._question
	_type("11")
	gate.press(ParentGate.OK)

	assert_signal_not_emitted(gate, "passed")
	assert_ne(gate._question, first)
	assert_eq(gate.get_node("%Answer").text, "?")


func test_empty_answer_does_not_pass() -> void:
	gate.press(ParentGate.OK)

	assert_signal_not_emitted(gate, "passed")


func test_typing_stops_at_two_digits() -> void:
	_type("123")

	assert_eq(gate.get_node("%Answer").text, "12")


func test_clear_empties_the_answer() -> void:
	_type("12")
	gate.press(ParentGate.CLEAR)

	assert_eq(gate.get_node("%Answer").text, "?")


func test_answer_is_not_passed_without_ok() -> void:
	_type(_answer())

	assert_signal_not_emitted(gate, "passed")
