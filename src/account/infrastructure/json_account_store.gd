class_name JsonAccountStore
extends AccountStore

## Keeps the logged-in session in user:// so the kid stays logged in between launches.
## Format: {"version": 1, "uid": "...", "username": "HappyCat27", "refresh_token": "..."}.
## The file is user-editable, so it is untrusted: anything that doesn't look right means guest.

const DEFAULT_PATH := "user://account.json"
const VERSION := 1

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func load_session() -> AccountSession:
	var data: Variant = JsonFile.read(_path)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	# JSON numbers arrive as float; comparing another type with a number would be an error.
	var version: Variant = data.get("version")
	if typeof(version) != TYPE_FLOAT or version != VERSION:
		return null
	var uid: Variant = data.get("uid")
	var username: Variant = data.get("username")
	var refresh_token: Variant = data.get("refresh_token")
	if (
		not FirebaseAuthGateway.is_uid(uid)
		or typeof(username) != TYPE_STRING
		or not Username.is_valid(username)
		or typeof(refresh_token) != TYPE_STRING
		or refresh_token.is_empty()
		or refresh_token.length() > FirebaseAuthGateway.MAX_TOKEN_LENGTH
	):
		return null
	return AccountSession.new(uid, Username.canonical(username), refresh_token)


func save_session(session: AccountSession) -> void:
	var error := JsonFile.write(_path, {
		"version": VERSION, "uid": session.uid, "username": session.username,
		"refresh_token": session.refresh_token,
	})
	if error != OK:
		push_warning("Login not remembered: %s" % error_string(error))


func clear() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
