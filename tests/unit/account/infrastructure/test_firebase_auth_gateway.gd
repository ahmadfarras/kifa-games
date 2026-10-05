extends GutTest

## Replies are copied from the real Firebase REST API (spike of 2026-10-05); no live calls here.

const FakeJsonHttp := preload("res://tests/unit/shared/fake_json_http.gd")

const KEY := "test-key"
const UID := "Nyl4KV181lgsu7xsazADkFAtoo53"

var http: FakeJsonHttp
var gateway: FirebaseAuthGateway


func before_each() -> void:
	http = FakeJsonHttp.new()
	gateway = FirebaseAuthGateway.new(http, KEY)


func _signed_in_reply() -> Dictionary:
	return {
		"kind": "identitytoolkit#SignupNewUserResponse", "idToken": "id.jwt.token", "email": "happycat27@kifa-games.invalid",
		"refreshToken": "refresh-token", "expiresIn": "3600", "localId": UID,
	}


func _error(message: String) -> Dictionary:
	return {"error": {"code": 400, "message": message, "errors": []}}


func test_sign_up_request() -> void:
	http.reply(200, _signed_in_reply())

	await gateway.sign_up("HappyCat27", "pass word\"1")

	assert_eq(http.last().method, HTTPClient.METHOD_POST)
	assert_eq(http.last().url, "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=test-key")
	assert_eq(http.last().headers, PackedStringArray([JsonHttp.JSON_HEADER]))
	assert_eq(http.last_json(), {
		"email": "happycat27@kifa-games.invalid", "password": "pass word\"1", "returnSecureToken": true,
	})


func test_sign_up_returns_tokens() -> void:
	http.reply(200, _signed_in_reply())

	var tokens: AuthGateway.Tokens = await gateway.sign_up("HappyCat27", "password1")

	assert_eq(tokens.status, AuthGateway.Status.OK)
	assert_eq(tokens.uid, UID)
	assert_eq(tokens.id_token, "id.jwt.token")
	assert_eq(tokens.refresh_token, "refresh-token")
	assert_eq(tokens.expires_in, 3600.0)


func test_sign_in_request() -> void:
	http.reply(200, _signed_in_reply())

	var tokens: AuthGateway.Tokens = await gateway.sign_in("HappyCat27", "password1")

	assert_eq(http.last().url, "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=test-key")
	assert_eq(http.last_json().email, "happycat27@kifa-games.invalid")
	assert_eq(tokens.status, AuthGateway.Status.OK)


func test_refresh_request_and_tokens() -> void:
	http.reply(200, {
		"access_token": "new.jwt", "expires_in": "3600", "token_type": "Bearer", "refresh_token": "new-refresh",
		"id_token": "new.jwt", "user_id": UID, "project_id": "699671676330",
	})

	var tokens: AuthGateway.Tokens = await gateway.refresh("old refresh&x=1")

	assert_eq(http.last().url, "https://securetoken.googleapis.com/v1/token?key=test-key")
	assert_eq(http.last().headers, PackedStringArray([FirebaseAuthGateway.FORM_HEADER]))
	assert_eq(http.last().body, "grant_type=refresh_token&refresh_token=old%20refresh%26x%3D1")
	assert_eq(tokens.status, AuthGateway.Status.OK)
	assert_eq(tokens.uid, UID)
	assert_eq(tokens.id_token, "new.jwt")
	assert_eq(tokens.refresh_token, "new-refresh")


func test_delete_account_request() -> void:
	http.reply(200, {"kind": "identitytoolkit#DeleteAccountResponse"})

	var status: AuthGateway.Status = await gateway.delete_account("id.jwt.token")

	assert_eq(http.last().url, "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=test-key")
	assert_eq(http.last_json(), {"idToken": "id.jwt.token"})
	assert_eq(status, AuthGateway.Status.OK)


func test_firebase_errors_map_to_statuses() -> void:
	var expected: Dictionary[String, AuthGateway.Status] = {
		"EMAIL_EXISTS": AuthGateway.Status.USERNAME_TAKEN,
		"INVALID_LOGIN_CREDENTIALS": AuthGateway.Status.WRONG_CREDENTIALS,
		"EMAIL_NOT_FOUND": AuthGateway.Status.WRONG_CREDENTIALS,
		"INVALID_PASSWORD": AuthGateway.Status.WRONG_CREDENTIALS,
		"WEAK_PASSWORD : Password should be at least 6 characters": AuthGateway.Status.WEAK_PASSWORD,
		"PASSWORD_DOES_NOT_MEET_REQUIREMENTS : Missing password requirements: [Password must contain at least 8 characters]":
			AuthGateway.Status.WEAK_PASSWORD,
		"TOO_MANY_ATTEMPTS_TRY_LATER : Access to this account has been temporarily disabled":
			AuthGateway.Status.TOO_MANY_ATTEMPTS,
		"TOKEN_EXPIRED": AuthGateway.Status.SESSION_EXPIRED,
		"INVALID_REFRESH_TOKEN": AuthGateway.Status.SESSION_EXPIRED,
		"USER_NOT_FOUND": AuthGateway.Status.SESSION_EXPIRED,
		"USER_DISABLED": AuthGateway.Status.SESSION_EXPIRED,
		"CREDENTIAL_TOO_OLD_LOGIN_AGAIN": AuthGateway.Status.SESSION_EXPIRED,
		"SOMETHING_NEW": AuthGateway.Status.UNKNOWN,
	}
	for message: String in expected:
		http.reply(400, _error(message))

		var tokens: AuthGateway.Tokens = await gateway.sign_in("HappyCat27", "password1")

		assert_eq(tokens.status, expected[message], message)
		assert_eq(tokens.id_token, "", message)


func test_no_answer_is_offline() -> void:
	assert_eq((await gateway.sign_in("HappyCat27", "password1")).status, AuthGateway.Status.OFFLINE)
	assert_eq((await gateway.refresh("refresh")).status, AuthGateway.Status.OFFLINE)
	assert_eq(await gateway.delete_account("id"), AuthGateway.Status.OFFLINE)


func test_malformed_replies_are_unknown() -> void:
	var replies: Array = [
		[200, null], [200, "text"], [200, [1]], [500, null], [500, {"error": "boom"}],
		[400, {"error": {"message": 5}}], [400, {}],
	]
	for reply: Array in replies:
		http.reply(reply[0], reply[1])

		assert_eq((await gateway.sign_in("HappyCat27", "password1")).status, AuthGateway.Status.UNKNOWN, str(reply))


func test_ok_reply_with_bad_token_fields_is_unknown() -> void:
	var bad_values: Dictionary[String, Array] = {
		"localId": ["", "../other", "a/b", 5, null, "a".repeat(129)],
		"idToken": ["", 5, null, "a".repeat(FirebaseAuthGateway.MAX_TOKEN_LENGTH + 1)],
		"refreshToken": ["", 5, null],
		"expiresIn": ["soon", null, ""],
	}
	for key: String in bad_values:
		for value: Variant in bad_values[key]:
			var reply := _signed_in_reply()
			reply[key] = value
			http.reply(200, reply)

			var tokens: AuthGateway.Tokens = await gateway.sign_up("HappyCat27", "password1")

			assert_eq(tokens.status, AuthGateway.Status.UNKNOWN, "%s = %s" % [key, value])
			assert_eq(tokens.uid, "")


func test_expires_in_is_clamped() -> void:
	var reply := _signed_in_reply()
	reply.expiresIn = "999999999"
	http.reply(200, reply)

	assert_eq((await gateway.sign_up("HappyCat27", "password1")).expires_in, FirebaseAuthGateway.MAX_EXPIRES_IN)


func test_is_uid() -> void:
	assert_true(FirebaseAuthGateway.is_uid(UID))
	for value: Variant in ["", "a b", "a/b", "ä", 7, null, "a".repeat(129)]:
		assert_false(FirebaseAuthGateway.is_uid(value), str(value))
