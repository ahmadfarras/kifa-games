extends GutTest

const MainScene := preload("res://src/app/main.tscn")


func test_main_starts_runner_game_on_start_screen() -> void:
	var main: Node = MainScene.instantiate()

	add_child_autofree(main)

	var game := main.get_child(0) as RunnerGame
	assert_not_null(game)
	assert_true(game.get_node("%RunnerUi").get_node("%StartScreen").visible)
