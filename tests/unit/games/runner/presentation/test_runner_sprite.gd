extends GutTest

const GIRL := preload("res://assets/runner/characters/little_girl.tres")
const BOY := preload("res://assets/runner/characters/little_boy.tres")
const CAT := preload("res://assets/runner/characters/cat.tres")
const WORLD_WIDTH := 1.8

var sprite: RunnerSprite
var run: Run


func before_each() -> void:
	sprite = RunnerSprite.new()
	sprite.sprite_frames = GIRL
	sprite.animation = RunnerSprite.ANIM_IDLE
	sprite.centered = false
	add_child_autofree(sprite)
	run = Run.new(WORLD_WIDTH, RandomNumberGenerator.new(), [Vector2(0.1, 0.1)] as Array[Vector2])


func _visible_rect(frames: SpriteFrames, animation: StringName) -> Rect2i:
	return frames.get_meta(RunnerSprite.BODIES_META)[animation]


func _expected_offset(frames: SpriteFrames, animation: StringName) -> Vector2:
	var body := _visible_rect(frames, animation)
	return -Vector2(body.position.x + body.size.x * 0.5, body.end.y)


func test_body_metadata_matches_first_frame_art() -> void:
	# Frames are cropped to their visible pixels; the margin places them inside the animation's frame box.
	for frames: SpriteFrames in [GIRL, BOY, CAT]:
		for animation in [RunnerSprite.ANIM_IDLE, RunnerSprite.ANIM_RUN, RunnerSprite.ANIM_JUMP, RunnerSprite.ANIM_DEAD]:
			var first := frames.get_frame_texture(animation, 0) as AtlasTexture
			var expected := Rect2i(Vector2i(first.margin.position), Vector2i(first.region.size))
			assert_eq(_visible_rect(frames, animation), expected, "%s %s" % [frames.resource_path, animation])


func test_frames_of_an_animation_share_one_box() -> void:
	for frames: SpriteFrames in [GIRL, BOY, CAT]:
		for animation in [RunnerSprite.ANIM_IDLE, RunnerSprite.ANIM_RUN, RunnerSprite.ANIM_JUMP, RunnerSprite.ANIM_DEAD]:
			var size := frames.get_frame_texture(animation, 0).get_size()
			for i in frames.get_frame_count(animation):
				assert_eq(frames.get_frame_texture(animation, i).get_size(), size)


func test_ready_anchors_feet_of_current_animation() -> void:
	assert_eq(sprite.offset, _expected_offset(GIRL, RunnerSprite.ANIM_IDLE))


func test_set_character_changes_frames_and_anchor() -> void:
	sprite.set_character(BOY)

	assert_eq(sprite.sprite_frames, BOY)
	assert_eq(sprite.offset, _expected_offset(BOY, RunnerSprite.ANIM_IDLE))


func test_fit_height_scales_visible_body_to_height() -> void:
	for frames: SpriteFrames in [GIRL, BOY, CAT]:
		sprite.set_character(frames)

		sprite.fit_height(100.0)

		assert_almost_eq(_visible_rect(frames, RunnerSprite.ANIM_IDLE).size.y * sprite.scale.y, 100.0, 0.001)


func test_show_idle_plays_idle_at_normal_speed() -> void:
	sprite.show_run_state(run)

	sprite.show_idle()

	assert_eq(sprite.animation, RunnerSprite.ANIM_IDLE)
	assert_eq(sprite.speed_scale, 1.0)


func test_animation_for_run_on_ground() -> void:
	assert_eq(RunnerSprite.animation_for(run), RunnerSprite.ANIM_RUN)


func test_animation_for_jump_in_air() -> void:
	run.jump()

	assert_eq(RunnerSprite.animation_for(run), RunnerSprite.ANIM_JUMP)


func test_animation_for_dead_when_over() -> void:
	run.jump()
	run.is_over = true

	assert_eq(RunnerSprite.animation_for(run), RunnerSprite.ANIM_DEAD)


func test_show_run_state_anchors_new_animation() -> void:
	run.jump()

	sprite.show_run_state(run)

	assert_eq(sprite.animation, RunnerSprite.ANIM_JUMP)
	assert_eq(sprite.offset, _expected_offset(GIRL, RunnerSprite.ANIM_JUMP))


func test_run_speed_follows_world_speed() -> void:
	run.speed = Run.MAX_SPEED

	sprite.show_run_state(run)

	assert_almost_eq(sprite.speed_scale, Run.MAX_SPEED / Run.START_SPEED, 0.0001)


func test_jump_animation_lasts_one_jump() -> void:
	for frames: SpriteFrames in [GIRL, BOY, CAT]:
		sprite.set_character(frames)
		run.runner.is_on_ground = false

		sprite.show_run_state(run)

		var fps := frames.get_animation_speed(RunnerSprite.ANIM_JUMP) * sprite.speed_scale
		assert_almost_eq(frames.get_frame_count(RunnerSprite.ANIM_JUMP) / fps, Runner.AIRTIME, 0.0001)


func test_dead_plays_at_normal_speed() -> void:
	run.is_over = true

	sprite.show_run_state(run)

	assert_eq(sprite.animation, RunnerSprite.ANIM_DEAD)
	assert_eq(sprite.speed_scale, 1.0)


func test_same_animation_is_not_restarted() -> void:
	sprite.show_run_state(run)
	sprite.frame = 5

	sprite.show_run_state(run)

	assert_eq(sprite.frame, 5)


func test_characters_have_all_animations() -> void:
	for frames: SpriteFrames in [GIRL, BOY, CAT]:
		for animation in [RunnerSprite.ANIM_IDLE, RunnerSprite.ANIM_RUN, RunnerSprite.ANIM_JUMP, RunnerSprite.ANIM_DEAD]:
			assert_gt(frames.get_frame_count(animation), 0, "%s missing %s" % [frames.resource_path, animation])
