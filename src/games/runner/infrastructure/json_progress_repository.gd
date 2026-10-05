class_name JsonProgressRepository
extends ProgressRepository

## Stores Runner progress in user:// (IndexedDB on Web, app data folder elsewhere).
## The file is user-editable, so it is untrusted input: read as plain JSON (JsonFile) and validated by
## ProgressCodec. Anything invalid falls back to safe defaults.

const DEFAULT_PATH := "user://runner_save.json"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## A file from a newer app loads fresh and stays untouched until the next save.
func load_progress() -> Progress:
	var progress := ProgressCodec.from_dictionary(JsonFile.read(_path))
	return progress if progress != null else Progress.fresh()


func save_progress(progress: Progress) -> void:
	var error := JsonFile.write(_path, ProgressCodec.to_dictionary(progress))
	if error != OK:
		push_warning("Runner progress not saved: %s" % error_string(error))
