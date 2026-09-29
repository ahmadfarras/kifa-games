class_name MathGame
extends Control

## Math Fun screens: pick an operation, answer Quiz.GOAL questions, win screen.
## Event driven (taps, two timers, short tweens): nothing runs per frame.

signal exit_requested

## Mode button: [mode, symbol, symbol colour, example].
const MODES := [
	[Quiz.Mode.ADD, "+", Color(0.263, 0.769, 0.396), "2 + 3"],
	[Quiz.Mode.SUBTRACT, "−", Color(0.302, 0.588, 1.0), "5 − 2"],
	[Quiz.Mode.MULTIPLY, "×", Color(1.0, 0.624, 0.11), "2 × 3"],
	[Quiz.Mode.DIVIDE, "÷", Color(1.0, 0.42, 0.616), "6 ÷ 2"],
	[Quiz.Mode.MIX, "🎲", Color(0.4, 0.4, 0.4), "+ − × ÷"],
]
const SIGNS := {
	Question.Operation.ADD: "+",
	Question.Operation.SUBTRACT: "−",
	Question.Operation.MULTIPLY: "×",
	Question.Operation.DIVIDE: "÷",
}
const POP_SCALE := Vector2(1.2, 1.2)
const SHAKE_DEGREES := 6.0

@export var answer_style: StyleBox
@export var correct_style: StyleBox
@export var wrong_style: StyleBox

var _session: MathSession
var _mode := Quiz.Mode.ADD
var _answers: Array[Button] = []

@onready var _pick_screen: Control = %PickScreen
@onready var _mode_buttons: Container = %ModeButtons
@onready var _game_screen: Control = %GameScreen
@onready var _question_box: Control = %QuestionBox
@onready var _question_label: Label = %QuestionLabel
@onready var _progress: StarProgress = %Progress
@onready var _win_screen: WinScreen = %WinScreen
@onready var _next_timer: Timer = %NextTimer
@onready var _win_timer: Timer = %WinTimer


func setup(session: MathSession) -> void:
	_session = session


static func question_text(question: Question) -> String:
	return "%d %s %d =" % [question.a, SIGNS[question.operation], question.b]


func _ready() -> void:
	for spec: Array in MODES:
		_add_mode_button(spec)
	for button: Button in %Answers.get_children():
		button.pressed.connect(_on_answer_pressed.bind(_answers.size()))
		_answers.append(button)
	%BackButton.pressed.connect(exit_requested.emit)
	%HomeButton.pressed.connect(_show_pick)
	_win_screen.home_pressed.connect(_show_pick)
	_win_screen.play_again_pressed.connect(func() -> void: _start(_mode))
	_session.quiz_won.connect(_win_timer.start)
	_next_timer.timeout.connect(_next_question)
	_win_timer.timeout.connect(_show_win)
	_show_pick()


func _add_mode_button(spec: Array) -> void:
	var button: Button = %ModeButtonTemplate.duplicate()
	var sign: Label = button.get_node("Content/Sign")
	sign.text = spec[1]
	sign.add_theme_color_override("font_color", spec[2])
	button.get_node("Content/Example").text = spec[3]
	button.show()
	button.pressed.connect(func() -> void: _start(spec[0]))
	_mode_buttons.add_child(button)


func _start(mode: Quiz.Mode) -> void:
	_mode = mode
	_stop_timers()
	_session.start(mode)
	_progress.reset(Quiz.GOAL)
	_pick_screen.hide()
	_win_screen.hide()
	_game_screen.show()
	_show_question(_session.quiz.question)


func _show_question(question: Question) -> void:
	_question_label.text = question_text(question)
	for i in _answers.size():
		_answers[i].text = str(question.choices[i])
		_answers[i].rotation = 0.0
		_answers[i].scale = Vector2.ONE
		_paint(_answers[i], answer_style)
	_pop(_question_box, Vector2(1.08, 1.08))


func _on_answer_pressed(index: int) -> void:
	var button := _answers[index]
	match _session.answer(_session.quiz.question.choices[index]):
		Quiz.Answer.CORRECT:
			_paint(button, correct_style)
			_pop(button, POP_SCALE)
			_progress.light_next()
			if not _session.quiz.is_won():
				_next_timer.start()
		Quiz.Answer.WRONG:
			_paint(button, wrong_style)
			_shake(button)


func _next_question() -> void:
	_session.next_question()
	_show_question(_session.quiz.question)


func _show_win() -> void:
	_win_screen.celebrate("⭐".repeat(Quiz.GOAL))


func _show_pick() -> void:
	_stop_timers()
	_game_screen.hide()
	_win_screen.hide()
	_pick_screen.show()


func _stop_timers() -> void:
	_next_timer.stop()
	_win_timer.stop()


static func _paint(button: Button, style: StyleBox) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, style)


static func _pop(control: Control, peak: Vector2) -> void:
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", peak, 0.15)
	tween.tween_property(control, "scale", Vector2.ONE, 0.2)


static func _shake(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	for degrees in [-SHAKE_DEGREES, SHAKE_DEGREES, 0.0]:
		tween.tween_property(control, "rotation", deg_to_rad(degrees), 0.1)
