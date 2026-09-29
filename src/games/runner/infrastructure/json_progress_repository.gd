class_name JsonProgressRepository
extends ProgressRepository

## Stores Runner progress in user:// (IndexedDB on Web, app data folder elsewhere).
## The file is user-editable, so it is untrusted input: stored as plain JSON (ConfigFile would instantiate
## Objects written in the file) and validated on load. Anything invalid falls back to safe defaults.
## Format v2: {"version": 2, "best_score": 42, "coins": 310, "owned": ["little_girl", "little_boy"]}.
## A v1 file ({"best_score": N}) loads with 0 coins and the free characters.

const DEFAULT_PATH := "user://runner_save.json"
const VERSION := 2
const MAX_SCORE := 1_000_000_000
const TMP_SUFFIX := ".tmp"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func load_progress() -> Progress:
	var data: Variant = _read_json()
	if typeof(data) != TYPE_DICTIONARY:
		return Progress.fresh()
	# A newer app wrote this file: start fresh without touching it until the next save.
	if _valid_whole(data.get("version"), MAX_SCORE) > VERSION:
		return Progress.fresh()
	return Progress.restore(
		_valid_whole(data.get("best_score"), MAX_SCORE),
		_valid_whole(data.get("coins"), Progress.MAX_COINS),
		_valid_ids(data.get("owned")),
	)


## Writes a temporary file and renames it over the save, so an interrupted save keeps the old file.
func save_progress(progress: Progress) -> void:
	var tmp_path := _path + TMP_SUFFIX
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Runner progress not saved: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(_to_dictionary(progress)))
	file.close()
	var error := DirAccess.rename_absolute(tmp_path, _path)
	if error != OK:
		push_warning("Runner progress not saved: %s" % error_string(error))


func _read_json() -> Variant:
	if not FileAccess.file_exists(_path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(_path)) != OK:
		return null
	return json.data


static func _to_dictionary(progress: Progress) -> Dictionary:
	var owned: Array[String] = []
	for id in CharacterCatalog.ids():
		if progress.owns(id):
			owned.append(String(id))
	return {"version": VERSION, "best_score": progress.best_score, "coins": progress.coins, "owned": owned}


## Keeps only strings; the entry cap bounds the work on a tampered file.
static func _valid_ids(value: Variant) -> Array[StringName]:
	var ids: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY:
		return ids
	var entries: Array = value
	for i in mini(entries.size(), CharacterCatalog.ids().size() * 2):
		if typeof(entries[i]) == TYPE_STRING:
			ids.append(StringName(entries[i]))
	return ids


static func _valid_whole(value: Variant, max_value: int) -> int:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return 0
	if value < 0 or value > max_value or value != floorf(value):
		return 0
	return int(value)
