class_name Runner
extends RefCounted

## The character the kid controls. Units: 1.0 = shortest screen side.

const SIZE := 0.13
const HITBOX_HALF_WIDTH := SIZE * 0.28
const JUMP_VELOCITY := 1.7
const GRAVITY := 4.3
const AIRTIME := 2.0 * JUMP_VELOCITY / GRAVITY

var height := 0.0
var velocity := 0.0
var is_on_ground := true


func jump() -> bool:
	if not is_on_ground:
		return false
	velocity = JUMP_VELOCITY
	is_on_ground = false
	return true


func tick(delta: float) -> void:
	if is_on_ground:
		return
	velocity -= GRAVITY * delta
	height += velocity * delta
	if height <= 0.0:
		_land()


func _land() -> void:
	height = 0.0
	velocity = 0.0
	is_on_ground = true
