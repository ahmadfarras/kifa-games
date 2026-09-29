class_name RunnerGame
extends Node2D

## Draws the Runner world and forwards input to RunnerSession.
## Domain units are converted to pixels with _unit (= shortest screen side).

signal exit_requested

# Visible body height relative to the hitbox size; a bit bigger reads better on small screens.
const RUNNER_DRAW_SCALE := 1.25
## Size of one obstacle texture pixel in domain units, so obstacle footprints (hitboxes) come from the art.
const OBSTACLE_UNITS_PER_PIXEL := 0.0013

## One texture per obstacle variant; the domain picks variants by index.
@export var obstacle_textures: Array[Texture2D] = []
## Shared by every obstacle sprite (one material keeps them batchable); outlines obstacles so kids can
## tell them apart from decorations.
@export var obstacle_material: Material

var _session: RunnerSession
var _rng: RandomNumberGenerator
var _unit := 1.0
var _ground_y := 0.0
var _obstacle_footprints: Array[Vector2] = []
var _obstacle_sprites := {}
var _spare_obstacle_sprites: Array[Sprite2D] = []

@onready var _background: RunnerBackground = $Background
@onready var _obstacles: Node2D = $Obstacles
@onready var _runner: RunnerSprite = $Runner
@onready var _game_over_timer: Timer = $GameOverTimer
@onready var _ui: RunnerUi = %RunnerUi


func setup(session: RunnerSession, rng: RandomNumberGenerator) -> void:
	_session = session
	_rng = rng


func _ready() -> void:
	for texture in obstacle_textures:
		_obstacle_footprints.append(texture.get_size() * OBSTACLE_UNITS_PER_PIXEL)
	_background.setup(_rng)
	_session.run_ended.connect(_on_run_ended)
	_ui.character_selected.connect(_on_character_selected)
	_ui.runner_chosen.connect(_on_runner_chosen)
	_ui.play_again_pressed.connect(_start_run)
	_ui.change_runner_pressed.connect(_ui.show_start)
	_ui.back_pressed.connect(exit_requested.emit)
	_game_over_timer.timeout.connect(_on_game_over_timer_timeout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_ui.show_start()
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_session.jump()


func _process(delta: float) -> void:
	_session.tick(delta)
	_sync_world()


func _on_character_selected(frames: SpriteFrames) -> void:
	_runner.set_character(frames)
	_fit_runner()


func _on_runner_chosen(frames: SpriteFrames) -> void:
	_on_character_selected(frames)
	_start_run()


func _start_run() -> void:
	_clear_obstacles()
	_background.reset()
	var run := _session.start_run(get_viewport_rect().size.x / _unit, _obstacle_footprints)
	run.obstacle_spawned.connect(_on_obstacle_spawned)
	run.obstacle_removed.connect(_on_obstacle_removed)
	run.score_changed.connect(_ui.set_score)
	_ui.show_playing(_session.best_score)
	_sync_world()
	set_process(true)


func _on_run_ended(_score: int, _best_score: int, _coins_earned: int) -> void:
	set_process(false)
	_game_over_timer.start()


func _on_game_over_timer_timeout() -> void:
	_ui.show_game_over(_session.run.score, _session.best_score)


func _on_obstacle_spawned(obstacle: Obstacle) -> void:
	var sprite: Sprite2D = _spare_obstacle_sprites.pop_back() if not _spare_obstacle_sprites.is_empty() else _new_obstacle_sprite()
	var texture := obstacle_textures[obstacle.variant]
	sprite.texture = texture
	sprite.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())
	_obstacle_sprites[obstacle] = sprite
	_fit_obstacle(obstacle, sprite)
	sprite.show()


func _on_obstacle_removed(obstacle: Obstacle) -> void:
	_recycle(_obstacle_sprites[obstacle])
	_obstacle_sprites.erase(obstacle)


func _clear_obstacles() -> void:
	for sprite: Sprite2D in _obstacle_sprites.values():
		_recycle(sprite)
	_obstacle_sprites.clear()


func _new_obstacle_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.material = obstacle_material
	_obstacles.add_child(sprite)
	return sprite


func _recycle(sprite: Sprite2D) -> void:
	sprite.hide()
	_spare_obstacle_sprites.append(sprite)


func _sync_world() -> void:
	var run := _session.run
	_update_runner(run)
	for obstacle: Obstacle in _obstacle_sprites:
		_obstacle_sprites[obstacle].position.x = obstacle.x * _unit
	_background.scroll(run.distance * _unit)


func _layout() -> void:
	var screen := get_viewport_rect().size
	_unit = minf(screen.x, screen.y)
	_background.fit(screen)
	_ground_y = _background.ground_y()
	_fit_runner()
	for obstacle: Obstacle in _obstacle_sprites:
		_fit_obstacle(obstacle, _obstacle_sprites[obstacle])
	if _session.run == null:
		_runner.show_idle()
		_runner.position = Vector2(screen.x * Run.RUNNER_X_RATIO, _ground_y)
		return
	_session.resize_world(screen.x / _unit)
	_sync_world()


func _update_runner(run: Run) -> void:
	_runner.show_run_state(run)
	_runner.position = Vector2(run.runner_x() * _unit, _ground_y - run.runner.height * _unit)


func _fit_runner() -> void:
	_runner.fit_height(Runner.SIZE * RUNNER_DRAW_SCALE * _unit)


func _fit_obstacle(obstacle: Obstacle, sprite: Sprite2D) -> void:
	sprite.scale = Vector2.ONE * OBSTACLE_UNITS_PER_PIXEL * _unit
	sprite.position = Vector2(obstacle.x * _unit, _ground_y)
