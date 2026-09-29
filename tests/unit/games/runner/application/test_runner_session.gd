extends GutTest

const WORLD_WIDTH := 1.8
const DELTA := 0.01
const FOOTPRINTS: Array[Vector2] = [Vector2(0.1, 0.1)]


class FakeBestScoreRepository:
	extends BestScoreRepository

	var stored := 0
	var save_count := 0

	func load_best() -> int:
		return stored

	func save_best(score: int) -> void:
		stored = score
		save_count += 1


var repository: FakeBestScoreRepository
var session: RunnerSession


func before_each() -> void:
	repository = FakeBestScoreRepository.new()
	repository.stored = 5
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	session = RunnerSession.new(repository, rng)


func _crash_with_score(score: int) -> void:
	session.run.score = score
	session.run.obstacles.append(Obstacle.new(session.run.runner_x(), FOOTPRINTS[0], 0))
	session.run.elapsed = score / Run.SCORE_PER_SECOND
	session.tick(DELTA)


func test_loads_best_score_on_init() -> void:
	assert_eq(session.best_score, 5)


func test_no_run_before_start() -> void:
	assert_null(session.run)
	assert_false(session.is_running())


func test_start_run_creates_running_run() -> void:
	var run := session.start_run(WORLD_WIDTH, FOOTPRINTS)

	assert_eq(session.run, run)
	assert_eq(run.world_width, WORLD_WIDTH)
	assert_true(session.is_running())


func test_start_run_replaces_previous_run() -> void:
	var first := session.start_run(WORLD_WIDTH, FOOTPRINTS)

	var second := session.start_run(WORLD_WIDTH, FOOTPRINTS)

	assert_ne(first, second)
	assert_eq(session.run, second)


func test_resize_world_without_run_does_nothing() -> void:
	session.resize_world(3.0)

	assert_null(session.run)


func test_resize_world_resizes_current_run() -> void:
	session.start_run(WORLD_WIDTH, FOOTPRINTS)

	session.resize_world(3.0)

	assert_eq(session.run.world_width, 3.0)


func test_jump_without_run_is_ignored() -> void:
	assert_false(session.jump())


func test_jump_during_run() -> void:
	session.start_run(WORLD_WIDTH, FOOTPRINTS)

	assert_true(session.jump())


func test_jump_after_crash_is_ignored() -> void:
	session.start_run(WORLD_WIDTH, FOOTPRINTS)
	_crash_with_score(1)

	assert_false(session.jump())


func test_tick_without_run_does_nothing() -> void:
	session.tick(DELTA)

	assert_null(session.run)


func test_tick_advances_run() -> void:
	session.start_run(WORLD_WIDTH, FOOTPRINTS)

	session.tick(DELTA)

	assert_gt(session.run.elapsed, 0.0)


func test_crash_with_new_record_saves_best() -> void:
	session.start_run(WORLD_WIDTH, FOOTPRINTS)
	watch_signals(session)

	_crash_with_score(9)

	assert_false(session.is_running())
	assert_eq(session.best_score, 9)
	assert_eq(repository.stored, 9)
	assert_signal_emitted_with_parameters(session, "run_ended", [9, 9])


func test_crash_below_record_keeps_best() -> void:
	session.start_run(WORLD_WIDTH, FOOTPRINTS)
	watch_signals(session)

	_crash_with_score(3)

	assert_eq(session.best_score, 5)
	assert_eq(repository.save_count, 0)
	assert_signal_emitted_with_parameters(session, "run_ended", [3, 5])


func test_tick_after_crash_does_not_end_twice() -> void:
	session.start_run(WORLD_WIDTH, FOOTPRINTS)
	_crash_with_score(1)
	watch_signals(session)

	session.tick(DELTA)

	assert_signal_not_emitted(session, "run_ended")
