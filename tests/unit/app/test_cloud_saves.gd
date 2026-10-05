extends GutTest

const FakeServices := preload("res://tests/unit/app/fake_services.gd")

const FOOTPRINTS: Array[Vector2] = [Vector2(0.1, 0.1)]

var services: FakeServices
var cloud_saves: CloudSaves


func before_each() -> void:
	_build(true)


func _build(signed_in: bool) -> void:
	services = FakeServices.new(signed_in)
	cloud_saves = services.cloud_saves


func _session() -> RunnerSession:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var session := RunnerSession.new(services.repository, rng)
	cloud_saves.watch(session)
	return session


func _end_run(session: RunnerSession, score: int) -> void:
	session.start_run(1.8, FOOTPRINTS)
	session.run.score = score
	session.run.obstacles.append(Obstacle.new(session.run.runner_x(), FOOTPRINTS[0], 0))
	session.run.elapsed = score / Run.SCORE_PER_SECOND
	session.tick(0.01)


func test_guest_never_calls_the_cloud() -> void:
	_build(false)
	var session := _session()

	assert_eq(await cloud_saves.sync_device(), ProgressCloud.Result.NOT_SIGNED_IN)
	_end_run(session, 5)
	cloud_saves.unwatch()

	assert_eq(services.cloud.pull_count, 0)
	assert_eq(services.gateway.calls, 0)


func test_sync_device_merges_the_cloud_save_into_the_device() -> void:
	services.cloud.remote = Progress.restore(40, 100, [&"cat"])

	assert_eq(await cloud_saves.sync_device(), ProgressCloud.Result.OK)
	assert_true(services.repository.stored.equals(Progress.restore(40, 100, [&"cat"])))


func test_logging_in_syncs_guest_progress_into_the_account() -> void:
	_build(false)
	services.gateway.passwords["happycat27"] = FakeServices.PASSWORD
	services.repository.stored = Progress.restore(12, 30, [])
	services.cloud.remote = Progress.restore(40, 0, [])

	await services.account.log_in(FakeServices.USERNAME, FakeServices.PASSWORD)

	assert_true(services.cloud.remote.equals(Progress.restore(40, 30, [])))
	assert_true(services.repository.stored.equals(Progress.restore(40, 30, [])))


func test_purchase_syncs_at_once() -> void:
	services.repository.stored = Progress.restore(0, 600, [])
	var session := _session()

	session.buy(&"cat")

	assert_true(services.cloud.remote.owns(&"cat"))
	assert_eq(services.cloud.remote.coins, 100)


func test_run_end_syncs_when_the_last_sync_is_old_enough() -> void:
	var session := _session()

	_end_run(session, 7)

	assert_eq(services.cloud.remote.best_score, 7)


func test_run_end_soon_after_a_sync_waits() -> void:
	var session := _session()
	_end_run(session, 7)
	services.now += CloudSaves.RUN_END_INTERVAL - 1.0

	_end_run(session, 9)

	assert_eq(services.cloud.pull_count, 1)
	assert_eq(services.cloud.remote.best_score, 7)
	assert_eq(services.repository.stored.best_score, 9, "still saved on the device")


func test_run_end_after_the_interval_syncs_again() -> void:
	var session := _session()
	_end_run(session, 7)
	services.now += CloudSaves.RUN_END_INTERVAL

	_end_run(session, 9)

	assert_eq(services.cloud.remote.best_score, 9)


func test_unwatch_syncs_and_stops_following_the_session() -> void:
	var session := _session()
	_end_run(session, 7)
	services.now += 1.0
	_end_run(session, 9)

	cloud_saves.unwatch()
	assert_eq(services.cloud.remote.best_score, 9)
	var pulls := services.cloud.pull_count
	session.buy(&"cat")
	cloud_saves.unwatch()

	assert_eq(services.cloud.pull_count, pulls)


func test_merge_during_a_session_redraws_without_syncing_twice() -> void:
	var session := _session()
	services.cloud.remote = Progress.restore(40, 100, [&"cat"])
	watch_signals(session)

	_end_run(session, 3)

	assert_true(session.owns(&"cat"))
	assert_signal_emit_count(session, "progress_changed", 1)
	assert_eq(services.cloud.pull_count, 1)


func test_log_out_syncs_then_resets_the_device() -> void:
	services.repository.stored = Progress.restore(12, 30, [&"cat"])

	assert_eq(await cloud_saves.log_out(), ProgressCloud.Result.OK)
	assert_true(services.cloud.remote.equals(Progress.restore(12, 30, [&"cat"])), "saved in the cloud first")
	assert_true(services.repository.stored.equals(Progress.fresh()))
	assert_false(services.account.is_signed_in())


func test_log_out_that_cannot_sync_changes_nothing() -> void:
	services.repository.stored = Progress.restore(12, 30, [])
	services.cloud.pull_result = ProgressCloud.Result.OFFLINE

	assert_eq(await cloud_saves.log_out(), ProgressCloud.Result.OFFLINE)
	assert_true(services.account.is_signed_in())
	assert_eq(services.repository.stored.coins, 30)


func test_log_out_discarding_unsaved_progress_skips_the_sync() -> void:
	services.repository.stored = Progress.restore(12, 30, [])
	services.cloud.pull_result = ProgressCloud.Result.OFFLINE

	assert_eq(await cloud_saves.log_out(true), ProgressCloud.Result.OK)
	assert_eq(services.cloud.pull_count, 0)
	assert_false(services.account.is_signed_in())
	assert_true(services.repository.stored.equals(Progress.fresh()))


func test_expired_session_keeps_the_progress_on_the_device() -> void:
	services.repository.stored = Progress.restore(12, 30, [])
	services.gateway.failure = AuthGateway.Status.SESSION_EXPIRED

	await services.account.id_token()

	assert_false(services.account.is_signed_in())
	assert_eq(services.repository.stored.coins, 30)


func test_delete_account_removes_cloud_saves_then_the_account_and_resets_the_device() -> void:
	services.repository.stored = Progress.restore(12, 30, [])
	services.http.reply(200, {})

	assert_eq(await cloud_saves.delete_account(FakeServices.PASSWORD), AuthGateway.Status.OK)
	assert_eq(services.http.requests.size(), CloudSaves.GAMES.size())
	assert_eq(services.http.last().method, HTTPClient.METHOD_DELETE)
	assert_true(services.http.last().url.ends_with("/saves/uidhappycat27/games/runner"))
	assert_eq(services.gateway.deleted_tokens.size(), 1)
	assert_false(services.account.is_signed_in())
	assert_true(services.repository.stored.equals(Progress.fresh()))


func test_delete_account_with_wrong_password_deletes_nothing() -> void:
	services.repository.stored = Progress.restore(12, 30, [])

	assert_eq(await cloud_saves.delete_account("password2"), AuthGateway.Status.WRONG_CREDENTIALS)
	assert_eq(services.http.requests.size(), 0)
	assert_eq(services.gateway.deleted_tokens.size(), 0)
	assert_true(services.account.is_signed_in())
	assert_eq(services.repository.stored.coins, 30)


func test_delete_account_stops_when_a_cloud_save_cannot_be_deleted() -> void:
	var expected: Dictionary[int, AuthGateway.Status] = {
		0: AuthGateway.Status.OFFLINE, 403: AuthGateway.Status.UNKNOWN, 500: AuthGateway.Status.UNKNOWN,
	}
	for http_status: int in expected:
		services.http.reply(http_status, {})

		assert_eq(await cloud_saves.delete_account(FakeServices.PASSWORD), expected[http_status], str(http_status))
	assert_eq(services.gateway.deleted_tokens.size(), 0)
	assert_true(services.account.is_signed_in())


func test_failed_account_deletion_keeps_the_login_and_progress() -> void:
	services.repository.stored = Progress.restore(12, 30, [])
	services.http.reply(200, {})
	await cloud_saves.delete_account("password2")
	services.gateway.failure = AuthGateway.Status.OK
	# The password check passes, then the server refuses the deletion itself.
	var status: AuthGateway.Status = await services.account.confirm_password(FakeServices.PASSWORD)
	services.gateway.failure = AuthGateway.Status.OFFLINE

	assert_eq(status, AuthGateway.Status.OK)
	assert_eq(await services.account.delete_account(), AuthGateway.Status.OFFLINE)
	assert_true(services.account.is_signed_in())
	assert_eq(services.repository.stored.coins, 30)
