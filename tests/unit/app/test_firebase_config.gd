extends GutTest

const PATH := "user://test_firebase.env"


func after_each() -> void:
	DirAccess.remove_absolute(PATH)


func _write(content: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func test_reads_project_id_and_api_key() -> void:
	_write("FIREBASE_PROJECT_ID=my-project\nFIREBASE_API_KEY=abc123\n")

	var config := FirebaseConfig.new(PATH)

	assert_eq(config.project_id, "my-project")
	assert_eq(config.api_key, "abc123")


func test_missing_file_gives_empty_values() -> void:
	var config := FirebaseConfig.new("user://no_such_file.env")

	assert_eq(config.project_id, "")
	assert_eq(config.api_key, "")


func test_missing_entries_give_empty_values() -> void:
	_write("FIREBASE_PROJECT_ID=my-project\n")

	assert_eq(FirebaseConfig.new(PATH).api_key, "")


func test_parse_skips_comments_blank_lines_and_junk() -> void:
	var values := FirebaseConfig.parse("# a comment\n\n  A = 1  \r\nnot a pair\n=no name\nB=x=y\n#C=3\n")

	assert_eq(values, {"A": "1", "B": "x=y"} as Dictionary[String, String])


func test_parse_of_empty_text_is_empty() -> void:
	assert_eq(FirebaseConfig.parse("").size(), 0)


func test_example_file_has_both_names_and_no_real_key() -> void:
	var values := FirebaseConfig.parse(FileAccess.get_file_as_string("res://firebase.env.example"))

	assert_true(values.has(FirebaseConfig.PROJECT_ID_KEY))
	assert_true(values.has(FirebaseConfig.API_KEY_KEY))
	assert_false(values[FirebaseConfig.API_KEY_KEY].begins_with("AIza"), "the example must never hold a real key")


func test_export_packs_the_env_file() -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")

	assert_string_contains(presets, 'include_filter="firebase.env"')
