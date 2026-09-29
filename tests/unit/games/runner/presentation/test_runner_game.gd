extends GutTest

const RunnerGameScene := preload("res://src/games/runner/presentation/runner_game.tscn")
const DELTA := 0.02


class FakeBestScoreRepository:
	extends BestScoreRepository

	var stored := 0

	func load_best() -> int:
		return stored

	func save_best(score: int) -> void:
		stored = score


var session: RunnerSession
var game: RunnerGame
var ui: RunnerUi


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	session = RunnerSession.new(FakeBestScoreRepository.new(), rng)
	game = RunnerGameScene.instantiate()
	game.setup(session)
	add_child_autofree(game)
	ui = game.get_node("%RunnerUi")


func _choose_runner() -> void:
	ui.runner_chosen.emit("🦖")


func _tick_until_obstacle() -> void:
	while session.run.obstacles.is_empty():
		session.run.runner.height = 10.0
		game._process(DELTA)


func _crash() -> void:
	session.run.obstacles.append(Obstacle.new(session.run.runner_x(), 0.1, Obstacle.Kind.ROCK))
	game._process(DELTA)


func _obstacle_label_count() -> int:
	var count := 0
	for label in game.get_node("Obstacles").get_children():
		if not label.is_queued_for_deletion():
			count += 1
	return count


func test_starts_on_start_screen_without_processing() -> void:
	assert_true(ui.get_node("%StartScreen").visible)
	assert_false(game.is_processing())
	assert_null(session.run)


func test_layout_places_ground_and_flowers() -> void:
	var screen := game.get_viewport_rect().size

	assert_almost_eq(game.get_node("Ground").position.y, screen.y * RunnerGame.GROUND_Y_RATIO, 0.01)
	assert_gt(game.get_node("Flowers").get_child_count(), 0)


func test_choosing_runner_starts_run() -> void:
	_choose_runner()

	assert_true(session.is_running())
	assert_eq(game.get_node("Runner").text, "🦖")
	assert_true(ui.get_node("%ScoreBar").visible)
	assert_true(game.is_processing())


func test_jump_action_makes_runner_jump() -> void:
	_choose_runner()
	var event := InputEventAction.new()
	event.action = "jump"
	event.pressed = true

	game._unhandled_input(event)

	assert_false(session.run.runner.is_on_ground)


func test_other_input_is_ignored() -> void:
	_choose_runner()
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true

	game._unhandled_input(event)

	assert_true(session.run.runner.is_on_ground)


func test_process_advances_run_and_scrolls_flowers() -> void:
	_choose_runner()

	game._process(DELTA)

	assert_gt(session.run.elapsed, 0.0)
	assert_lt(game.get_node("Flowers").position.x, 0.0)


func test_runner_rises_on_screen_when_jumping() -> void:
	_choose_runner()
	var runner_label: Label = game.get_node("Runner")
	var ground_position := runner_label.position.y
	session.jump()

	game._process(DELTA)

	assert_lt(runner_label.position.y, ground_position)


func test_spawned_obstacle_gets_a_label_at_its_position() -> void:
	_choose_runner()

	_tick_until_obstacle()

	assert_eq(_obstacle_label_count(), 1)
	var label: Label = game.get_node("Obstacles").get_child(0)
	var expected_center := session.run.obstacles[0].x * minf(game.get_viewport_rect().size.x, game.get_viewport_rect().size.y)
	assert_almost_eq(label.position.x + label.size.x * 0.5, expected_center, 0.5)


func test_removed_obstacle_frees_its_label() -> void:
	_choose_runner()
	_tick_until_obstacle()
	var obstacle := session.run.obstacles[0]

	session.run.obstacle_removed.emit(obstacle)

	assert_eq(_obstacle_label_count(), 0)


func test_score_change_updates_score_label() -> void:
	_choose_runner()

	session.run.score_changed.emit(4)

	assert_eq(ui.get_node("%ScoreLabel").text, "⭐ 4")


func test_crash_stops_processing_and_starts_timer() -> void:
	_choose_runner()

	_crash()

	assert_false(game.is_processing())
	assert_false(game.get_node("GameOverTimer").is_stopped())
	assert_false(ui.get_node("%GameOverScreen").visible)


func test_game_over_screen_shows_after_timer() -> void:
	_choose_runner()
	_crash()

	game.get_node("GameOverTimer").timeout.emit()

	assert_true(ui.get_node("%GameOverScreen").visible)


func test_play_again_starts_fresh_run_without_old_obstacles() -> void:
	_choose_runner()
	_tick_until_obstacle()
	var old_run := session.run
	_crash()

	ui.play_again_pressed.emit()

	assert_ne(session.run, old_run)
	assert_true(session.is_running())
	assert_eq(_obstacle_label_count(), 0)


func test_change_runner_returns_to_start_screen() -> void:
	_choose_runner()
	_crash()

	ui.change_runner_pressed.emit()

	assert_true(ui.get_node("%StartScreen").visible)


func test_relayout_during_run_resizes_world() -> void:
	_choose_runner()
	_tick_until_obstacle()
	session.run.resize(99.0)

	game._layout()

	var screen := game.get_viewport_rect().size
	assert_almost_eq(session.run.world_width, screen.x / minf(screen.x, screen.y), 0.0001)
	assert_eq(_obstacle_label_count(), 1)
