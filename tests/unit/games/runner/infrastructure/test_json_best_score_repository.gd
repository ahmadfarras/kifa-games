extends GutTest

const TEST_PATH := "user://test_runner_save.json"

var repository: JsonBestScoreRepository


func before_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	repository = JsonBestScoreRepository.new(TEST_PATH)


func after_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)


func _write_file(content: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func test_load_best_is_zero_without_file() -> void:
	assert_eq(repository.load_best(), 0)


func test_save_then_load_returns_score() -> void:
	repository.save_best(12)

	assert_eq(repository.load_best(), 12)


func test_save_overwrites_previous_score() -> void:
	repository.save_best(12)

	repository.save_best(30)

	assert_eq(repository.load_best(), 30)


func test_new_instance_reads_saved_score() -> void:
	repository.save_best(7)

	assert_eq(JsonBestScoreRepository.new(TEST_PATH).load_best(), 7)


func test_saves_plain_json() -> void:
	repository.save_best(5)

	assert_eq(JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH)), {"best_score": 5.0})


func test_default_path_is_user_dir() -> void:
	assert_true(JsonBestScoreRepository.DEFAULT_PATH.begins_with("user://"))


func test_save_to_unwritable_path_does_not_crash() -> void:
	var broken := JsonBestScoreRepository.new("user://missing_dir/sub/save.json")

	broken.save_best(3)

	assert_eq(broken.load_best(), 0)


func test_corrupt_json_loads_zero() -> void:
	_write_file("{not json")

	assert_eq(repository.load_best(), 0)


func test_empty_file_loads_zero() -> void:
	_write_file("")

	assert_eq(repository.load_best(), 0)


func test_non_object_json_loads_zero() -> void:
	_write_file("[1, 2, 3]")

	assert_eq(repository.load_best(), 0)


func test_missing_key_loads_zero() -> void:
	_write_file('{"other": 5}')

	assert_eq(repository.load_best(), 0)


func test_godot_object_syntax_is_not_instantiated() -> void:
	_write_file('{"best_score": Object(RefCounted,"script":null)}')

	assert_eq(repository.load_best(), 0)


func test_wrong_types_load_zero() -> void:
	for content in ['{"best_score": "99"}', '{"best_score": true}', '{"best_score": null}', '{"best_score": [5]}']:
		_write_file(content)
		assert_eq(repository.load_best(), 0, content)


func test_negative_score_loads_zero() -> void:
	_write_file('{"best_score": -4}')

	assert_eq(repository.load_best(), 0)


func test_fractional_score_loads_zero() -> void:
	_write_file('{"best_score": 4.5}')

	assert_eq(repository.load_best(), 0)


func test_huge_score_loads_zero() -> void:
	_write_file('{"best_score": 1e20}')

	assert_eq(repository.load_best(), 0)


func test_max_score_is_accepted() -> void:
	_write_file('{"best_score": %d}' % JsonBestScoreRepository.MAX_SCORE)

	assert_eq(repository.load_best(), JsonBestScoreRepository.MAX_SCORE)
