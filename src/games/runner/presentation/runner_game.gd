class_name RunnerGame
extends Node2D

## Draws the Runner world and forwards input to RunnerSession.
## Domain units are converted to pixels with _unit (= shortest screen side).

const GROUND_Y_RATIO := 0.8
const GROUND_EDGE_HEIGHT := 0.012
const SUN_CENTER_RATIO := Vector2(0.88, 0.12)
const SUN_SIZE := 0.1
const FLOWER_SIZE := 0.045
const FLOWER_GAP := 0.55
const OBSTACLE_GLYPH_RATIO := 1.6
const OBSTACLE_CENTER_RATIO := 0.55
# Visible body height relative to the hitbox size; a bit bigger reads better on small screens.
const RUNNER_DRAW_SCALE := 1.25
const OBSTACLE_GLYPHS := {
	Obstacle.Kind.CACTUS: "🌵",
	Obstacle.Kind.ROCK: "🪨",
	Obstacle.Kind.LOG: "🪵",
	Obstacle.Kind.MUSHROOM: "🍄",
}

var _session: RunnerSession
var _unit := 1.0
var _ground_y := 0.0
var _obstacle_labels := {}

@onready var _sun: Label = $Sun
@onready var _ground: ColorRect = $Ground
@onready var _ground_edge: ColorRect = $Ground/Edge
@onready var _flowers: Node2D = $Flowers
@onready var _obstacles: Node2D = $Obstacles
@onready var _runner: RunnerSprite = $Runner
@onready var _game_over_timer: Timer = $GameOverTimer
@onready var _ui: RunnerUi = %RunnerUi


func setup(session: RunnerSession) -> void:
	_session = session


func _ready() -> void:
	_session.run_ended.connect(_on_run_ended)
	_ui.character_selected.connect(_on_character_selected)
	_ui.runner_chosen.connect(_on_runner_chosen)
	_ui.play_again_pressed.connect(_start_run)
	_ui.change_runner_pressed.connect(_ui.show_start)
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
	var run := _session.start_run(get_viewport_rect().size.x / _unit)
	run.obstacle_spawned.connect(_on_obstacle_spawned)
	run.obstacle_removed.connect(_on_obstacle_removed)
	run.score_changed.connect(_ui.set_score)
	_ui.show_playing(_session.best_score)
	_sync_world()
	set_process(true)


func _on_run_ended(_score: int, _best_score: int) -> void:
	set_process(false)
	_game_over_timer.start()


func _on_game_over_timer_timeout() -> void:
	_ui.show_game_over(_session.run.score, _session.best_score)


func _on_obstacle_spawned(obstacle: Obstacle) -> void:
	var label := Label.new()
	label.text = OBSTACLE_GLYPHS[obstacle.kind]
	_obstacles.add_child(label)
	_obstacle_labels[obstacle] = label
	_fit_obstacle(obstacle, label)


func _on_obstacle_removed(obstacle: Obstacle) -> void:
	_obstacle_labels[obstacle].queue_free()
	_obstacle_labels.erase(obstacle)


func _clear_obstacles() -> void:
	for label: Label in _obstacle_labels.values():
		label.queue_free()
	_obstacle_labels.clear()


func _sync_world() -> void:
	var run := _session.run
	_update_runner(run)
	for obstacle: Obstacle in _obstacle_labels:
		var label: Label = _obstacle_labels[obstacle]
		label.position.x = obstacle.x * _unit - label.size.x * 0.5
	_flowers.position.x = -fmod(run.distance * _unit, FLOWER_GAP * _unit)


func _layout() -> void:
	var screen := get_viewport_rect().size
	_unit = minf(screen.x, screen.y)
	_ground_y = screen.y * GROUND_Y_RATIO
	_ground.position = Vector2(0.0, _ground_y)
	_ground.size = Vector2(screen.x, screen.y - _ground_y)
	_ground_edge.size = Vector2(screen.x, GROUND_EDGE_HEIGHT * _unit)
	_fit_label(_sun, SUN_SIZE)
	_place(_sun, screen * SUN_CENTER_RATIO)
	_fit_runner()
	_build_flowers(screen)
	for obstacle: Obstacle in _obstacle_labels:
		_fit_obstacle(obstacle, _obstacle_labels[obstacle])
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


func _build_flowers(screen: Vector2) -> void:
	for flower in _flowers.get_children():
		flower.queue_free()
	var gap := FLOWER_GAP * _unit
	var flower_y := _ground_y + (screen.y - _ground_y) * 0.5
	for i in ceili(screen.x / gap) + 2:
		var flower := Label.new()
		flower.text = "🌼"
		_flowers.add_child(flower)
		_fit_label(flower, FLOWER_SIZE)
		_place(flower, Vector2(i * gap, flower_y))


func _fit_obstacle(obstacle: Obstacle, label: Label) -> void:
	_fit_label(label, obstacle.size * OBSTACLE_GLYPH_RATIO)
	var center_y := _ground_y - obstacle.size * OBSTACLE_CENTER_RATIO * _unit
	_place(label, Vector2(obstacle.x * _unit, center_y))


func _fit_label(label: Label, size_in_units: float) -> void:
	label.add_theme_font_size_override("font_size", maxi(1, int(size_in_units * _unit)))
	label.reset_size()
	label.pivot_offset = label.size * 0.5


func _place(label: Label, center: Vector2) -> void:
	label.position = center - label.size * 0.5
