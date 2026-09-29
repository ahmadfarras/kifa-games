extends GutTest

const TEST_PATH := "user://test_runner_best.cfg"

var repository: ConfigFileBestScoreRepository


func before_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	repository = ConfigFileBestScoreRepository.new(TEST_PATH)


func after_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)


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

	assert_eq(ConfigFileBestScoreRepository.new(TEST_PATH).load_best(), 7)


func test_default_path_is_user_dir() -> void:
	assert_true(ConfigFileBestScoreRepository.DEFAULT_PATH.begins_with("user://"))
