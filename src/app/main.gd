extends Node

## Composition root: builds concrete dependencies and hands them to the game scene.

const RUNNER_GAME_SCENE := preload("res://src/games/runner/presentation/runner_game.tscn")


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var session := RunnerSession.new(JsonBestScoreRepository.new(), rng)
	var game: RunnerGame = RUNNER_GAME_SCENE.instantiate()
	game.setup(session, rng)
	add_child(game)
