extends GutTest

const SIZE := 0.1
const RUNNER_X := 0.5


func test_init_sets_fields() -> void:
	var obstacle := Obstacle.new(1.2, SIZE, Obstacle.Kind.ROCK)

	assert_eq(obstacle.x, 1.2)
	assert_eq(obstacle.size, SIZE)
	assert_eq(obstacle.kind, Obstacle.Kind.ROCK)


func test_move_shifts_left() -> void:
	var obstacle := Obstacle.new(1.0, SIZE, Obstacle.Kind.CACTUS)

	obstacle.move(0.25)

	assert_almost_eq(obstacle.x, 0.75, 0.0001)


func test_random_stays_within_size_range_and_valid_kind() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	for i in 100:
		var obstacle := Obstacle.random(2.0, rng)
		assert_eq(obstacle.x, 2.0)
		assert_between(obstacle.size, Obstacle.MIN_SIZE, Obstacle.MIN_SIZE + Obstacle.SIZE_VARIANCE)
		assert_between(obstacle.kind, 0, Obstacle.Kind.size() - 1)


func test_random_is_deterministic_for_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 7
	rng_b.seed = 7

	var a := Obstacle.random(1.0, rng_a)
	var b := Obstacle.random(1.0, rng_b)

	assert_eq(a.size, b.size)
	assert_eq(a.kind, b.kind)


func test_hits_runner_on_ground_at_same_x() -> void:
	var obstacle := Obstacle.new(RUNNER_X, SIZE, Obstacle.Kind.CACTUS)

	assert_true(obstacle.hits(Runner.new(), RUNNER_X))


func test_misses_runner_far_away() -> void:
	var obstacle := Obstacle.new(RUNNER_X + 1.0, SIZE, Obstacle.Kind.CACTUS)

	assert_false(obstacle.hits(Runner.new(), RUNNER_X))


func test_misses_runner_just_outside_reach() -> void:
	var reach := Runner.HITBOX_HALF_WIDTH + SIZE * Obstacle.HITBOX_HALF_WIDTH_RATIO
	var obstacle := Obstacle.new(RUNNER_X + reach, SIZE, Obstacle.Kind.CACTUS)

	assert_false(obstacle.hits(Runner.new(), RUNNER_X))


func test_misses_runner_jumping_over() -> void:
	var runner := Runner.new()
	runner.height = SIZE * Obstacle.HITBOX_HEIGHT_RATIO
	var obstacle := Obstacle.new(RUNNER_X, SIZE, Obstacle.Kind.CACTUS)

	assert_false(obstacle.hits(runner, RUNNER_X))
