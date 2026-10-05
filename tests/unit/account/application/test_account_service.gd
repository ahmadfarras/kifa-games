extends GutTest

const FakeAuthGateway := preload("res://tests/unit/account/fake_auth_gateway.gd")
const FakeAccountStore := preload("res://tests/unit/account/fake_account_store.gd")

const NAME := "HappyCat27"
const PASSWORD := "password1"

var gateway: FakeAuthGateway
var store: FakeAccountStore
var service: AccountService
var now := 1000.0


func before_each() -> void:
	now = 1000.0
	gateway = FakeAuthGateway.new()
	store = FakeAccountStore.new()
	service = AccountService.new(gateway, store, _clock)


func _clock() -> float:
	return now


func _registered() -> void:
	await service.register(NAME, PASSWORD)


func test_starts_as_guest() -> void:
	assert_false(service.is_signed_in())
	assert_eq(service.username(), "")
	assert_eq(service.uid(), "")
	assert_eq(await service.id_token(), "")
	assert_eq(gateway.calls, 0)


func test_restores_a_stored_session() -> void:
	store.stored = AccountSession.new("uid-happycat27", NAME, "refresh-happycat27-1")

	service = AccountService.new(gateway, store, _clock)

	assert_true(service.is_signed_in())
	assert_eq(service.username(), NAME)
	assert_eq(service.uid(), "uid-happycat27")


func test_register_signs_in_and_stores_the_session() -> void:
	watch_signals(service)

	var status: AuthGateway.Status = await service.register(NAME, PASSWORD)

	assert_eq(status, AuthGateway.Status.OK)
	assert_true(service.is_signed_in())
	assert_eq(service.username(), NAME)
	assert_eq(store.stored.username, NAME)
	assert_eq(store.stored.uid, "uid-happycat27")
	assert_signal_emitted_with_parameters(service, "signed_in", [NAME])


func test_register_taken_username_stays_guest() -> void:
	gateway.passwords["happycat27"] = "someone else"
	watch_signals(service)

	assert_eq(await service.register(NAME, PASSWORD), AuthGateway.Status.USERNAME_TAKEN)
	assert_false(service.is_signed_in())
	assert_null(store.stored)
	assert_signal_not_emitted(service, "signed_in")


func test_register_rejects_weak_password_without_calling_the_server() -> void:
	for password in ["", "short", "a".repeat(Password.MAX_LENGTH + 1)]:
		assert_eq(await service.register(NAME, password), AuthGateway.Status.WEAK_PASSWORD, password)
	assert_eq(gateway.calls, 0)


func test_register_rejects_a_username_that_was_not_generated() -> void:
	assert_eq(await service.register("Budi", PASSWORD), AuthGateway.Status.UNKNOWN)
	assert_eq(gateway.calls, 0)


func test_log_in_with_typed_lower_case_username() -> void:
	gateway.passwords["happycat27"] = PASSWORD

	assert_eq(await service.log_in(" happycat27 ", PASSWORD), AuthGateway.Status.OK)
	assert_eq(service.username(), NAME)


func test_log_in_wrong_password() -> void:
	gateway.passwords["happycat27"] = PASSWORD

	assert_eq(await service.log_in(NAME, "password2"), AuthGateway.Status.WRONG_CREDENTIALS)
	assert_false(service.is_signed_in())


func test_log_in_refuses_impossible_input_without_calling_the_server() -> void:
	for attempt: Array in [["Budi", PASSWORD], ["' OR 1=1 --", PASSWORD], [NAME, "short"], ["", ""]]:
		assert_eq(await service.log_in(attempt[0], attempt[1]), AuthGateway.Status.WRONG_CREDENTIALS)
	assert_eq(gateway.calls, 0)


func test_log_in_reports_gateway_failures() -> void:
	for failure: AuthGateway.Status in [
		AuthGateway.Status.OFFLINE, AuthGateway.Status.TOO_MANY_ATTEMPTS, AuthGateway.Status.UNKNOWN,
	]:
		gateway.failure = failure

		assert_eq(await service.log_in(NAME, PASSWORD), failure)
		assert_false(service.is_signed_in())


func test_log_out_clears_the_session() -> void:
	await _registered()
	watch_signals(service)

	service.log_out()

	assert_false(service.is_signed_in())
	assert_null(store.stored)
	assert_eq(await service.id_token(), "")
	assert_signal_emitted(service, "signed_out")


func test_log_out_as_guest_does_nothing() -> void:
	watch_signals(service)

	service.log_out()

	assert_signal_not_emitted(service, "signed_out")


func test_id_token_is_reused_while_fresh() -> void:
	await _registered()
	now += gateway.expires_in - AccountService.REFRESH_MARGIN - 1.0

	assert_eq(await service.id_token(), "id-1")
	assert_eq(gateway.refresh_count, 0)


func test_id_token_refreshes_near_expiry_and_stores_the_new_refresh_token() -> void:
	await _registered()
	now += gateway.expires_in - AccountService.REFRESH_MARGIN

	assert_eq(await service.id_token(), "id-2")
	assert_eq(gateway.refresh_count, 1)
	assert_eq(store.stored.refresh_token, "refresh-happycat27-2")
	assert_eq(service.username(), NAME)


func test_restored_session_refreshes_on_first_use() -> void:
	store.stored = AccountSession.new("uid-happycat27", NAME, "refresh-happycat27-1")
	service = AccountService.new(gateway, store, _clock)

	assert_eq(await service.id_token(), "id-1")
	assert_eq(gateway.refresh_count, 1)


func test_offline_refresh_keeps_the_login() -> void:
	await _registered()
	now += gateway.expires_in
	gateway.failure = AuthGateway.Status.OFFLINE

	assert_eq(await service.id_token(), "")
	assert_true(service.is_signed_in())
	assert_not_null(store.stored)


func test_expired_session_logs_out() -> void:
	await _registered()
	now += gateway.expires_in
	gateway.failure = AuthGateway.Status.SESSION_EXPIRED
	watch_signals(service)

	assert_eq(await service.id_token(), "")
	assert_false(service.is_signed_in())
	assert_null(store.stored)
	assert_signal_emitted(service, "signed_out")


func test_confirm_password_accepts_the_right_password_quietly() -> void:
	await _registered()
	watch_signals(service)

	assert_eq(await service.confirm_password(PASSWORD), AuthGateway.Status.OK)
	assert_eq(await service.id_token(), "id-2", "a fresh token for the delete that follows")
	assert_signal_not_emitted(service, "signed_in")


func test_confirm_password_rejects_a_wrong_password_and_keeps_the_login() -> void:
	await _registered()

	assert_eq(await service.confirm_password("password2"), AuthGateway.Status.WRONG_CREDENTIALS)
	assert_eq(await service.confirm_password("short"), AuthGateway.Status.WRONG_CREDENTIALS)
	assert_true(service.is_signed_in())


func test_confirm_password_as_guest() -> void:
	assert_eq(await service.confirm_password(PASSWORD), AuthGateway.Status.SESSION_EXPIRED)
	assert_eq(gateway.calls, 0)


func test_delete_account_deletes_and_logs_out() -> void:
	await _registered()

	assert_eq(await service.delete_account(), AuthGateway.Status.OK)
	assert_eq(gateway.deleted_tokens, ["id-1"] as Array[String])
	assert_false(service.is_signed_in())
	assert_null(store.stored)


func test_failed_delete_keeps_the_login() -> void:
	await _registered()
	gateway.failure = AuthGateway.Status.OFFLINE

	assert_eq(await service.delete_account(), AuthGateway.Status.OFFLINE)
	assert_true(service.is_signed_in())


func test_delete_account_as_guest() -> void:
	assert_eq(await service.delete_account(), AuthGateway.Status.SESSION_EXPIRED)
	assert_eq(gateway.calls, 0)
