extends GutTest

const FakeProgressCloud := preload("res://tests/unit/games/runner/fake_progress_cloud.gd")


func test_fake_implements_port() -> void:
	var cloud: ProgressCloud = FakeProgressCloud.new()

	assert_eq(await cloud.push(Progress.restore(5, 9, [])), ProgressCloud.Result.OK)
	var pull: ProgressCloud.Pull = await cloud.pull()

	assert_eq(pull.result, ProgressCloud.Result.OK)
	assert_true(pull.progress.equals(Progress.restore(5, 9, [])))


func test_pull_defaults_to_no_progress() -> void:
	var pull := ProgressCloud.Pull.new(ProgressCloud.Result.OFFLINE)

	assert_eq(pull.result, ProgressCloud.Result.OFFLINE)
	assert_null(pull.progress)
