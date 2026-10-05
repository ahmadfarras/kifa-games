class_name JsonFile
extends RefCounted

## Reads and writes small JSON files in user://. Those files are editable by anyone with the device, so
## they are untrusted: plain JSON only (ConfigFile / str_to_var would instantiate Objects written in the
## file) and the caller validates what comes back.

const TMP_SUFFIX := ".tmp"
## Saves are a few hundred bytes; anything bigger is not one of ours.
const MAX_BYTES := 65_536


## Returns the parsed JSON, or null when the file is missing, too big or not JSON.
static func read(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data


## Writes a temporary file and renames it over the target, so an interrupted write keeps the old file.
static func write(path: String, data: Dictionary) -> Error:
	var tmp_path := path + TMP_SUFFIX
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.close()
	return DirAccess.rename_absolute(tmp_path, path)
