extends ProgressCloud

## In-memory ProgressCloud for tests. Set `hold` to keep a pull waiting until release() is called.

signal released

var remote: Progress
var pull_result := Result.OK
var push_result := Result.OK
var pull_count := 0
var push_count := 0
var hold := false


func pull() -> Pull:
	pull_count += 1
	if hold:
		await released
	return Pull.new(pull_result, remote if pull_result == Result.OK else null)


func push(progress: Progress) -> Result:
	push_count += 1
	if push_result == Result.OK:
		remote = Progress.restore(progress.best_score, progress.coins, progress.owned.keys())
	return push_result


func release() -> void:
	hold = false
	released.emit()
