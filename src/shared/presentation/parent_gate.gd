class_name ParentGate
extends VBoxContainer

## Parental gate: shows a GateQuestion with a number pad. A right answer emits `passed`; a wrong one
## shows a new question. Used before anything a grown-up should decide (creating or deleting an account).

signal passed

const CLEAR := "C"
const OK := "OK"
const KEYS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", CLEAR, "0", OK]

var _rng: RandomNumberGenerator
var _question: GateQuestion
var _typed := ""

@onready var _question_label: Label = %Question
@onready var _answer_label: Label = %Answer
@onready var _keys: GridContainer = %Keys
@onready var _key_template: Button = %KeyTemplate


func setup(rng: RandomNumberGenerator) -> void:
	_rng = rng


func _ready() -> void:
	for key in KEYS:
		var button: Button = _key_template.duplicate()
		button.text = key
		button.show()
		button.pressed.connect(press.bind(key))
		_keys.add_child(button)


## Starts over with a new question.
func ask() -> void:
	_question = GateQuestion.new(_rng)
	_question_label.text = _question.text()
	_set_typed("")


func press(key: String) -> void:
	if key == CLEAR:
		_set_typed("")
	elif key == OK:
		_check()
	elif _typed.length() < GateQuestion.ANSWER_DIGITS:
		_set_typed(_typed + key)


func _check() -> void:
	if _question.is_answer(_typed):
		passed.emit()
	else:
		ask()


func _set_typed(typed: String) -> void:
	_typed = typed
	_answer_label.text = typed if not typed.is_empty() else "?"
