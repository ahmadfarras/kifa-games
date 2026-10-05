extends GutTest

const FakeProgressRepository := preload("res://tests/unit/games/runner/fake_progress_repository.gd")
const FakeProgressCloud := preload("res://tests/unit/games/runner/fake_progress_cloud.gd")

var repository: FakeProgressRepository
var cloud: FakeProgressCloud
var sync: ProgressSync


func before_each() -> void:
	repository = FakeProgressRepository.new()
	cloud = FakeProgressCloud.new()
	sync = ProgressSync.new(repository, cloud)


func test_first_sync_pushes_device_progress() -> void:
	var progress := Progress.restore(5, 9, [])

	var result: ProgressCloud.Result = await sync.sync(progress)

	assert_eq(result, ProgressCloud.Result.OK)
	assert_true(cloud.remote.equals(progress))
	assert_eq(repository.save_count, 0, "device progress did not change")


func test_cloud_ahead_updates_and_saves_device() -> void:
	cloud.remote = Progress.restore(40, 100, [&"cat"])
	var progress := Progress.fresh()

	await sync.sync(progress)

	assert_true(progress.equals(cloud.remote))
	assert_eq(repository.save_count, 1)
	assert_eq(repository.stored, progress)
	assert_eq(cloud.push_count, 0, "cloud already has the merged progress")


func test_device_ahead_pushes_without_saving() -> void:
	cloud.remote = Progress.restore(5, 9, [])
	var progress := Progress.restore(40, 100, [&"cat"])

	await sync.sync(progress)

	assert_true(cloud.remote.equals(progress))
	assert_eq(repository.save_count, 0)
	assert_eq(cloud.push_count, 1)


func test_both_changed_merges_saves_and_pushes() -> void:
	cloud.remote = Progress.restore(40, 100, [&"cat"])
	var progress := Progress.restore(90, 600, [])

	await sync.sync(progress)

	assert_true(progress.equals(Progress.restore(90, 100, [&"cat"])))
	assert_eq(repository.save_count, 1)
	assert_true(cloud.remote.equals(progress))


func test_equal_progress_does_nothing() -> void:
	cloud.remote = Progress.restore(5, 9, [])

	var result: ProgressCloud.Result = await sync.sync(Progress.restore(5, 9, []))

	assert_eq(result, ProgressCloud.Result.OK)
	assert_eq(repository.save_count, 0)
	assert_eq(cloud.push_count, 0)


func test_failed_pull_keeps_device_progress_and_does_not_push() -> void:
	for failure: ProgressCloud.Result in [
		ProgressCloud.Result.OFFLINE, ProgressCloud.Result.NOT_SIGNED_IN, ProgressCloud.Result.FAILED,
	]:
		cloud.pull_result = failure
		var progress := Progress.restore(5, 9, [])

		assert_eq(await sync.sync(progress), failure)
		assert_true(progress.equals(Progress.restore(5, 9, [])))
	assert_eq(cloud.push_count, 0)
	assert_eq(repository.save_count, 0)


func test_failed_push_is_reported_and_device_keeps_merged_progress() -> void:
	cloud.remote = Progress.restore(40, 0, [])
	cloud.push_result = ProgressCloud.Result.OFFLINE
	var progress := Progress.restore(5, 9, [])

	assert_eq(await sync.sync(progress), ProgressCloud.Result.OFFLINE)
	assert_eq(progress.best_score, 40)
	assert_eq(repository.save_count, 1)


func test_emits_finished_with_result() -> void:
	watch_signals(sync)

	await sync.sync(Progress.fresh())

	assert_signal_emitted_with_parameters(sync, "finished", [ProgressCloud.Result.OK])


func test_second_sync_waits_for_the_first() -> void:
	cloud.hold = true
	var progress := Progress.restore(5, 9, [])
	sync.sync(progress)
	sync.sync(progress)

	assert_eq(cloud.pull_count, 1, "second sync has not started")
	cloud.release()

	assert_eq(cloud.pull_count, 2)
	assert_eq(cloud.push_count, 1, "second sync finds the cloud up to date")


func test_emits_merged_only_when_the_device_progress_changed() -> void:
	watch_signals(sync)
	var progress := Progress.restore(5, 9, [])

	await sync.sync(progress)
	assert_signal_not_emitted(sync, "merged")
	cloud.remote = Progress.restore(40, 9, [])
	await sync.sync(progress)

	assert_signal_emit_count(sync, "merged", 1)
