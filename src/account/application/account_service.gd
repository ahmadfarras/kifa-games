class_name AccountService
extends RefCounted

## Use cases for accounts: register, log in, log out, delete, and hand out the id token that proves
## the login to the cloud save. Playing as a guest needs none of this.

signal signed_in(username: String)
signal signed_out

## Refresh this long before the id token expires, so a request never leaves with a dying token.
const REFRESH_MARGIN := 60.0

var _gateway: AuthGateway
var _store: AccountStore
## Returns the current time in seconds; injected so tests control it.
var _clock: Callable
var _session: AccountSession
var _id_token := ""
var _expires_at := 0.0


func _init(gateway: AuthGateway, store: AccountStore, clock: Callable) -> void:
	_gateway = gateway
	_store = store
	_clock = clock
	_session = store.load_session()


func is_signed_in() -> bool:
	return _session != null


func username() -> String:
	return _session.username if is_signed_in() else ""


func uid() -> String:
	return _session.uid if is_signed_in() else ""


func register(username_text: String, password: String) -> AuthGateway.Status:
	var name := Username.canonical(username_text)
	if name.is_empty():
		return AuthGateway.Status.INVALID_USERNAME
	if not Password.is_valid(password):
		return AuthGateway.Status.WEAK_PASSWORD
	return _start_session(name, await _gateway.sign_up(name, password))


## Text that cannot be a username or password is refused here, without asking the server.
func log_in(username_text: String, password: String) -> AuthGateway.Status:
	var name := Username.canonical(username_text)
	if name.is_empty() or not Password.is_valid(password):
		return AuthGateway.Status.WRONG_CREDENTIALS
	return _start_session(name, await _gateway.sign_in(name, password))


func log_out() -> void:
	if not is_signed_in():
		return
	_session = null
	_id_token = ""
	_expires_at = 0.0
	_store.clear()
	signed_out.emit()


## Asks for the password again before something that cannot be undone (deleting the account).
func confirm_password(password: String) -> AuthGateway.Status:
	if not is_signed_in():
		return AuthGateway.Status.SESSION_EXPIRED
	if not Password.is_valid(password):
		return AuthGateway.Status.WRONG_CREDENTIALS
	var name := _session.username
	var tokens: AuthGateway.Tokens = await _gateway.sign_in(name, password)
	if tokens.status == AuthGateway.Status.OK:
		_keep(name, tokens)
	return tokens.status


## Call confirm_password() first: the server only deletes for a recent login.
func delete_account() -> AuthGateway.Status:
	var token := await id_token()
	if token.is_empty():
		return AuthGateway.Status.SESSION_EXPIRED
	var status: AuthGateway.Status = await _gateway.delete_account(token)
	if status == AuthGateway.Status.OK:
		log_out()
	return status


## Returns "" for a guest, when offline, or when the login is no longer valid (which logs out).
func id_token() -> String:
	if not is_signed_in():
		return ""
	if _clock.call() < _expires_at - REFRESH_MARGIN:
		return _id_token
	var tokens: AuthGateway.Tokens = await _gateway.refresh(_session.refresh_token)
	if tokens.status == AuthGateway.Status.SESSION_EXPIRED:
		log_out()
	if tokens.status != AuthGateway.Status.OK or not is_signed_in():
		return ""
	_keep(_session.username, tokens)
	return _id_token


func _start_session(name: String, tokens: AuthGateway.Tokens) -> AuthGateway.Status:
	if tokens.status == AuthGateway.Status.OK:
		_keep(name, tokens)
		signed_in.emit(name)
	return tokens.status


func _keep(name: String, tokens: AuthGateway.Tokens) -> void:
	_session = AccountSession.new(tokens.uid, name, tokens.refresh_token)
	_id_token = tokens.id_token
	_expires_at = _clock.call() + tokens.expires_in
	_store.save_session(_session)
