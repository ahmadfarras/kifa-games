extends GutTest

const FakeJsonHttp := preload("res://tests/unit/shared/fake_json_http.gd")

const UID := "Nyl4KV181lgsu7xsazADkFAtoo53"
const DOCUMENT_URL := (
	"https://firestore.googleapis.com/v1/projects/test-project/databases/(default)/documents/saves/%s/games/runner" % UID
)

var http: FakeJsonHttp
var documents: FirestoreDocuments
var token := "id.jwt.token"
var uid := UID


func before_each() -> void:
	token = "id.jwt.token"
	uid = UID
	http = FakeJsonHttp.new()
	documents = FirestoreDocuments.new(http, "test-project", _token, _uid)


func _token() -> String:
	return token


func _uid() -> String:
	return uid


func _firestore_document() -> Dictionary:
	return {
		"name": "projects/test-project/databases/(default)/documents/saves/%s/games/runner" % UID,
		"fields": {
			"version": {"integerValue": "2"},
			"coins": {"integerValue": "310"},
			"owned": {"arrayValue": {"values": [{"stringValue": "little_girl"}, {"stringValue": "cat"}]}},
			"flag": {"booleanValue": true},
		},
		"createTime": "2026-10-05T03:00:00Z", "updateTime": "2026-10-05T03:00:00Z",
	}


func test_read_request() -> void:
	http.reply(200, _firestore_document())

	await documents.read("runner")

	assert_eq(http.last().method, HTTPClient.METHOD_GET)
	assert_eq(http.last().url, DOCUMENT_URL)
	assert_eq(http.last().headers, PackedStringArray(["Authorization: Bearer id.jwt.token", JsonHttp.JSON_HEADER]))
	assert_eq(http.last().body, "")


func test_read_decodes_typed_values() -> void:
	http.reply(200, _firestore_document())

	var document: FirestoreDocuments.Document = await documents.read("runner")

	assert_eq(document.status, FirestoreDocuments.Status.OK)
	assert_eq(document.data, {"version": 2, "coins": 310, "owned": ["little_girl", "cat"], "flag": true})
	assert_eq(typeof(document.data.coins), TYPE_INT)


func test_read_missing_document_is_not_found() -> void:
	http.reply(404, {"error": {"code": 404, "message": "Document not found", "status": "NOT_FOUND"}})

	var document: FirestoreDocuments.Document = await documents.read("runner")

	assert_eq(document.status, FirestoreDocuments.Status.NOT_FOUND)
	assert_eq(document.data, {})


func test_read_turns_unsupported_values_into_null() -> void:
	http.reply(200, {"fields": {
		"big": {"integerValue": "12abc"}, "number": {"integerValue": 5}, "real": {"doubleValue": 1.5},
		"map": {"mapValue": {"fields": {"a": {"integerValue": "1"}}}}, "nothing": {"nullValue": null},
		"junk": "text", "list": {"arrayValue": {"values": [{"integerValue": "1"}, "junk", {"mapValue": {}}]}},
		"empty_list": {"arrayValue": {}}, "bad_list": {"arrayValue": "text"},
	}})

	var data: Dictionary = (await documents.read("runner")).data

	assert_eq(data, {
		"big": null, "number": null, "real": null, "map": null, "nothing": null,
		"list": [1, null, null], "empty_list": [], "bad_list": [],
	})


func test_read_caps_list_length() -> void:
	var values: Array = []
	values.resize(FirestoreDocuments.MAX_LIST_ENTRIES + 50)
	values.fill({"stringValue": "cat"})
	http.reply(200, {"fields": {"owned": {"arrayValue": {"values": values}}}})

	assert_eq((await documents.read("runner")).data.owned.size(), FirestoreDocuments.MAX_LIST_ENTRIES)


func test_read_document_without_fields_is_empty() -> void:
	for json: Variant in [{}, {"fields": "text"}, {"fields": [1]}]:
		http.reply(200, json)

		var document: FirestoreDocuments.Document = await documents.read("runner")

		assert_eq(document.status, FirestoreDocuments.Status.OK)
		assert_eq(document.data, {})


func test_write_request_encodes_typed_values() -> void:
	http.reply(200, _firestore_document())

	var status: FirestoreDocuments.Status = await documents.write(
		"runner", {"version": 2, "coins": 310, "owned": ["little_girl", "cat"], "flag": true}
	)

	assert_eq(status, FirestoreDocuments.Status.OK)
	assert_eq(http.last().method, HTTPClient.METHOD_PATCH)
	assert_eq(http.last().url, DOCUMENT_URL)
	assert_eq(http.last_json(), {"fields": {
		"version": {"integerValue": "2"},
		"coins": {"integerValue": "310"},
		"owned": {"arrayValue": {"values": [{"stringValue": "little_girl"}, {"stringValue": "cat"}]}},
		"flag": {"booleanValue": true},
	}})


func test_written_document_reads_back_the_same() -> void:
	var data := {"version": 2, "best_score": 42, "coins": 0, "owned": ["little_girl"]}
	http.reply(200, {})
	await documents.write("runner", data)
	http.reply(200, http.last_json())

	assert_eq((await documents.read("runner")).data, data)


func test_delete_request() -> void:
	http.reply(200, {})

	assert_eq(await documents.delete("runner"), FirestoreDocuments.Status.OK)
	assert_eq(http.last().method, HTTPClient.METHOD_DELETE)
	assert_eq(http.last().url, DOCUMENT_URL)


func test_http_statuses_map_to_statuses() -> void:
	var expected: Dictionary[int, FirestoreDocuments.Status] = {
		0: FirestoreDocuments.Status.OFFLINE,
		401: FirestoreDocuments.Status.NOT_SIGNED_IN,
		403: FirestoreDocuments.Status.FAILED,
		404: FirestoreDocuments.Status.NOT_FOUND,
		429: FirestoreDocuments.Status.FAILED,
		500: FirestoreDocuments.Status.FAILED,
	}
	for status: int in expected:
		http.reply(status, {"error": {"message": "nope"}})

		assert_eq(await documents.write("runner", {"coins": 1}), expected[status], str(status))


func test_ok_status_without_json_is_failed() -> void:
	http.reply(200, null)

	assert_eq((await documents.read("runner")).status, FirestoreDocuments.Status.FAILED)


func test_guest_sends_nothing() -> void:
	token = ""

	assert_eq((await documents.read("runner")).status, FirestoreDocuments.Status.NOT_SIGNED_IN)
	assert_eq(await documents.write("runner", {"coins": 1}), FirestoreDocuments.Status.NOT_SIGNED_IN)
	assert_eq(await documents.delete("runner"), FirestoreDocuments.Status.NOT_SIGNED_IN)
	assert_eq(http.requests.size(), 0)


func test_unsafe_uid_or_game_sends_nothing() -> void:
	for bad_uid in ["", "../other", "a/b", "a?b", "a b"]:
		uid = bad_uid
		assert_eq(await documents.delete("runner"), FirestoreDocuments.Status.NOT_SIGNED_IN, bad_uid)
	uid = UID
	for bad_game in ["", "../runner", "runner/x", "Runner", "runner2", "a".repeat(33)]:
		assert_eq(await documents.delete(bad_game), FirestoreDocuments.Status.NOT_SIGNED_IN, bad_game)
	assert_eq(http.requests.size(), 0)
