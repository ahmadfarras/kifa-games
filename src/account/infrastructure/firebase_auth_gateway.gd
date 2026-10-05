class_name FirebaseAuthGateway
extends AuthGateway

## Accounts on Firebase Authentication, over its REST API. Firebase wants an email-shaped id, so the
## username "Budi7" is sent as "budi7@kifa-games.invalid": never shown, never mailed. Lower case, so
## "budi7" and "Budi7" are the same account.
## Firebase hashes the password and limits repeated attempts; the game only passes it on over HTTPS.

const AUTH_DOMAIN := "kifa-games.invalid"
const ACCOUNTS_URL := "https://identitytoolkit.googleapis.com/v1/accounts:%s?key=%s"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token?key=%s"
const FORM_HEADER := "Content-Type: application/x-www-form-urlencoded"
const MAX_TOKEN_LENGTH := 4096
const MAX_EXPIRES_IN := 86_400.0
## Firebase error message (its first word) -> what the game shows. Anything else is UNKNOWN.
const STATUS_BY_ERROR: Dictionary[String, Status] = {
	"EMAIL_EXISTS": Status.USERNAME_TAKEN,
	"INVALID_LOGIN_CREDENTIALS": Status.WRONG_CREDENTIALS,
	"EMAIL_NOT_FOUND": Status.WRONG_CREDENTIALS,
	"INVALID_PASSWORD": Status.WRONG_CREDENTIALS,
	"INVALID_EMAIL": Status.WRONG_CREDENTIALS,
	"WEAK_PASSWORD": Status.WEAK_PASSWORD,
	"PASSWORD_DOES_NOT_MEET_REQUIREMENTS": Status.WEAK_PASSWORD,
	"TOO_MANY_ATTEMPTS_TRY_LATER": Status.TOO_MANY_ATTEMPTS,
	"TOKEN_EXPIRED": Status.SESSION_EXPIRED,
	"INVALID_REFRESH_TOKEN": Status.SESSION_EXPIRED,
	"INVALID_ID_TOKEN": Status.SESSION_EXPIRED,
	"USER_NOT_FOUND": Status.SESSION_EXPIRED,
	"USER_DISABLED": Status.SESSION_EXPIRED,
	"CREDENTIAL_TOO_OLD_LOGIN_AGAIN": Status.SESSION_EXPIRED,
}

static var _uid_pattern := RegEx.create_from_string("^[A-Za-z0-9]{1,128}$")

var _http: JsonHttp
var _api_key: String


func _init(http: JsonHttp, api_key: String) -> void:
	_http = http
	_api_key = api_key


func sign_up(username: String, password: String) -> Tokens:
	return await _credentials_call("signUp", username, password)


func sign_in(username: String, password: String) -> Tokens:
	return await _credentials_call("signInWithPassword", username, password)


func refresh(refresh_token: String) -> Tokens:
	var body := "grant_type=refresh_token&refresh_token=" + refresh_token.uri_encode()
	var response := await _http.send(HTTPClient.METHOD_POST, TOKEN_URL % _api_key, [FORM_HEADER], body)
	return _tokens(response, "user_id", "id_token", "refresh_token", "expires_in")


func delete_account(id_token: String) -> Status:
	var response := await _post("delete", {"idToken": id_token})
	return _status(response)


static func is_uid(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and _uid_pattern.search(value) != null


func _credentials_call(action: String, username: String, password: String) -> Tokens:
	var email := "%s@%s" % [username.to_lower(), AUTH_DOMAIN]
	var response := await _post(action, {"email": email, "password": password, "returnSecureToken": true})
	return _tokens(response, "localId", "idToken", "refreshToken", "expiresIn")


func _post(action: String, payload: Dictionary) -> JsonHttp.Response:
	var url := ACCOUNTS_URL % [action, _api_key]
	return await _http.send(HTTPClient.METHOD_POST, url, [JsonHttp.JSON_HEADER], JSON.stringify(payload))


## The two Firebase APIs answer with the same values under different names, hence the keys.
static func _tokens(
	response: JsonHttp.Response, uid_key: String, id_key: String, refresh_key: String, expires_key: String
) -> Tokens:
	var status := _status(response)
	if status != Status.OK:
		return Tokens.new(status)
	var json: Dictionary = response.json
	var expires_in := str(json.get(expires_key, ""))
	if (
		not is_uid(json.get(uid_key))
		or not _is_token(json.get(id_key))
		or not _is_token(json.get(refresh_key))
		or not expires_in.is_valid_float()
	):
		return Tokens.new(Status.UNKNOWN)
	var tokens := Tokens.new(Status.OK)
	tokens.uid = json[uid_key]
	tokens.id_token = json[id_key]
	tokens.refresh_token = json[refresh_key]
	tokens.expires_in = clampf(expires_in.to_float(), 0.0, MAX_EXPIRES_IN)
	return tokens


static func _status(response: JsonHttp.Response) -> Status:
	if response.status == 0:
		return Status.OFFLINE
	if typeof(response.json) != TYPE_DICTIONARY:
		return Status.UNKNOWN
	if response.status == 200:
		return Status.OK
	var error: Variant = response.json.get("error")
	if typeof(error) != TYPE_DICTIONARY or typeof(error.get("message")) != TYPE_STRING:
		return Status.UNKNOWN
	# Messages can carry details: "WEAK_PASSWORD : Password should be at least 6 characters".
	var code: String = error.message.get_slice(" ", 0)
	return STATUS_BY_ERROR.get(code, Status.UNKNOWN)


static func _is_token(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.is_empty() and value.length() <= MAX_TOKEN_LENGTH
