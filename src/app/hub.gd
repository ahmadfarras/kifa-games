class_name Hub
extends Control

## Main menu: the kid picks a game. Game cards sit in one row in landscape and two rows in portrait.

signal game_chosen(game: StringName)
signal account_requested

const RUNNER := &"runner"
const MATCH := &"match"
const MATH := &"math"
const COLORING := &"coloring"
const GUEST_ACCOUNT_TEXT := "⭐ Save my stars"

@onready var _games: GridContainer = %Games
@onready var _account_button: Button = %AccountButton


func _ready() -> void:
	%MatchButton.pressed.connect(game_chosen.emit.bind(MATCH))
	%ColoringButton.pressed.connect(game_chosen.emit.bind(COLORING))
	%MathButton.pressed.connect(game_chosen.emit.bind(MATH))
	%RunnerButton.pressed.connect(game_chosen.emit.bind(RUNNER))
	_account_button.pressed.connect(account_requested.emit)
	get_viewport().size_changed.connect(_layout)
	_layout()


## Shows who is logged in on the account button ("" = guest).
func show_account(username: String) -> void:
	_account_button.text = GUEST_ACCOUNT_TEXT if username.is_empty() else "✅ " + username


func _layout() -> void:
	var screen := get_viewport_rect().size
	var count := _games.get_child_count()
	_games.columns = count if screen.x > screen.y else ceili(count / 2.0)
