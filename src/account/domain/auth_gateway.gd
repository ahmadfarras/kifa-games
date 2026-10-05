@abstract
class_name AuthGateway
extends RefCounted

## Port: the server that knows accounts. Every call goes over the network, so callers await them.
## WRONG_CREDENTIALS covers both an unknown username and a wrong password, so nobody can find out
## which usernames exist.

enum Status {
	OK, INVALID_USERNAME, USERNAME_TAKEN, WRONG_CREDENTIALS, WEAK_PASSWORD, TOO_MANY_ATTEMPTS, OFFLINE,
	SESSION_EXPIRED, UNKNOWN,
}


class Tokens:
	extends RefCounted

	var status: Status
	var uid := ""
	## Short-lived proof of login sent with each cloud save request.
	var id_token := ""
	## Long-lived; exchanged for a new id token with refresh().
	var refresh_token := ""
	## Seconds until the id token stops working.
	var expires_in := 0.0

	func _init(tokens_status: Status) -> void:
		status = tokens_status


@abstract func sign_up(username: String, password: String) -> Tokens


@abstract func sign_in(username: String, password: String) -> Tokens


@abstract func refresh(refresh_token: String) -> Tokens


@abstract func delete_account(id_token: String) -> Status
