extends GutTest

const PATH := "user://test_account.json"
const UID := "Nyl4KV181lgsu7xsazADkFAtoo53"

var store: JsonAccountStore


func before_each() -> void:
	_clean()
	store = JsonAccountStore.new(PATH)


func after_each() -> void:
	_clean()


func _clean() -> void:
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(PATH + JsonFile.TMP_SUFFIX)


func _write(data: Variant) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _valid() -> Dictionary:
	return {"version": 1, "uid": UID, "username": "HappyCat27", "refresh_token": "refresh-token"}


func test_default_path_is_user_dir() -> void:
	assert_eq(JsonAccountStore.DEFAULT_PATH, "user://account.json")


func test_no_file_is_guest() -> void:
	assert_null(store.load_session())


func test_round_trip() -> void:
	store.save_session(AccountSession.new(UID, "HappyCat27", "refresh-token"))

	var session := JsonAccountStore.new(PATH).load_session()

	assert_eq(session.uid, UID)
	assert_eq(session.username, "HappyCat27")
	assert_eq(session.refresh_token, "refresh-token")


func test_saves_plain_json_without_a_password() -> void:
	store.save_session(AccountSession.new(UID, "HappyCat27", "refresh-token"))

	assert_eq(JsonFile.read(PATH), {
		"version": 1.0, "uid": UID, "username": "HappyCat27", "refresh_token": "refresh-token",
	})


func test_username_loads_without_surrounding_spaces() -> void:
	var data := _valid()
	data.username = " happycat27 "
	_write(data)

	assert_eq(store.load_session().username, "happycat27")


func test_clear_removes_the_session() -> void:
	store.save_session(AccountSession.new(UID, "HappyCat27", "refresh-token"))

	store.clear()

	assert_null(store.load_session())
	assert_false(FileAccess.file_exists(PATH))


func test_clear_without_file_does_not_fail() -> void:
	store.clear()

	assert_null(store.load_session())


func test_tampered_files_are_guest() -> void:
	var bad_values: Dictionary[String, Array] = {
		"version": [2, "1", null],
		"uid": ["", "../../other", "a/b", 5, null],
		"username": ["a b", "", 5, null, "HappyCat27@evil.com", "a".repeat(17)],
		"refresh_token": ["", 5, null, "a".repeat(FirebaseAuthGateway.MAX_TOKEN_LENGTH + 1)],
	}
	for key: String in bad_values:
		for value: Variant in bad_values[key]:
			var data := _valid()
			data[key] = value
			_write(data)

			assert_null(store.load_session(), "%s = %s" % [key, value])


func test_missing_fields_and_non_dictionaries_are_guest() -> void:
	for data: Variant in [{}, {"version": 1}, [1, 2], "text", 5, null]:
		_write(data)

		assert_null(store.load_session(), str(data))


func test_save_to_unwritable_path_does_not_crash() -> void:
	var broken := JsonAccountStore.new("user://missing_dir/sub/account.json")

	broken.save_session(AccountSession.new(UID, "HappyCat27", "refresh-token"))

	assert_null(broken.load_session())
