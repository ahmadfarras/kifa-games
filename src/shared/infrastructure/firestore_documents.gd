class_name FirestoreDocuments
extends RefCounted

## Reads and writes one cloud save document per game for the logged-in account, over the Firestore REST
## API: saves/{uid}/games/{game}. Knows nothing about what a game stores: documents are flat
## dictionaries of whole numbers, text, booleans and lists of those.
## The server decides who may touch a document (firestore.rules); what comes back is untrusted and the
## game's own codec validates it.

enum Status { OK, NOT_FOUND, NOT_SIGNED_IN, OFFLINE, FAILED }

const URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/saves/%s/games/%s"
## Bounds the work on a response that is not one of ours.
const MAX_LIST_ENTRIES := 100


class Document:
	extends RefCounted

	var status: Status
	var data: Dictionary

	func _init(document_status: Status, document_data: Dictionary = {}) -> void:
		status = document_status
		data = document_data


static var _game_pattern := RegEx.create_from_string("^[a-z]{1,32}$")
static var _uid_pattern := RegEx.create_from_string("^[A-Za-z0-9]{1,128}$")

var _http: JsonHttp
var _project_id: String
## Returns the id token of the logged-in account ("" when there is none); awaited.
var _id_token: Callable
## Returns the uid of the logged-in account.
var _uid: Callable


func _init(http: JsonHttp, project_id: String, id_token: Callable, uid: Callable) -> void:
	_http = http
	_project_id = project_id
	_id_token = id_token
	_uid = uid


func read(game: String) -> Document:
	var response := await _call(HTTPClient.METHOD_GET, game, "")
	var status := _status(response)
	if status != Status.OK:
		return Document.new(status)
	return Document.new(Status.OK, _decode(response.json))


## Replaces the whole document.
func write(game: String, data: Dictionary) -> Status:
	return _status(await _call(HTTPClient.METHOD_PATCH, game, JSON.stringify({"fields": _encode(data)})))


func delete(game: String) -> Status:
	return _status(await _call(HTTPClient.METHOD_DELETE, game, ""))


## Returns null when nobody is logged in or the path would not be one of ours.
func _call(method: HTTPClient.Method, game: String, body: String) -> JsonHttp.Response:
	var token: String = await _id_token.call()
	var uid: String = _uid.call()
	# The uid and game go into the URL: only plain letters and digits may get there.
	if token.is_empty() or _uid_pattern.search(uid) == null or _game_pattern.search(game) == null:
		return null
	var headers: PackedStringArray = ["Authorization: Bearer " + token, JsonHttp.JSON_HEADER]
	return await _http.send(method, URL % [_project_id, uid, game], headers, body)


static func _status(response: JsonHttp.Response) -> Status:
	if response == null:
		return Status.NOT_SIGNED_IN
	match response.status:
		0:
			return Status.OFFLINE
		200:
			return Status.OK if typeof(response.json) == TYPE_DICTIONARY else Status.FAILED
		401:
			return Status.NOT_SIGNED_IN
		404:
			return Status.NOT_FOUND
	return Status.FAILED


static func _encode(data: Dictionary) -> Dictionary:
	var fields := {}
	for key: String in data:
		var value: Variant = data[key]
		if typeof(value) == TYPE_ARRAY:
			var values: Array = (value as Array).map(_encode_scalar)
			fields[key] = {"arrayValue": {"values": values}}
		else:
			fields[key] = _encode_scalar(value)
	return fields


## Firestore sends and expects whole numbers as text.
static func _encode_scalar(value: Variant) -> Dictionary:
	match typeof(value):
		TYPE_INT:
			return {"integerValue": str(value)}
		TYPE_BOOL:
			return {"booleanValue": value}
	return {"stringValue": str(value)}


static func _decode(json: Dictionary) -> Dictionary:
	var data := {}
	var fields: Variant = json.get("fields")
	if typeof(fields) != TYPE_DICTIONARY:
		return data
	for key: Variant in fields:
		var field: Variant = fields[key]
		if typeof(key) != TYPE_STRING or typeof(field) != TYPE_DICTIONARY:
			continue
		data[key] = _decode_list(field.arrayValue) if field.has("arrayValue") else _decode_scalar(field)
	return data


static func _decode_list(array_value: Variant) -> Array:
	var list := []
	if typeof(array_value) != TYPE_DICTIONARY or typeof(array_value.get("values")) != TYPE_ARRAY:
		return list
	var values: Array = array_value.values
	for i in mini(values.size(), MAX_LIST_ENTRIES):
		list.append(_decode_scalar(values[i]))
	return list


## Returns null for anything that is not a whole number, text or boolean.
static func _decode_scalar(field: Variant) -> Variant:
	if typeof(field) != TYPE_DICTIONARY:
		return null
	var whole: Variant = field.get("integerValue")
	if typeof(whole) == TYPE_STRING and whole.is_valid_int():
		return whole.to_int()
	if typeof(field.get("stringValue")) == TYPE_STRING or typeof(field.get("booleanValue")) == TYPE_BOOL:
		return field.get("stringValue", field.get("booleanValue"))
	return null
