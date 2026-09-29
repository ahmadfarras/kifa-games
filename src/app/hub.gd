class_name Hub
extends Control

## Main menu: the kid picks a game.

signal game_chosen(game: StringName)

const RUNNER := &"runner"
const MATCH := &"match"
const MATH := &"math"


func _ready() -> void:
	%MatchButton.pressed.connect(game_chosen.emit.bind(MATCH))
	%MathButton.pressed.connect(game_chosen.emit.bind(MATH))
	%RunnerButton.pressed.connect(game_chosen.emit.bind(RUNNER))
