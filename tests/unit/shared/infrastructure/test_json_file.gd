extends GutTest

const PATH := "user://test_json_file.json"
const TMP_PATH := PATH + JsonFile.TMP_SUFFIX


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _clean() -> void:
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(TMP_PATH)


func _write_raw(content: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func test_read_missing_file_is_null() -> void:
	assert_null(JsonFile.read(PATH))


func test_round_trip() -> void:
	assert_eq(JsonFile.write(PATH, {"name": "cat", "list": [1, 2]}), OK)

	assert_eq(JsonFile.read(PATH), {"name": "cat", "list": [1.0, 2.0]})


func test_read_returns_any_json_value() -> void:
	_write_raw("[1, 2]")

	assert_eq(JsonFile.read(PATH), [1.0, 2.0])


func test_read_invalid_json_is_null() -> void:
	for content in ["{not json", "", 'Object(RefCounted,"script":null)']:
		_write_raw(content)
		assert_null(JsonFile.read(PATH), content)


func test_read_refuses_oversized_file() -> void:
	_write_raw('"%s"' % "a".repeat(JsonFile.MAX_BYTES))

	assert_null(JsonFile.read(PATH))


func test_write_leaves_no_tmp_file() -> void:
	JsonFile.write(PATH, {"a": 1})

	assert_true(FileAccess.file_exists(PATH))
	assert_false(FileAccess.file_exists(TMP_PATH))


func test_failed_write_reports_error_and_keeps_previous_file() -> void:
	JsonFile.write(PATH, {"a": 1})
	# A directory where the temporary file should go makes the write fail.
	DirAccess.make_dir_absolute(TMP_PATH)

	assert_ne(JsonFile.write(PATH, {"a": 2}), OK)
	assert_eq(JsonFile.read(PATH), {"a": 1.0})
