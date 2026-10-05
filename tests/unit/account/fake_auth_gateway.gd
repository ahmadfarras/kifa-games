extends AuthGateway

## In-memory AuthGateway for tests. Set `failure` to make every call fail with that status.

var failure := Status.OK
var expires_in := 3600.0
## Lower-case username -> password.
var passwords: Dictionary[String, String] = {}
var deleted_tokens: Array[String] = []
var calls := 0
var refresh_count := 0
var _issued := 0


func sign_up(username: String, password: String) -> Tokens:
	calls += 1
	if failure != Status.OK:
		return Tokens.new(failure)
	if passwords.has(username.to_lower()):
		return Tokens.new(Status.USERNAME_TAKEN)
	passwords[username.to_lower()] = password
	return _issue(username)


func sign_in(username: String, password: String) -> Tokens:
	calls += 1
	if failure != Status.OK:
		return Tokens.new(failure)
	if passwords.get(username.to_lower(), "") != password:
		return Tokens.new(Status.WRONG_CREDENTIALS)
	return _issue(username)


func refresh(refresh_token: String) -> Tokens:
	calls += 1
	refresh_count += 1
	if failure != Status.OK:
		return Tokens.new(failure)
	return _issue(refresh_token.trim_prefix("refresh-").get_slice("-", 0))


func delete_account(id_token: String) -> Status:
	calls += 1
	if failure == Status.OK:
		deleted_tokens.append(id_token)
	return failure


func _issue(username: String) -> Tokens:
	_issued += 1
	var tokens := Tokens.new(Status.OK)
	tokens.uid = "uid" + username.to_lower()
	tokens.id_token = "id-%d" % _issued
	tokens.refresh_token = "refresh-%s-%d" % [username.to_lower(), _issued]
	tokens.expires_in = expires_in
	return tokens
