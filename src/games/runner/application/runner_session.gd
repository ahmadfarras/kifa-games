class_name RunnerSession
extends RefCounted

## Use cases for the Runner game: start a run, jump, advance time, earn coins and buy characters.
## Progress is saved only when a run ends or a purchase succeeds.

signal run_ended(score: int, best_score: int, coins_earned: int)
signal progress_changed

var run: Run
var progress: Progress
var best_score: int:
	get:
		return progress.best_score

var _repository: ProgressRepository
var _rng: RandomNumberGenerator


func _init(repository: ProgressRepository, rng: RandomNumberGenerator) -> void:
	_repository = repository
	_rng = rng
	progress = repository.load_progress()


func start_run(world_width: float, obstacle_footprints: Array[Vector2]) -> Run:
	run = Run.new(world_width, _rng, obstacle_footprints)
	run.crashed.connect(_on_crashed)
	return run


func resize_world(world_width: float) -> void:
	if run != null:
		run.resize(world_width)


func is_running() -> bool:
	return run != null and not run.is_over


func jump() -> bool:
	return is_running() and run.jump()


func tick(delta: float) -> void:
	if is_running():
		run.tick(delta)


func owns(id: StringName) -> bool:
	return progress.owns(id)


func coins() -> int:
	return progress.coins


## Tells the screens to redraw after a sync merged another device's progress into this one.
func refresh_from_sync() -> void:
	progress_changed.emit()


func buy(id: StringName) -> Progress.Purchase:
	var result := progress.buy(id)
	if result == Progress.Purchase.BOUGHT:
		_repository.save_progress(progress)
		progress_changed.emit()
	return result


func _on_crashed() -> void:
	var earned := progress.record_run(run.score)
	_repository.save_progress(progress)
	run_ended.emit(run.score, progress.best_score, earned)
