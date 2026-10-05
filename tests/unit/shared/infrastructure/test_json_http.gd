extends GutTest

## Talks to a tiny HTTP server on this machine, so the real HTTPRequest node is exercised.

const HOST := "127.0.0.1"
const FIRST_PORT := 18_930
const MAX_FRAMES := 600

var server: TCPServer
var port := 0
var http: JsonHttp
var responses: Array[JsonHttp.Response] = []


func before_each() -> void:
	server = TCPServer.new()
	port = FIRST_PORT
	while server.listen(port, HOST) != OK:
		port += 1
	var request := JsonHttp.new_request()
	add_child_autofree(request)
	http = JsonHttp.new(request)
	responses = []


func after_each() -> void:
	server.stop()


func _url() -> String:
	return "http://%s:%d/thing" % [HOST, port]


func _send(method: HTTPClient.Method, headers: PackedStringArray = [], body := "") -> void:
	responses.append(await http.send(method, _url(), headers, body))


## Answers the next request with `status_line` + `body` and returns the request as text.
func _serve(status_line: String, body: String) -> String:
	var frames := 0
	while not server.is_connection_available() and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	var peer := server.take_connection()
	var request := ""
	while not _is_complete(request) and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
		peer.poll()
		if peer.get_available_bytes() > 0:
			request += peer.get_utf8_string(peer.get_available_bytes())
	var reply := "HTTP/1.1 %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
	peer.put_data((reply % [status_line, body.to_utf8_buffer().size(), body]).to_utf8_buffer())
	await get_tree().process_frame
	peer.disconnect_from_host()
	return request


func _is_complete(request: String) -> bool:
	var header_end := request.find("\r\n\r\n")
	if header_end < 0:
		return false
	var length := 0
	for line in request.left(header_end).split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			length = line.get_slice(":", 1).strip_edges().to_int()
	return request.length() - header_end - 4 >= length


func _wait_for_responses(count: int) -> void:
	var frames := 0
	while responses.size() < count and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1


func test_new_request_has_limits() -> void:
	var request := JsonHttp.new_request()

	assert_eq(request.timeout, JsonHttp.TIMEOUT_SECONDS)
	assert_eq(request.body_size_limit, JsonHttp.MAX_RESPONSE_BYTES)
	assert_eq(request.max_redirects, 0)
	request.free()


func test_returns_status_and_parsed_json() -> void:
	_send(HTTPClient.METHOD_GET)
	await _serve("200 OK", '{"coins": 5}')
	await _wait_for_responses(1)

	assert_eq(responses[0].status, 200)
	assert_eq(responses[0].json, {"coins": 5.0})


func test_sends_method_headers_and_body() -> void:
	_send(HTTPClient.METHOD_POST, ["X-Test: yes", JsonHttp.JSON_HEADER], '{"a":1}')
	var request := await _serve("200 OK", "{}")
	await _wait_for_responses(1)

	assert_true(request.begins_with("POST /thing HTTP/1.1"), request)
	assert_string_contains(request, "X-Test: yes")
	assert_string_contains(request, "Content-Type: application/json")
	assert_true(request.ends_with('{"a":1}'), request)


func test_error_status_keeps_the_json_body() -> void:
	_send(HTTPClient.METHOD_GET)
	await _serve("400 Bad Request", '{"error": {"message": "EMAIL_EXISTS"}}')
	await _wait_for_responses(1)

	assert_eq(responses[0].status, 400)
	assert_eq(responses[0].json.error.message, "EMAIL_EXISTS")


func test_non_json_body_gives_null_json() -> void:
	_send(HTTPClient.METHOD_GET)
	await _serve("200 OK", "<html>hello</html>")
	await _wait_for_responses(1)

	assert_eq(responses[0].status, 200)
	assert_null(responses[0].json)


func test_oversized_body_counts_as_no_answer() -> void:
	_send(HTTPClient.METHOD_GET)
	await _serve("200 OK", '"%s"' % "a".repeat(JsonHttp.MAX_RESPONSE_BYTES))
	await _wait_for_responses(1)

	assert_eq(responses[0].status, 0)
	assert_null(responses[0].json)


func test_no_server_gives_status_zero() -> void:
	server.stop()
	_send(HTTPClient.METHOD_GET)
	await _wait_for_responses(1)

	assert_eq(responses[0].status, 0)
	assert_null(responses[0].json)


func test_second_request_waits_for_the_first() -> void:
	_send(HTTPClient.METHOD_GET)
	_send(HTTPClient.METHOD_GET)
	await _serve("200 OK", '{"n": 1}')
	await _serve("200 OK", '{"n": 2}')
	await _wait_for_responses(2)

	assert_eq(responses[0].json, {"n": 1.0})
	assert_eq(responses[1].json, {"n": 2.0})
