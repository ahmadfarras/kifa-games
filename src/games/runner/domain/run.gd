class_name Run
extends RefCounted

## One play session, from start until the runner hits an obstacle.
## Other layers read its fields but change state only through jump() and tick().

signal obstacle_spawned(obstacle: Obstacle)
signal obstacle_removed(obstacle: Obstacle)
signal score_changed(score: int)
signal crashed

const START_SPEED := 0.45
const MAX_SPEED := 1.05
const ACCELERATION := 0.016
const FIRST_GAP := 0.9
# Gaps are measured in seconds of travel so they stay jumpable as speed grows.
const MIN_GAP_SECONDS := 1.1
const GAP_SECONDS_VARIANCE := 0.9
const SPAWN_MARGIN := 0.15
const DESPAWN_X := -0.2
const RUNNER_X_RATIO := 0.18
const SCORE_PER_SECOND := 2.0
# Caps a long frame (e.g. tab switch) so the runner can't pass through obstacles.
const MAX_TICK := 0.05

var runner := Runner.new()
var obstacles: Array[Obstacle] = []
var world_width: float
var elapsed := 0.0
var speed := START_SPEED
var distance := 0.0
var score := 0
var is_over := false

var _gap_left := FIRST_GAP
var _rng: RandomNumberGenerator


func _init(width: float, rng: RandomNumberGenerator) -> void:
	world_width = width
	_rng = rng


func resize(width: float) -> void:
	world_width = width


func runner_x() -> float:
	return world_width * RUNNER_X_RATIO


func jump() -> bool:
	if is_over:
		return false
	return runner.jump()


func tick(delta: float) -> void:
	if is_over:
		return
	delta = minf(delta, MAX_TICK)
	elapsed += delta
	speed = minf(START_SPEED + elapsed * ACCELERATION, MAX_SPEED)
	runner.tick(delta)
	_scroll(speed * delta)
	_update_score()
	if _runner_hit_obstacle():
		is_over = true
		crashed.emit()


func _scroll(step: float) -> void:
	distance += step
	for obstacle in obstacles:
		obstacle.move(step)
	# Obstacles move in spawn order, so only the front can be off-screen.
	while not obstacles.is_empty() and obstacles[0].x < DESPAWN_X:
		obstacle_removed.emit(obstacles.pop_front())
	_gap_left -= step
	if _gap_left <= 0.0:
		_spawn_obstacle()


func _spawn_obstacle() -> void:
	_gap_left = speed * (MIN_GAP_SECONDS + _rng.randf() * GAP_SECONDS_VARIANCE)
	var obstacle := Obstacle.random(world_width + SPAWN_MARGIN, _rng)
	obstacles.append(obstacle)
	obstacle_spawned.emit(obstacle)


func _update_score() -> void:
	var new_score := int(elapsed * SCORE_PER_SECOND)
	if new_score == score:
		return
	score = new_score
	score_changed.emit(score)


func _runner_hit_obstacle() -> bool:
	var x := runner_x()
	for obstacle in obstacles:
		if obstacle.hits(runner, x):
			return true
	return false
