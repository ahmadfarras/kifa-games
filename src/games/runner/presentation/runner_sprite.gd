class_name RunnerSprite
extends AnimatedSprite2D

## The runner character on screen: picks the animation for the run state and keeps the feet on its position.
## Sprite packs pad their frames differently, so size and anchor come from the visible (non-transparent)
## pixels of each animation's first frame, not from the canvas size.

const ANIM_IDLE := &"idle"
const ANIM_RUN := &"run"
const ANIM_JUMP := &"jump"
const ANIM_DEAD := &"dead"

var _visible_rects := {}


func _ready() -> void:
	_anchor()


static func animation_for(run: Run) -> StringName:
	if run.is_over:
		return ANIM_DEAD
	if not run.runner.is_on_ground:
		return ANIM_JUMP
	return ANIM_RUN


static func visible_rect(texture: Texture2D) -> Rect2i:
	return texture.get_image().get_used_rect()


func set_character(frames: SpriteFrames) -> void:
	sprite_frames = frames
	_anchor()


func fit_height(height: float) -> void:
	var body := _cached_visible_rect(sprite_frames.get_frame_texture(ANIM_IDLE, 0))
	scale = Vector2.ONE * (height / body.size.y)


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
	var body := _cached_visible_rect(sprite_frames.get_frame_texture(animation, 0))
	offset = -Vector2(body.position.x + body.size.x * 0.5, body.end.y)


func _cached_visible_rect(texture: Texture2D) -> Rect2i:
	if not _visible_rects.has(texture):
		_visible_rects[texture] = visible_rect(texture)
	return _visible_rects[texture]
