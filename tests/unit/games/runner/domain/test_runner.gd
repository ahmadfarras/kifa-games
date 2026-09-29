extends GutTest

const DELTA := 0.01

var runner: Runner


func before_each() -> void:
	runner = Runner.new()


func test_starts_on_ground() -> void:
	assert_true(runner.is_on_ground)
	assert_eq(runner.height, 0.0)
	assert_eq(runner.velocity, 0.0)


func test_jump_from_ground_launches_upward() -> void:
	var jumped := runner.jump()

	assert_true(jumped)
	assert_false(runner.is_on_ground)
	assert_eq(runner.velocity, Runner.JUMP_VELOCITY)


func test_jump_in_air_is_ignored() -> void:
	runner.jump()
	runner.tick(DELTA)
	var velocity_before := runner.velocity

	var jumped := runner.jump()

	assert_false(jumped)
	assert_eq(runner.velocity, velocity_before)


func test_tick_on_ground_does_nothing() -> void:
	runner.tick(DELTA)

	assert_eq(runner.height, 0.0)
	assert_true(runner.is_on_ground)


func test_tick_in_air_rises_and_slows_down() -> void:
	runner.jump()

	runner.tick(DELTA)

	assert_gt(runner.height, 0.0)
	assert_almost_eq(runner.velocity, Runner.JUMP_VELOCITY - Runner.GRAVITY * DELTA, 0.0001)


func test_lands_back_on_ground_after_jump() -> void:
	runner.jump()

	for i in 200:
		runner.tick(DELTA)

	assert_true(runner.is_on_ground)
	assert_eq(runner.height, 0.0)
	assert_eq(runner.velocity, 0.0)


func test_can_jump_again_after_landing() -> void:
	runner.jump()
	for i in 200:
		runner.tick(DELTA)

	assert_true(runner.jump())
