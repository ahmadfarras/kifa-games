extends JsonHttp

## JsonHttp for tests: records what would be sent and answers with queued replies (status 0 when the
## queue is empty, like being offline). No network.

var requests: Array[Dictionary] = []
var _replies: Array[Response] = []


func _init() -> void:
	super(null)


func reply(status: int, json: Variant = null) -> void:
	_replies.append(Response.new(status, json))


func send(method: HTTPClient.Method, url: String, headers: PackedStringArray, body := "") -> Response:
	requests.append({"method": method, "url": url, "headers": headers, "body": body})
	return Response.new(0) if _replies.is_empty() else _replies.pop_front()


func last() -> Dictionary:
	return requests[-1]


func last_json() -> Variant:
	return JSON.parse_string(last().body)
