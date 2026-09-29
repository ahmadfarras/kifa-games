extends GutTest

const WORLD_WIDTH := 1.8
const DELTA := 0.01
const FOOTPRINTS: Array[Vector2] = [Vector2(0.1, 0.1), Vector2(0.15, 0.06)]

var run: Run


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	run = Run.new(WORLD_WIDTH, rng, FOOTPRINTS)


func _tick_until_first_obstacle() -> void:
	while run.obstacles.is_empty():
		run.tick(DELTA)


func test_starts_fresh() -> void:
	assert_eq(run.world_width, WORLD_WIDTH)
	assert_eq(run.speed, Run.START_SPEED)
	assert_eq(run.score, 0)
	assert_eq(run.elapsed, 0.0)
	assert_true(run.obstacles.is_empty())
	assert_false(run.is_over)


func test_resize_changes_world_width() -> void:
	run.resize(3.0)

	assert_eq(run.world_width, 3.0)
	assert_almost_eq(run.runner_x(), 3.0 * Run.RUNNER_X_RATIO, 0.0001)


func test_runner_x_is_ratio_of_world_width() -> void:
	assert_almost_eq(run.runner_x(), WORLD_WIDTH * Run.RUNNER_X_RATIO, 0.0001)


func test_jump_makes_runner_leave_ground() -> void:
	assert_true(run.jump())
	assert_false(run.runner.is_on_ground)


func test_jump_ignored_when_over() -> void:
	run.is_over = true

	assert_false(run.jump())
	assert_true(run.runner.is_on_ground)


func test_tick_advances_time_and_distance() -> void:
	run.tick(DELTA)

	assert_almost_eq(run.elapsed, DELTA, 0.0001)
	assert_gt(run.distance, 0.0)


func test_tick_clamps_long_frames() -> void:
	run.tick(1.0)

	assert_almost_eq(run.elapsed, Run.MAX_TICK, 0.0001)


func test_speed_grows_with_time() -> void:
	run.tick(DELTA)

	assert_gt(run.speed, Run.START_SPEED)


func test_speed_is_capped() -> void:
	run.elapsed = 1000.0

	run.tick(DELTA)

	assert_eq(run.speed, Run.MAX_SPEED)


func test_tick_moves_runner_in_air() -> void:
	run.jump()

	run.tick(DELTA)

	assert_gt(run.runner.height, 0.0)


func test_spawned_obstacles_use_given_footprints() -> void:
	for i in 2000:
		run.runner.height = 10.0
		run.tick(DELTA)

	assert_gt(run.obstacles.size(), 0)
	for obstacle in run.obstacles:
		assert_eq(Vector2(obstacle.width, obstacle.height), FOOTPRINTS[obstacle.variant])


func test_first_obstacle_spawns_at_right_edge() -> void:
	watch_signals(run)

	_tick_until_first_obstacle()

	assert_eq(run.obstacles.size(), 1)
	assert_eq(run.obstacles[0].x, WORLD_WIDTH + Run.SPAWN_MARGIN)
	assert_signal_emitted_with_parameters(run, "obstacle_spawned", [run.obstacles[0]])


func test_first_obstacle_spawns_after_first_gap() -> void:
	_tick_until_first_obstacle()

	assert_gte(run.distance, Run.FIRST_GAP)
	assert_lt(run.distance, Run.FIRST_GAP + Run.MAX_SPEED * DELTA)


func test_obstacles_scroll_left() -> void:
	_tick_until_first_obstacle()
	var start_x := run.obstacles[0].x

	run.tick(DELTA)

	assert_lt(run.obstacles[0].x, start_x)


func test_next_gap_scales_with_speed() -> void:
	_tick_until_first_obstacle()
	var distance_at_first := run.distance
	while run.obstacles.size() < 2:
		run.runner.height = 10.0
		run.tick(DELTA)

	var gap := run.distance - distance_at_first
	var min_gap := Run.START_SPEED * Run.MIN_GAP_SECONDS
	var max_gap := Run.MAX_SPEED * (Run.MIN_GAP_SECONDS + Run.GAP_SECONDS_VARIANCE) + Run.MAX_SPEED * DELTA
	assert_between(gap, min_gap, max_gap)


func test_obstacle_removed_after_leaving_screen() -> void:
	var obstacle := Obstacle.new(Run.DESPAWN_X + 0.001, FOOTPRINTS[0], 0)
	run.obstacles.append(obstacle)
	watch_signals(run)

	run.tick(DELTA)

	assert_false(run.obstacles.has(obstacle))
	assert_signal_emitted_with_parameters(run, "obstacle_removed", [obstacle])


func test_score_counts_two_per_second() -> void:
	watch_signals(run)

	for i in 101:
		run.runner.height = 10.0
		run.tick(DELTA)

	assert_eq(run.score, 2)
	assert_signal_emit_count(run, "score_changed", 2)


func test_score_signal_not_emitted_without_change() -> void:
	watch_signals(run)

	run.tick(DELTA)

	assert_signal_not_emitted(run, "score_changed")


func test_crashes_when_hitting_obstacle() -> void:
	run.obstacles.append(Obstacle.new(run.runner_x(), FOOTPRINTS[0], 0))
	watch_signals(run)

	run.tick(DELTA)

	assert_true(run.is_over)
	assert_signal_emitted(run, "crashed")


func test_no_crash_when_jumping_over() -> void:
	run.obstacles.append(Obstacle.new(run.runner_x(), FOOTPRINTS[0], 0))
	run.runner.height = 1.0
	run.runner.is_on_ground = false

	run.tick(DELTA)

	assert_false(run.is_over)


func test_tick_does_nothing_when_over() -> void:
	run.is_over = true

	run.tick(DELTA)

	assert_eq(run.elapsed, 0.0)
