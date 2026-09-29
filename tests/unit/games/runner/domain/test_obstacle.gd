extends GutTest

const FOOTPRINT := Vector2(0.12, 0.1)
const RUNNER_X := 0.5
const FOOTPRINTS: Array[Vector2] = [Vector2(0.1, 0.1), Vector2(0.15, 0.05), Vector2(0.08, 0.14)]


func test_init_sets_fields() -> void:
	var obstacle := Obstacle.new(1.2, FOOTPRINT, 2)

	assert_eq(obstacle.x, 1.2)
	assert_eq(obstacle.width, FOOTPRINT.x)
	assert_eq(obstacle.height, FOOTPRINT.y)
	assert_eq(obstacle.variant, 2)


func test_move_shifts_left() -> void:
	var obstacle := Obstacle.new(1.0, FOOTPRINT, 0)

	obstacle.move(0.25)

	assert_almost_eq(obstacle.x, 0.75, 0.0001)


func test_random_uses_footprint_of_picked_variant() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	for i in 100:
		var obstacle := Obstacle.random(2.0, FOOTPRINTS, rng)
		assert_eq(obstacle.x, 2.0)
		assert_between(obstacle.variant, 0, FOOTPRINTS.size() - 1)
		assert_eq(Vector2(obstacle.width, obstacle.height), FOOTPRINTS[obstacle.variant])


func test_random_picks_every_variant() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var seen := {}

	for i in 100:
		seen[Obstacle.random(0.0, FOOTPRINTS, rng).variant] = true

	assert_eq(seen.size(), FOOTPRINTS.size())


func test_random_is_deterministic_for_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 7
	rng_b.seed = 7

	assert_eq(Obstacle.random(1.0, FOOTPRINTS, rng_a).variant, Obstacle.random(1.0, FOOTPRINTS, rng_b).variant)


func test_hits_runner_on_ground_at_same_x() -> void:
	var obstacle := Obstacle.new(RUNNER_X, FOOTPRINT, 0)

	assert_true(obstacle.hits(Runner.new(), RUNNER_X))


func test_misses_runner_far_away() -> void:
	var obstacle := Obstacle.new(RUNNER_X + 1.0, FOOTPRINT, 0)

	assert_false(obstacle.hits(Runner.new(), RUNNER_X))


func test_wider_obstacle_reaches_further() -> void:
	var narrow := Obstacle.new(RUNNER_X + 0.08, Vector2(0.05, 0.1), 0)
	var wide := Obstacle.new(RUNNER_X + 0.08, Vector2(0.2, 0.1), 0)

	assert_false(narrow.hits(Runner.new(), RUNNER_X))
	assert_true(wide.hits(Runner.new(), RUNNER_X))


func test_misses_runner_just_outside_reach() -> void:
	var reach := Runner.HITBOX_HALF_WIDTH + FOOTPRINT.x * Obstacle.HITBOX_HALF_WIDTH_RATIO
	var obstacle := Obstacle.new(RUNNER_X + reach, FOOTPRINT, 0)

	assert_false(obstacle.hits(Runner.new(), RUNNER_X))


func test_misses_runner_jumping_over() -> void:
	var runner := Runner.new()
	runner.height = FOOTPRINT.y * Obstacle.HITBOX_HEIGHT_RATIO
	var obstacle := Obstacle.new(RUNNER_X, FOOTPRINT, 0)

	assert_false(obstacle.hits(runner, RUNNER_X))


func test_taller_obstacle_needs_higher_jump() -> void:
	var runner := Runner.new()
	runner.height = 0.09

	assert_false(Obstacle.new(RUNNER_X, Vector2(0.1, 0.1), 0).hits(runner, RUNNER_X))
	assert_true(Obstacle.new(RUNNER_X, Vector2(0.1, 0.14), 0).hits(runner, RUNNER_X))


func test_every_footprint_is_jumpable() -> void:
	var apex := Runner.JUMP_VELOCITY * Runner.JUMP_VELOCITY / (2.0 * Runner.GRAVITY)

	for footprint in FOOTPRINTS:
		assert_lt(footprint.y * Obstacle.HITBOX_HEIGHT_RATIO, apex)
