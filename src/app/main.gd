extends Node

## Composition root: shows the menu and builds each game with its concrete dependencies.
## Game scenes are loaded only when picked and freed on exit, so one game's art never stays in memory
## while another is played.

const HUB_SCENE := "res://src/app/hub.tscn"
const RUNNER_GAME_SCENE := "res://src/games/runner/presentation/runner_game.tscn"
const MATCH_GAME_SCENE := "res://src/games/match/presentation/match_game.tscn"

var _current: Node


func _ready() -> void:
	show_hub()


func show_hub() -> void:
	var hub: Hub = load(HUB_SCENE).instantiate()
	hub.game_chosen.connect(_on_game_chosen)
	_switch_to(hub)


func _on_game_chosen(game: StringName) -> void:
	match game:
		Hub.RUNNER:
			_switch_to(_build_runner())
		Hub.MATCH:
			_switch_to(_build_match())


func _build_runner() -> RunnerGame:
	var rng := _new_rng()
	var session := RunnerSession.new(JsonBestScoreRepository.new(), rng)
	var game: RunnerGame = load(RUNNER_GAME_SCENE).instantiate()
	game.setup(session, rng)
	game.exit_requested.connect(show_hub)
	return game


func _build_match() -> MatchGame:
	var game: MatchGame = load(MATCH_GAME_SCENE).instantiate()
	game.setup(MatchSession.new(_new_rng()))
	game.exit_requested.connect(show_hub)
	return game


func _switch_to(scene: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = scene
	add_child(scene)


func _new_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng
