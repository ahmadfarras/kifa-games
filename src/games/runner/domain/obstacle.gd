class_name Obstacle
extends RefCounted

## Something scrolling toward the runner. Touching it ends the run.
## Its footprint (width, height) comes from the obstacle's art; `variant` says which art it is.

# Hitbox is smaller than the art so near misses feel fair to kids.
const HITBOX_HALF_WIDTH_RATIO := 0.35
const HITBOX_HEIGHT_RATIO := 0.75

var x: float
var width: float
var height: float
var variant: int


func _init(start_x: float, footprint: Vector2, obstacle_variant: int) -> void:
	x = start_x
	width = footprint.x
	height = footprint.y
	variant = obstacle_variant


static func random(start_x: float, footprints: Array[Vector2], rng: RandomNumberGenerator) -> Obstacle:
	var picked := rng.randi_range(0, footprints.size() - 1)
	return Obstacle.new(start_x, footprints[picked], picked)


func move(distance: float) -> void:
	x -= distance


func hits(runner: Runner, runner_x: float) -> bool:
	var reach := Runner.HITBOX_HALF_WIDTH + width * HITBOX_HALF_WIDTH_RATIO
	return absf(x - runner_x) < reach and runner.height < height * HITBOX_HEIGHT_RATIO
