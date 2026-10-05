extends GutTest

const TEST_PATH := "user://test_runner_save.json"
const TMP_PATH := TEST_PATH + JsonFile.TMP_SUFFIX

var repository: JsonProgressRepository


func before_each() -> void:
	_clean()
	repository = JsonProgressRepository.new(TEST_PATH)


func after_each() -> void:
	_clean()


func _clean() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	DirAccess.remove_absolute(TMP_PATH)


func _write_file(content: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _read_file() -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))


func _progress(best: int, coins: int, owned: Array[StringName] = []) -> Progress:
	return Progress.restore(best, coins, owned)


func _assert_fresh(progress: Progress, context := "") -> void:
	assert_eq(progress.best_score, 0, context)
	assert_eq(progress.coins, 0, context)
	assert_eq(progress.owned, Progress.fresh().owned, context)


func test_default_path_is_user_dir() -> void:
	assert_eq(JsonProgressRepository.DEFAULT_PATH, "user://runner_save.json")


func test_load_without_file_is_fresh() -> void:
	_assert_fresh(repository.load_progress())


func test_round_trip() -> void:
	repository.save_progress(_progress(42, 310, [&"cat"]))

	var loaded := JsonProgressRepository.new(TEST_PATH).load_progress()

	assert_eq(loaded.best_score, 42)
	assert_eq(loaded.coins, 310)
	assert_eq(loaded.owned, {&"little_girl": true, &"little_boy": true, &"cat": true})


func test_save_overwrites_previous_progress() -> void:
	repository.save_progress(_progress(12, 5))

	repository.save_progress(_progress(30, 7))

	assert_eq(repository.load_progress().best_score, 30)
	assert_eq(repository.load_progress().coins, 7)


func test_saves_plain_json_v2() -> void:
	repository.save_progress(_progress(42, 310))

	assert_eq(_read_file(), {
		"version": 2.0, "best_score": 42.0, "coins": 310.0, "owned": ["little_girl", "little_boy"],
	})


func test_corrupt_json_loads_fresh() -> void:
	for content in ["{not json", "", "[1, 2, 3]", "42", '"text"', "null"]:
		_write_file(content)
		_assert_fresh(repository.load_progress(), content)


func test_godot_object_syntax_is_not_instantiated() -> void:
	_write_file('{"version": 2, "coins": Object(RefCounted,"script":null), "owned": [Object(RefCounted,"script":null)]}')

	_assert_fresh(repository.load_progress())


func test_wrong_number_types_load_zero() -> void:
	for value in ['"99"', "true", "null", "[5]", "{}"]:
		_write_file('{"version": 2, "best_score": %s, "coins": %s}' % [value, value])
		_assert_fresh(repository.load_progress(), value)


func test_invalid_numbers_load_zero() -> void:
	for value in ["-4", "4.5", "1e20"]:
		_write_file('{"version": 2, "best_score": %s, "coins": %s}' % [value, value])
		_assert_fresh(repository.load_progress(), value)


func test_max_values_are_accepted() -> void:
	_write_file('{"version": 2, "best_score": %d, "coins": %d}' % [ProgressCodec.MAX_SCORE, Progress.MAX_COINS])

	var loaded := repository.load_progress()

	assert_eq(loaded.best_score, ProgressCodec.MAX_SCORE)
	assert_eq(loaded.coins, Progress.MAX_COINS)


func test_owned_not_an_array_keeps_free_characters() -> void:
	for value in ['"cat"', "5", "null", '{"cat": true}']:
		_write_file('{"version": 2, "owned": %s}' % value)
		_assert_fresh(repository.load_progress(), value)


func test_owned_drops_unknown_ids_and_non_strings() -> void:
	_write_file('{"version": 2, "owned": ["dragon", 5, null, ["cat"], "cat"]}')

	var loaded := repository.load_progress()

	assert_eq(loaded.owned, {&"little_girl": true, &"little_boy": true, &"cat": true})


func test_owned_duplicates_are_merged() -> void:
	_write_file('{"version": 2, "owned": ["cat", "cat", "little_boy"]}')

	assert_eq(repository.load_progress().owned.size(), 3)


func test_owned_without_free_ids_adds_them() -> void:
	_write_file('{"version": 2, "owned": ["cat"]}')

	var loaded := repository.load_progress()

	for id in CharacterCatalog.free_ids():
		assert_true(loaded.owns(id), id)


func test_oversized_owned_array_is_capped() -> void:
	var junk: Array = []
	junk.resize(CharacterCatalog.ids().size() * 2)
	junk.fill("dragon")
	junk.append("cat")
	_write_file(JSON.stringify({"version": 2, "owned": junk}))

	assert_false(repository.load_progress().owns(&"cat"))


func test_v1_file_migrates_best_score() -> void:
	_write_file('{"best_score": 42}')

	var loaded := repository.load_progress()

	assert_eq(loaded.best_score, 42)
	assert_eq(loaded.coins, 0)
	assert_eq(loaded.owned, Progress.fresh().owned)


func test_v1_file_is_saved_as_v2() -> void:
	_write_file('{"best_score": 42}')

	repository.save_progress(repository.load_progress())

	assert_eq(_read_file().version, 2.0)
	assert_eq(_read_file().best_score, 42.0)


func test_future_version_loads_fresh_and_keeps_file() -> void:
	var content := '{"version": 3, "best_score": 42, "coins": 9}'
	_write_file(content)

	_assert_fresh(repository.load_progress())
	assert_eq(FileAccess.get_file_as_string(TEST_PATH), content)


func test_save_leaves_no_tmp_file() -> void:
	repository.save_progress(_progress(1, 2))

	assert_true(FileAccess.file_exists(TEST_PATH))
	assert_false(FileAccess.file_exists(TMP_PATH))


func test_failed_save_keeps_previous_file() -> void:
	repository.save_progress(_progress(12, 5))
	# A directory where the temporary file should go makes the write fail.
	DirAccess.make_dir_absolute(TMP_PATH)

	repository.save_progress(_progress(99, 99))

	assert_eq(repository.load_progress().best_score, 12)
	assert_eq(repository.load_progress().coins, 5)


func test_save_to_unwritable_path_does_not_crash() -> void:
	var broken := JsonProgressRepository.new("user://missing_dir/sub/save.json")

	broken.save_progress(_progress(3, 3))

	_assert_fresh(broken.load_progress())
