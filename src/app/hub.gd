class_name Hub
extends Control

## Main menu: the kid picks a game.

signal game_chosen(game: StringName)

const RUNNER := &"runner"
const MATCH := &"match"


func _ready() -> void:
	%MatchButton.pressed.connect(game_chosen.emit.bind(MATCH))
	%RunnerButton.pressed.connect(game_chosen.emit.bind(RUNNER))
