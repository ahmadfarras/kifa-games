class_name JsonProgressRepository
extends ProgressRepository

## Stores Runner progress in user:// (IndexedDB on Web, app data folder elsewhere).
## The file is user-editable, so it is untrusted input: stored as plain JSON (ConfigFile would instantiate
## Objects written in the file) and validated by ProgressCodec. Anything invalid falls back to safe defaults.

const DEFAULT_PATH := "user://runner_save.json"
const TMP_SUFFIX := ".tmp"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## A file from a newer app loads fresh and stays untouched until the next save.
func load_progress() -> Progress:
	var progress := ProgressCodec.from_dictionary(_read_json())
	return progress if progress != null else Progress.fresh()


## Writes a temporary file and renames it over the save, so an interrupted save keeps the old file.
func save_progress(progress: Progress) -> void:
	var tmp_path := _path + TMP_SUFFIX
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Runner progress not saved: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(ProgressCodec.to_dictionary(progress)))
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
