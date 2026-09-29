extends ProgressRepository

## In-memory ProgressRepository for tests; counts saves.

var stored := Progress.fresh()
var save_count := 0


func load_progress() -> Progress:
	return stored


func save_progress(progress: Progress) -> void:
	stored = progress
	save_count += 1
