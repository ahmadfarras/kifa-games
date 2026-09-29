class_name JsonBestScoreRepository
extends BestScoreRepository

## Stores the best score in user:// (IndexedDB on Web, app data folder elsewhere).
## The file is user-editable, so it is untrusted input: stored as plain JSON (ConfigFile would instantiate
## Objects written in the file) and validated on load. Anything invalid falls back to 0.

const DEFAULT_PATH := "user://runner_save.json"
const KEY := "best_score"
const MAX_SCORE := 1_000_000_000

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func load_best() -> int:
	if not FileAccess.file_exists(_path):
		return 0
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(_path)) != OK:
		return 0
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return 0
	return _valid_score(data.get(KEY))


func save_best(score: int) -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		push_warning("Best score not saved: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({KEY: score}))


static func _valid_score(value: Variant) -> int:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return 0
	if value < 0 or value > MAX_SCORE or value != floorf(value):
		return 0
	return int(value)
