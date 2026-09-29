class_name ConfigFileBestScoreRepository
extends BestScoreRepository

## Stores the best score in user:// (IndexedDB on Web, app data folder elsewhere).

const DEFAULT_PATH := "user://runner.cfg"
const SECTION := "runner"
const KEY := "best_score"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func load_best() -> int:
	var config := ConfigFile.new()
	if config.load(_path) != OK:
		return 0
	return int(config.get_value(SECTION, KEY, 0))


func save_best(score: int) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, KEY, score)
	config.save(_path)
