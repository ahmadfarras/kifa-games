extends GutTest

const FakeJsonHttp := preload("res://tests/unit/shared/fake_json_http.gd")

var http: FakeJsonHttp
var cloud: FirestoreProgressCloud


func before_each() -> void:
	http = FakeJsonHttp.new()
	var documents := FirestoreDocuments.new(
		http, "test-project", func() -> String: return "id.jwt.token", func() -> String: return "uid1"
	)
	cloud = FirestoreProgressCloud.new(documents)


func _document(version: int, best: int, coins: int, owned: Array) -> Dictionary:
	var values: Array = owned.map(func(id: String) -> Dictionary: return {"stringValue": id})
	return {"fields": {
		"version": {"integerValue": str(version)}, "best_score": {"integerValue": str(best)},
		"coins": {"integerValue": str(coins)}, "owned": {"arrayValue": {"values": values}},
	}}


func test_pull_returns_the_cloud_save() -> void:
	http.reply(200, _document(2, 42, 310, ["little_girl", "little_boy", "cat"]))

	var pull: ProgressCloud.Pull = await cloud.pull()

	assert_eq(pull.result, ProgressCloud.Result.OK)
	assert_true(pull.progress.equals(Progress.restore(42, 310, [&"cat"])))
	assert_true(http.last().url.ends_with("/saves/uid1/games/runner"))


func test_pull_without_cloud_save_is_ok_with_no_progress() -> void:
	http.reply(404, {"error": {"status": "NOT_FOUND"}})

	var pull: ProgressCloud.Pull = await cloud.pull()

	assert_eq(pull.result, ProgressCloud.Result.OK)
	assert_null(pull.progress)


func test_pull_validates_like_a_save_file() -> void:
	http.reply(200, _document(2, -5, 2_000_000_000, ["dragon", "cat"]))

	var pull: ProgressCloud.Pull = await cloud.pull()

	assert_true(pull.progress.equals(Progress.restore(0, 0, [&"cat"])))


func test_pull_of_newer_version_fails_so_it_is_not_overwritten() -> void:
	http.reply(200, _document(3, 42, 310, []))

	var pull: ProgressCloud.Pull = await cloud.pull()

	assert_eq(pull.result, ProgressCloud.Result.FAILED)
	assert_null(pull.progress)


func test_pull_failures() -> void:
	var expected: Dictionary[int, ProgressCloud.Result] = {
		0: ProgressCloud.Result.OFFLINE, 401: ProgressCloud.Result.NOT_SIGNED_IN,
		403: ProgressCloud.Result.FAILED, 500: ProgressCloud.Result.FAILED,
	}
	for status: int in expected:
		http.reply(status, {})

		var pull: ProgressCloud.Pull = await cloud.pull()

		assert_eq(pull.result, expected[status], str(status))
		assert_null(pull.progress)


func test_push_writes_save_format_v2() -> void:
	http.reply(200, {})

	var result: ProgressCloud.Result = await cloud.push(Progress.restore(42, 310, [&"cat"]))

	assert_eq(result, ProgressCloud.Result.OK)
	assert_eq(http.last().method, HTTPClient.METHOD_PATCH)
	assert_eq(http.last_json(), _document(2, 42, 310, ["little_girl", "little_boy", "cat"]))


func test_push_failures() -> void:
	var expected: Dictionary[int, ProgressCloud.Result] = {
		0: ProgressCloud.Result.OFFLINE, 401: ProgressCloud.Result.NOT_SIGNED_IN, 403: ProgressCloud.Result.FAILED,
	}
	for status: int in expected:
		http.reply(status, {})

		assert_eq(await cloud.push(Progress.fresh()), expected[status], str(status))
