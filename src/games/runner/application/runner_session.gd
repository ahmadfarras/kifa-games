class_name RunnerSession
extends RefCounted

## Use cases for the Runner game: start a run, jump, advance time, record the best score.

signal run_ended(score: int, best_score: int)

var run: Run
var best_score: int

var _repository: BestScoreRepository
var _rng: RandomNumberGenerator


func _init(repository: BestScoreRepository, rng: RandomNumberGenerator) -> void:
	_repository = repository
	_rng = rng
	best_score = repository.load_best()


func start_run(world_width: float) -> Run:
	run = Run.new(world_width, _rng)
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


func _on_crashed() -> void:
	if run.score > best_score:
		best_score = run.score
		_repository.save_best(best_score)
	run_ended.emit(run.score, best_score)
