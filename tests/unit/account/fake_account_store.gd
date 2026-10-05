extends AccountStore

## In-memory AccountStore for tests; counts saves.

var stored: AccountSession
var save_count := 0


func load_session() -> AccountSession:
	return stored


func save_session(session: AccountSession) -> void:
	stored = session
	save_count += 1


func clear() -> void:
	stored = null
