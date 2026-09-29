extends GutTest

const RunnerGameScene := preload("res://src/games/runner/presentation/runner_game.tscn")
const DELTA := 0.02
const GIRL := preload("res://assets/runner/characters/little_girl.tres")
const BOY := preload("res://assets/runner/characters/little_boy.tres")
const FakeProgressRepository := preload("res://tests/unit/games/runner/fake_progress_repository.gd")


var session: RunnerSession
var game: RunnerGame
var ui: RunnerUi


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	session = RunnerSession.new(FakeProgressRepository.new(), rng)
	game = RunnerGameScene.instantiate()
	game.setup(session, rng)
	add_child_autofree(game)
	ui = game.get_node("%RunnerUi")


func _choose_runner() -> void:
	ui.runner_chosen.emit(GIRL)


func _tick_until_obstacle() -> void:
	while session.run.obstacles.is_empty():
		session.run.runner.height = 10.0
		game._process(DELTA)


func _crash() -> void:
	session.run.obstacles.append(Obstacle.new(session.run.runner_x(), Vector2(0.1, 0.1), 0))
	game._process(DELTA)


func _visible_obstacle_sprites() -> Array[Sprite2D]:
	var visible: Array[Sprite2D] = []
	for sprite: Sprite2D in game.get_node("Obstacles").get_children():
		if sprite.visible:
			visible.append(sprite)
	return visible


func _unit() -> float:
	var screen := game.get_viewport_rect().size
	return minf(screen.x, screen.y)


func test_starts_on_start_screen_without_processing() -> void:
	assert_true(ui.get_node("%StartScreen").visible)
	assert_false(game.is_processing())
	assert_null(session.run)


func test_ground_line_comes_from_background() -> void:
	assert_eq(game._ground_y, game.get_node("Background").ground_y())
	assert_gt(game._ground_y, 0.0)


func test_obstacle_footprints_come_from_art() -> void:
	var textures: Array[Texture2D] = game.obstacle_textures

	assert_eq(game._obstacle_footprints.size(), textures.size())
	for i in textures.size():
		assert_eq(game._obstacle_footprints[i], textures[i].get_size() * RunnerGame.OBSTACLE_UNITS_PER_PIXEL)


func test_every_obstacle_is_jumpable() -> void:
	var apex := Runner.JUMP_VELOCITY * Runner.JUMP_VELOCITY / (2.0 * Runner.GRAVITY)

	for footprint in game._obstacle_footprints:
		assert_lt(footprint.y * Obstacle.HITBOX_HEIGHT_RATIO, apex)


func test_choosing_runner_starts_run() -> void:
	_choose_runner()

	assert_true(session.is_running())
	assert_eq(game.get_node("Runner").sprite_frames, GIRL)
	assert_true(ui.get_node("%ScoreBar").visible)
	assert_true(game.is_processing())


func test_jump_action_makes_runner_jump() -> void:
	_choose_runner()
	var event := InputEventAction.new()
	event.action = "jump"
	event.pressed = true

	game._unhandled_input(event)

	assert_false(session.run.runner.is_on_ground)


func test_other_input_is_ignored() -> void:
	_choose_runner()
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true

	game._unhandled_input(event)

	assert_true(session.run.runner.is_on_ground)


func test_process_advances_run_and_scrolls_background() -> void:
	_choose_runner()

	game._process(DELTA)

	assert_gt(session.run.elapsed, 0.0)
	assert_lt(game.get_node("Background/Plants").position.x, 0.0)


func test_runner_rises_on_screen_when_jumping() -> void:
	_choose_runner()
	var runner: AnimatedSprite2D = game.get_node("Runner")
	var ground_position := runner.position.y
	session.jump()

	game._process(DELTA)

	assert_lt(runner.position.y, ground_position)


func test_runner_idles_on_start_screen() -> void:
	var runner: AnimatedSprite2D = game.get_node("Runner")

	assert_eq(runner.animation, RunnerSprite.ANIM_IDLE)
	assert_true(runner.is_playing())


func test_runner_feet_are_on_ground() -> void:
	_choose_runner()

	assert_almost_eq(game.get_node("Runner").position.y, game._ground_y, 0.01)


func test_runner_body_scaled_to_draw_size() -> void:
	var runner: RunnerSprite = game.get_node("Runner")
	var body: Rect2i = runner.sprite_frames.get_meta(RunnerSprite.BODIES_META)[RunnerSprite.ANIM_IDLE]

	assert_almost_eq(body.size.y * runner.scale.y, Runner.SIZE * RunnerGame.RUNNER_DRAW_SCALE * game._unit, 0.01)


func test_selecting_character_previews_it_on_field() -> void:
	ui.character_selected.emit(BOY)

	assert_eq(game.get_node("Runner").sprite_frames, BOY)
	assert_null(session.run)


func test_choosing_another_character_swaps_frames() -> void:
	ui.runner_chosen.emit(BOY)

	assert_eq(game.get_node("Runner").sprite_frames, BOY)


func test_runner_plays_run_while_on_ground() -> void:
	_choose_runner()

	game._process(DELTA)

	assert_eq(game.get_node("Runner").animation, RunnerSprite.ANIM_RUN)


func test_runner_plays_dead_after_crash() -> void:
	_choose_runner()

	_crash()

	var runner: AnimatedSprite2D = game.get_node("Runner")
	assert_eq(runner.animation, RunnerSprite.ANIM_DEAD)
	assert_eq(runner.speed_scale, 1.0)


func test_new_run_after_crash_plays_run_again() -> void:
	_choose_runner()
	_crash()

	ui.play_again_pressed.emit()

	assert_eq(game.get_node("Runner").animation, RunnerSprite.ANIM_RUN)


func test_spawned_obstacle_shows_its_art_on_the_ground() -> void:
	_choose_runner()

	_tick_until_obstacle()

	var obstacle := session.run.obstacles[0]
	var sprites := _visible_obstacle_sprites()
	assert_eq(sprites.size(), 1)
	assert_eq(sprites[0].texture, game.obstacle_textures[obstacle.variant])
	assert_almost_eq(sprites[0].position.x, obstacle.x * _unit(), 0.01)
	assert_almost_eq(sprites[0].position.y, game._ground_y, 0.01)


func test_obstacle_sprite_is_drawn_at_footprint_size() -> void:
	_choose_runner()
	_tick_until_obstacle()

	var obstacle := session.run.obstacles[0]
	var sprite := _visible_obstacle_sprites()[0]
	assert_almost_eq(sprite.texture.get_height() * sprite.scale.y, obstacle.height * _unit(), 0.01)
	assert_eq(sprite.offset, Vector2(-sprite.texture.get_width() * 0.5, -sprite.texture.get_height()))


func test_obstacles_share_outline_material() -> void:
	_choose_runner()
	_tick_until_obstacle()

	var material := _visible_obstacle_sprites()[0].material as ShaderMaterial
	assert_not_null(material)
	assert_eq(material, game.obstacle_material)
	assert_eq(material.shader.resource_path, "res://src/games/runner/presentation/obstacle_outline.gdshader")


func test_obstacle_moves_with_world() -> void:
	_choose_runner()
	_tick_until_obstacle()
	var sprite := _visible_obstacle_sprites()[0]
	var start_x := sprite.position.x

	session.run.runner.height = 10.0
	game._process(DELTA)

	assert_lt(sprite.position.x, start_x)


func test_removed_obstacle_hides_its_sprite() -> void:
	_choose_runner()
	_tick_until_obstacle()
	var obstacle := session.run.obstacles[0]

	session.run.obstacle_removed.emit(obstacle)

	assert_eq(_visible_obstacle_sprites().size(), 0)


func test_obstacle_sprites_are_reused() -> void:
	_choose_runner()
	_tick_until_obstacle()
	session.run.obstacle_removed.emit(session.run.obstacles.pop_front())
	var pool_size := game.get_node("Obstacles").get_child_count()

	_tick_until_obstacle()

	assert_eq(game.get_node("Obstacles").get_child_count(), pool_size)
	assert_eq(_visible_obstacle_sprites().size(), 1)


func test_score_change_updates_score_label() -> void:
	_choose_runner()

	session.run.score_changed.emit(4)

	assert_eq(ui.get_node("%ScoreLabel").text, "⭐ 4")


func test_crash_stops_processing_and_starts_timer() -> void:
	_choose_runner()

	_crash()

	assert_false(game.is_processing())
	assert_false(game.get_node("GameOverTimer").is_stopped())
	assert_false(ui.get_node("%GameOverScreen").visible)


func test_game_over_screen_shows_after_timer() -> void:
	_choose_runner()
	_crash()

	game.get_node("GameOverTimer").timeout.emit()

	assert_true(ui.get_node("%GameOverScreen").visible)


func test_play_again_starts_fresh_run_without_old_obstacles() -> void:
	_choose_runner()
	_tick_until_obstacle()
	var old_run := session.run
	_crash()

	ui.play_again_pressed.emit()

	assert_ne(session.run, old_run)
	assert_true(session.is_running())
	assert_eq(_visible_obstacle_sprites().size(), 0)


func test_back_button_requests_exit() -> void:
	watch_signals(game)

	ui.back_pressed.emit()

	assert_signal_emitted(game, "exit_requested")


func test_change_runner_returns_to_start_screen() -> void:
	_choose_runner()
	_crash()

	ui.change_runner_pressed.emit()

	assert_true(ui.get_node("%StartScreen").visible)


func test_relayout_during_run_resizes_world() -> void:
	_choose_runner()
	_tick_until_obstacle()
	session.run.resize(99.0)

	game._layout()

	var screen := game.get_viewport_rect().size
	assert_almost_eq(session.run.world_width, screen.x / minf(screen.x, screen.y), 0.0001)
	assert_eq(_visible_obstacle_sprites().size(), 1)


func test_start_screen_shows_coins_and_locks() -> void:
	assert_eq(ui.get_node("%CoinsLabel").text, "🪙 0")
	assert_true(ui.get_node("%CharacterButtons/Cat").is_locked)


func test_crash_shows_coins_earned_and_new_balance() -> void:
	_choose_runner()
	session.run.elapsed = 12.0 / Run.SCORE_PER_SECOND
	_crash()

	game.get_node("GameOverTimer").timeout.emit()

	assert_eq(ui.get_node("%FinalCoinsLabel").text, "+12 🪙")
	assert_eq(ui.get_node("%CoinsLabel").text, "🪙 12")
