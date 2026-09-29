class_name Hub
extends Control

## Main menu: the kid picks a game. Game cards sit in one row in landscape and two rows in portrait.

signal game_chosen(game: StringName)

const RUNNER := &"runner"
const MATCH := &"match"
const MATH := &"math"
const COLORING := &"coloring"

@onready var _games: GridContainer = %Games


func _ready() -> void:
	%MatchButton.pressed.connect(game_chosen.emit.bind(MATCH))
	%ColoringButton.pressed.connect(game_chosen.emit.bind(COLORING))
	%MathButton.pressed.connect(game_chosen.emit.bind(MATH))
	%RunnerButton.pressed.connect(game_chosen.emit.bind(RUNNER))
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var screen := get_viewport_rect().size
	var count := _games.get_child_count()
	_games.columns = count if screen.x > screen.y else ceili(count / 2.0)
