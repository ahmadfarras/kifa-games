class_name Obstacle
extends RefCounted

## Something scrolling toward the runner. Touching it ends the run.

enum Kind { CACTUS, ROCK, LOG, MUSHROOM }

const MIN_SIZE := 0.07
const SIZE_VARIANCE := 0.045
# Hitbox is smaller than the visual so near misses feel fair to kids.
const HITBOX_HALF_WIDTH_RATIO := 0.34
const HITBOX_HEIGHT_RATIO := 0.62

var x: float
var size: float
var kind: Kind


func _init(start_x: float, obstacle_size: float, obstacle_kind: Kind) -> void:
	x = start_x
	size = obstacle_size
	kind = obstacle_kind


static func random(start_x: float, rng: RandomNumberGenerator) -> Obstacle:
	var obstacle_size := MIN_SIZE + rng.randf() * SIZE_VARIANCE
	var obstacle_kind := rng.randi_range(0, Kind.size() - 1) as Kind
	return Obstacle.new(start_x, obstacle_size, obstacle_kind)


func move(distance: float) -> void:
	x -= distance


func hits(runner: Runner, runner_x: float) -> bool:
	var reach := Runner.HITBOX_HALF_WIDTH + size * HITBOX_HALF_WIDTH_RATIO
	return absf(x - runner_x) < reach and runner.height < size * HITBOX_HEIGHT_RATIO
