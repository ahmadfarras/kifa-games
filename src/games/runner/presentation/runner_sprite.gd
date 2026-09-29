class_name RunnerSprite
extends AnimatedSprite2D

## The runner character on screen: picks the animation for the run state and keeps the feet on its position.
## Sprite packs pad their frames differently, so size and anchor come from the visible body of each
## animation's first frame, precomputed by tools/prepare_runner_assets.gd into the frames' metadata.

const ANIM_IDLE := &"idle"
const ANIM_RUN := &"run"
const ANIM_JUMP := &"jump"
const ANIM_DEAD := &"dead"
## SpriteFrames metadata: animation -> Rect2i of the first frame's visible pixels.
const BODIES_META := &"bodies"


func _ready() -> void:
	_anchor()


static func animation_for(run: Run) -> StringName:
	if run.is_over:
		return ANIM_DEAD
	if not run.runner.is_on_ground:
		return ANIM_JUMP
	return ANIM_RUN


func set_character(frames: SpriteFrames) -> void:
	sprite_frames = frames
	_anchor()


func fit_height(height: float) -> void:
	scale = Vector2.ONE * (height / _body(ANIM_IDLE).size.y)


func show_idle() -> void:
	_play(ANIM_IDLE)
	speed_scale = 1.0


func show_run_state(run: Run) -> void:
	var next := animation_for(run)
	_play(next)
	speed_scale = _speed_scale_for(next, run)


func _speed_scale_for(next: StringName, run: Run) -> float:
	if next == ANIM_RUN:
		return run.speed / Run.START_SPEED
	if next == ANIM_JUMP:
		# Stretch the jump animation so it lasts exactly one jump.
		return sprite_frames.get_frame_count(ANIM_JUMP) / (sprite_frames.get_animation_speed(ANIM_JUMP) * Runner.AIRTIME)
	return 1.0


func _play(next: StringName) -> void:
	if animation == next:
		return
	play(next)
	_anchor()


func _anchor() -> void:
	var body := _body(animation)
	offset = -Vector2(body.position.x + body.size.x * 0.5, body.end.y)


func _body(animation_name: StringName) -> Rect2i:
	return sprite_frames.get_meta(BODIES_META)[animation_name]
