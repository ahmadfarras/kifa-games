extends GutTest

const FakeAuthGateway := preload("res://tests/unit/account/fake_auth_gateway.gd")
const FakeAccountStore := preload("res://tests/unit/account/fake_account_store.gd")


func test_session_holds_its_fields() -> void:
	var session := AccountSession.new("uid-1", "HappyCat27", "refresh-1")

	assert_eq(session.uid, "uid-1")
	assert_eq(session.username, "HappyCat27")
	assert_eq(session.refresh_token, "refresh-1")


func test_tokens_default_to_empty() -> void:
	var tokens := AuthGateway.Tokens.new(AuthGateway.Status.OFFLINE)

	assert_eq(tokens.status, AuthGateway.Status.OFFLINE)
	assert_eq(tokens.uid, "")
	assert_eq(tokens.id_token, "")
	assert_eq(tokens.refresh_token, "")
	assert_eq(tokens.expires_in, 0.0)


func test_fake_gateway_implements_port() -> void:
	var gateway: AuthGateway = FakeAuthGateway.new()

	var created: AuthGateway.Tokens = await gateway.sign_up("HappyCat27", "password1")
	var again: AuthGateway.Tokens = await gateway.sign_up("happycat27", "password2")
	var wrong: AuthGateway.Tokens = await gateway.sign_in("HappyCat27", "password2")
	var refreshed: AuthGateway.Tokens = await gateway.refresh(created.refresh_token)

	assert_eq(created.status, AuthGateway.Status.OK)
	assert_eq(again.status, AuthGateway.Status.USERNAME_TAKEN)
	assert_eq(wrong.status, AuthGateway.Status.WRONG_CREDENTIALS)
	assert_eq(refreshed.uid, created.uid)
	assert_eq(await gateway.delete_account(created.id_token), AuthGateway.Status.OK)


func test_fake_store_implements_port() -> void:
	var store: AccountStore = FakeAccountStore.new()
	var session := AccountSession.new("uid-1", "HappyCat27", "refresh-1")

	assert_null(store.load_session())
	store.save_session(session)
	assert_eq(store.load_session(), session)
	store.clear()
	assert_null(store.load_session())
