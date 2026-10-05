class_name JsonHttp
extends RefCounted

## Sends one HTTPS request at a time through an HTTPRequest node and returns the status and JSON body.
## The response is untrusted: callers validate it. Nothing sent or received is ever logged (requests
## carry passwords and tokens).

signal _idle

const TIMEOUT_SECONDS := 10.0
## Responses here are a few KB; the cap bounds memory if a server misbehaves.
const MAX_RESPONSE_BYTES := 65_536
const JSON_HEADER := "Content-Type: application/json"


class Response:
	extends RefCounted

	## HTTP status, or 0 when there was no answer (offline, timeout, TLS error, response too big).
	var status: int
	## Parsed body; null when the body is not JSON.
	var json: Variant

	func _init(response_status: int, body: Variant = null) -> void:
		status = response_status
		json = body


var _request: HTTPRequest
var _busy := false


func _init(request: HTTPRequest) -> void:
	_request = request


## Builds the node with the limits every request must have. Add it to the tree before use.
static func new_request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = TIMEOUT_SECONDS
	request.body_size_limit = MAX_RESPONSE_BYTES
	request.max_redirects = 0
	# On Web the browser already unpacks gzip; unpacking again fails and the answer is lost.
	request.accept_gzip = false
	return request


## A call made while another request is running waits for it to finish first.
func send(method: HTTPClient.Method, url: String, headers: PackedStringArray, body := "") -> Response:
	while _busy:
		await _idle
	_busy = true
	var response := await _send(method, url, headers, body)
	_busy = false
	_idle.emit()
	return response


func _send(method: HTTPClient.Method, url: String, headers: PackedStringArray, body: String) -> Response:
	if _request.request(url, headers, method, body) != OK:
		return Response.new(0)
	# [result, status, headers, body]
	var completed: Array = await _request.request_completed
	if completed[0] != HTTPRequest.RESULT_SUCCESS:
		return Response.new(0)
	var raw: PackedByteArray = completed[3]
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK:
		return Response.new(completed[1])
	return Response.new(completed[1], json.data)
